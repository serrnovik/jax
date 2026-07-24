function Register-JaxVaultPlugin {
    [CmdletBinding()]
    param()

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    if ($null -eq $commonParams) {
        $commonParams = @{}
    }

    # Hooks for vault integration
    $hooks = @{
        # Persist and apply -vault/-novault as a plugin preference.
        # This runs before the header is printed so the UI reflects the effective state.
        'BeforeRunHeader'  = {
            param($hook)
            $context = $hook.Context
            $pluginConfig = $hook.PluginConfig

            $resolved = $null
            if ($hook.Data -and $hook.Data.ContainsKey('Resolved')) {
                $resolved = $hook.Data['Resolved']
            }

            $vaultEnabled = $false
            if ($pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
                if ($pluginConfig.Contains('enabled') -and $pluginConfig['enabled'] -is [bool]) {
                    $vaultEnabled = [bool]$pluginConfig['enabled']
                }
            }

            # Apply persisted preference from state when present.
            $stateVaultEnabled = $null
            if ($context.ContainsKey('State') -and $context['State'] -is [System.Collections.IDictionary]) {
                $st = $context['State']
                if ($st.Contains('plugins') -and $st['plugins'] -is [System.Collections.IDictionary]) {
                    $plugins = $st['plugins']
                    if ($plugins.Contains('vault') -and $plugins['vault'] -is [System.Collections.IDictionary]) {
                        $vaultPrefs = $plugins['vault']
                        if ($vaultPrefs.Contains('enabled') -and $vaultPrefs['enabled'] -is [bool]) {
                            $stateVaultEnabled = [bool]$vaultPrefs['enabled']
                        }
                    }
                }
            }
            if ($stateVaultEnabled -is [bool]) {
                $vaultEnabled = $stateVaultEnabled
            }

            # CLI override always wins and gets persisted (unless -noSavedSettings).
            $cliOverride = $null
            if ($resolved -and $resolved -is [System.Collections.IDictionary]) {
                if ($resolved.Contains('novault') -and [bool]$resolved['novault']) { $cliOverride = $false }
                elseif ($resolved.Contains('vault') -and [bool]$resolved['vault']) { $cliOverride = $true }
            }
            if ($cliOverride -is [bool]) {
                $vaultEnabled = $cliOverride

                $noSave = $false
                if ($context.ContainsKey('NoSavedSettings') -and [bool]$context['NoSavedSettings']) { $noSave = $true }
                if ($resolved -and $resolved.Contains('noSavedSettings') -and [bool]$resolved['noSavedSettings']) { $noSave = $true }

                if (-not $noSave) {
                    Update-JaxState -RepoRoot $context['RepoRoot'] -Updates @{ plugins = @{ vault = @{ enabled = $vaultEnabled } } } | Out-Null
                }
            }

            # Expose effective choice for the rest of the run.
            if ($resolved -and $resolved -is [System.Collections.IDictionary]) {
                $resolved['vaultEnabledOverride'] = $vaultEnabled
            }
            $context['VaultEnabledOverride'] = $vaultEnabled
        }

        # Inject vault token and address into run context if enabled
        # Also resolve secrets in Entity Args/Container
        'BeforeRunEntity'  = {
            param($hook)
            $context = $hook.Context
            $data = $hook.Data
            $pluginConfig = $hook.PluginConfig

            if (-not $context.ContainsKey('VaultEnvSnapshot')) {
                $context['VaultEnvSnapshot'] = @{
                    VAULT_ADDR            = @{
                        WasSet = (Test-Path Env:\VAULT_ADDR)
                        Value  = (Get-Item Env:\VAULT_ADDR -ErrorAction SilentlyContinue).Value
                    }
                    VAULT_TOKEN           = @{
                        WasSet = (Test-Path Env:\VAULT_TOKEN)
                        Value  = (Get-Item Env:\VAULT_TOKEN -ErrorAction SilentlyContinue).Value
                    }
                    JAX_NO_CONFIG_SECRETS = @{
                        WasSet = (Test-Path Env:\JAX_NO_CONFIG_SECRETS)
                        Value  = (Get-Item Env:\JAX_NO_CONFIG_SECRETS -ErrorAction SilentlyContinue).Value
                    }
                }
            }

            # Determine vault enablement from config (source of truth).
            $vaultEnabled = $false
            if ($null -ne $pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
                if ($pluginConfig.Contains('enabled') -and $pluginConfig['enabled'] -is [bool]) {
                    $vaultEnabled = [bool]$pluginConfig['enabled']
                }
            }

            # CLI/state override (persisted preference): allow -vault/-novault to temporarily disable vault resolution.
            if ($context.ContainsKey('VaultEnabledOverride') -and $context['VaultEnabledOverride'] -is [bool]) {
                $vaultEnabled = [bool]$context['VaultEnabledOverride']
            } elseif ($context.ContainsKey('ResolvedOptions') -and $context['ResolvedOptions'] -is [System.Collections.IDictionary]) {
                $resolved = $context['ResolvedOptions']
                if ($resolved.Contains('vaultEnabledOverride') -and $resolved['vaultEnabledOverride'] -is [bool]) {
                    $vaultEnabled = [bool]$resolved['vaultEnabledOverride']
                } elseif ($resolved.Contains('novault') -and [bool]$resolved['novault']) {
                    $vaultEnabled = $false
                } elseif ($resolved.Contains('vault') -and [bool]$resolved['vault']) {
                    $vaultEnabled = $true
                }
            }

            $vaultAddress = $null
            if ($null -ne $pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
                if ($pluginConfig.Contains('address') -and $pluginConfig['address'] -is [string] -and -not [string]::IsNullOrWhiteSpace($pluginConfig['address'])) {
                    $vaultAddress = [string]$pluginConfig['address']
                }
            }

            # Expose these on context for other components (and for debugging).
            $context['VaultEnabled'] = $vaultEnabled
            if (-not [string]::IsNullOrWhiteSpace($vaultAddress)) {
                $context['VaultAddress'] = $vaultAddress
            }

            # 1. Env Injection
            if ($vaultEnabled) {
                # Ensure a previous -novault run in the same shell doesn't keep secrets disabled.
                Remove-Item Env:\JAX_NO_CONFIG_SECRETS -ErrorAction SilentlyContinue

                $addr = $vaultAddress
                if (-not [string]::IsNullOrWhiteSpace($addr)) {
                    $env:VAULT_ADDR = $addr
                }

                $token = $null
                if ($context.ContainsKey('ResolvedOptions') -and $context['ResolvedOptions'] -is [System.Collections.IDictionary]) {
                    $resolved = $context['ResolvedOptions']
                    if ($resolved.Contains('vaultToken') -and $resolved['vaultToken'] -is [string] -and -not [string]::IsNullOrWhiteSpace($resolved['vaultToken'])) {
                        $token = [string]$resolved['vaultToken']
                    } elseif ($resolved.Contains('vaultTokenEnv') -and $resolved['vaultTokenEnv'] -is [string] -and -not [string]::IsNullOrWhiteSpace($resolved['vaultTokenEnv'])) {
                        $tokenEnvName = [string]$resolved['vaultTokenEnv']
                        $tokenEnvItem = Get-Item -Path "Env:$tokenEnvName" -ErrorAction SilentlyContinue
                        if ($null -ne $tokenEnvItem -and -not [string]::IsNullOrWhiteSpace($tokenEnvItem.Value)) {
                            $token = [string]$tokenEnvItem.Value
                        } else {
                            Write-Warning "Vault token env var '$tokenEnvName' was requested but is not set."
                        }
                    } elseif ($resolved.Contains('useEnvVaultToken') -and [bool]$resolved['useEnvVaultToken']) {
                        if (Test-Path Env:\VAULT_TOKEN) {
                            $token = (Get-Item Env:\VAULT_TOKEN).Value
                        } else {
                            Write-Warning "Vault token override requested with -useEnvVaultToken, but VAULT_TOKEN is not set."
                        }
                    }
                }
                if ([string]::IsNullOrWhiteSpace($token)) {
                    $token = Get-JaxVaultToken
                }
                if (-not [string]::IsNullOrWhiteSpace($token)) {
                    $env:VAULT_TOKEN = $token
                } else {
                    Write-Warning "Vault is enabled but no token found. Run 'jax vault set' (or 'jax vault login') to authenticate."
                }
            } else {
                # Hard-disable secret resolution for this run (do not touch VAULT_TOKEN to avoid side effects).
                $env:JAX_NO_CONFIG_SECRETS = '1'
            }

            # 1.5 Resolve secrets in the merged RunConfig (base properties) once per run.
            # This enables secrets defined in consumer run-config layers to be used by tasks and scripts.
            # We do this at runtime (not during run-config log writing) to avoid persisting secrets into log files.
            if ($vaultEnabled) {
                # From this point onward, runner payloads may contain plaintext
                # values whose keys do not look secret. Consumers must treat
                # the entire resolved payload as tainted when logging.
                $context['VaultSecretsResolved'] = $true
                if ($context.ContainsKey('RunConfig') -and $context['RunConfig'] -is [System.Collections.IDictionary]) {
                    $alreadyResolved = $context.ContainsKey('RunConfigVaultResolved') -and [bool]$context['RunConfigVaultResolved']
                    if (-not $alreadyResolved) {
                        $cache = @{}
                        if ($context.ContainsKey('VaultSecretsCache') -and $context['VaultSecretsCache'] -is [hashtable]) {
                            $cache = $context['VaultSecretsCache']
                        }
                        $ctxDebug = $context.ContainsKey('Debug') -and [bool]$context['Debug']
                        $ctxVerbose = $context.ContainsKey('Verbose') -and [bool]$context['Verbose']
                        $context['RunConfig'] = Resolve-JaxVaultSecrets -Data $context['RunConfig'] -Cache $cache -Debug:$ctxDebug -Verbose:$ctxVerbose
                        $context['VaultSecretsCache'] = $cache
                        $context['RunConfigVaultResolved'] = $true
                    }
                }
            }

            # 2. Secret Resolution
            if ($null -ne $data -and $data.Contains('Entity')) {
                $entity = $data['Entity']

                # Resolve Args
                if ($entity.Contains('Args') -and $entity['Args'] -is [System.Collections.IDictionary]) {
                    $ctxDebug = $context.ContainsKey('Debug') -and [bool]$context['Debug']
                    $ctxVerbose = $context.ContainsKey('Verbose') -and [bool]$context['Verbose']
                    $entity['Args'] = Resolve-JaxVaultSecrets -Data $entity['Args'] -Debug:$ctxDebug -Verbose:$ctxVerbose
                }

                # Resolve Container (Image, Env)
                if ($entity.Contains('Container') -and $entity['Container'] -is [System.Collections.IDictionary]) {
                    $ctxDebug = $context.ContainsKey('Debug') -and [bool]$context['Debug']
                    $ctxVerbose = $context.ContainsKey('Verbose') -and [bool]$context['Verbose']
                    $entity['Container'] = Resolve-JaxVaultSecrets -Data $entity['Container'] -Debug:$ctxDebug -Verbose:$ctxVerbose
                }

                # Resolve Environment vars if present
                if ($entity.Contains('Environment') -and $entity['Environment'] -is [System.Collections.IDictionary]) {
                    $ctxDebug = $context.ContainsKey('Debug') -and [bool]$context['Debug']
                    $ctxVerbose = $context.ContainsKey('Verbose') -and [bool]$context['Verbose']
                    $entity['Environment'] = Resolve-JaxVaultSecrets -Data $entity['Environment'] -Debug:$ctxDebug -Verbose:$ctxVerbose
                }
            }
        }

        'AfterRunEntities' = {
            param($hook)
            $context = $hook.Context
            if (-not $context.ContainsKey('VaultEnvSnapshot')) {
                return
            }

            $snapshot = $context['VaultEnvSnapshot']
            $items = @(
                @{ Name = 'VAULT_ADDR'; Snapshot = $snapshot['VAULT_ADDR'] }
                @{ Name = 'VAULT_TOKEN'; Snapshot = $snapshot['VAULT_TOKEN'] }
                @{ Name = 'JAX_NO_CONFIG_SECRETS'; Snapshot = $snapshot['JAX_NO_CONFIG_SECRETS'] }
            )
            foreach ($item in $items) {
                $name = $item['Name']
                $snap = $item['Snapshot']
                if ($null -eq $snap) {
                    continue
                }

                $wasSet = $false
                if ($snap.ContainsKey('WasSet')) { $wasSet = [bool]$snap['WasSet'] }
                if ($wasSet) {
                    $value = $null
                    if ($snap.ContainsKey('Value')) { $value = $snap['Value'] }
                    if ($null -ne $value) {
                        Set-Item -Path "Env:$name" -Value $value -ErrorAction SilentlyContinue | Out-Null
                    } else {
                        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                    }
                } else {
                    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Register-JaxPlugin -Name 'vault' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path @commonParams
}

# Auto-register on import
Register-JaxVaultPlugin

# Exported Functions - source from public/
$publicDir = Join-Path $PSScriptRoot 'public'
if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}

# Private Functions - source from private/
$privateDir = Join-Path $PSScriptRoot 'private'
if (Test-Path $privateDir) {
    Get-ChildItem -Path $privateDir -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
