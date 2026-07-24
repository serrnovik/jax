function Set-JaxVaultToken {
    [CmdletBinding()]
    [Alias('Connect-JaxVault', 'Set-VaultToken')]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $VaultToken,

        [Parameter(Mandatory = $false)]
        [string] $VaultAddress,

        [Parameter(Mandatory = $false)]
        [ValidateSet('token', 'github', 'ldap', 'userpass')]
        [string] $Method
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters

    $repoRoot = Get-JaxRepoRoot @commonParams
    $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams

    $vaultCfg = $null
    try { $vaultCfg = Get-JaxVaultPluginConfig -RepoRoot $repoRoot -Config $config } catch {}

    $configHasAddress = $vaultCfg -and $vaultCfg.Contains('address') -and $vaultCfg['address'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['address'])
    $configHasTokenDir = $vaultCfg -and $vaultCfg.Contains('tokenDir') -and $vaultCfg['tokenDir'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['tokenDir'])
    $configHasPolicy = $vaultCfg -and $vaultCfg.Contains('policy') -and $vaultCfg['policy'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['policy'])
    $configHasTokenTtl = $vaultCfg -and $vaultCfg.Contains('tokenTtl') -and $vaultCfg['tokenTtl'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['tokenTtl'])
    $authMount = 'github'
    if ($vaultCfg -and $vaultCfg.Contains('authMount') -and $vaultCfg['authMount'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['authMount'])) {
        $authMount = ([string]$vaultCfg['authMount']).Trim().Trim('/')
    }
    if ($authMount -notmatch '^[A-Za-z0-9][A-Za-z0-9_.\-/]*$' -or $authMount -match '(^|/)\.\.($|/)') {
        throw "Invalid Vault GitHub auth mount '$authMount'."
    }

    function ConvertTo-JaxVaultTokenTtlValue {
        param([string] $value)
        if ([string]::IsNullOrWhiteSpace($value)) { return '8h' }
        $v = $value.Trim()
        if ($v -match '^\d+$') { return "${v}h" }
        return $v
    }

    # Resolve address:
    # - explicit argument wins
    # - then repo config (.jax/jax.config.yml / legacy jax.config.yml)
    # - then env var (fallback only)
    if ([string]::IsNullOrWhiteSpace($VaultAddress)) {
        try {
            if ($configHasAddress) {
                $VaultAddress = $vaultCfg['address']
            }
        } catch {
            # best-effort
        }
    }
    if ([string]::IsNullOrWhiteSpace($VaultAddress)) {
        if (Test-Path Env:\VAULT_ADDR) {
            $VaultAddress = (Get-Item Env:\VAULT_ADDR).Value
        }
    }

    # Config is source of truth: if config doesn't have address yet, ask once (defaulting to env) and save it.
    if (-not $configHasAddress) {
        $addrDefault = $VaultAddress
        if ([string]::IsNullOrWhiteSpace($addrDefault)) { $addrDefault = 'http://127.0.0.1:8200' }
        $VaultAddress = Read-JaxPromptString -Prompt 'Vault address' -Default $addrDefault
    }

    if (-not [string]::IsNullOrWhiteSpace($VaultAddress)) {
        $env:VAULT_ADDR = $VaultAddress
        Write-Host "Vault address set to: $VaultAddress" -ForegroundColor Cyan
    }

    # Config is source of truth: ask tokenDir once (when missing) and save it.
    $tokenDir = $null
    if ($configHasTokenDir) {
        $tokenDir = $vaultCfg['tokenDir']
    }
    if (-not $configHasTokenDir) {
        $tokenDirDefault = '.jax/vault'
        $tokenDir = Read-JaxPromptString -Prompt "Token directory (relative to HOME or absolute; shortcut: enter a project key)" -Default $tokenDirDefault
        if ([string]::IsNullOrWhiteSpace($tokenDir)) {
            $tokenDir = $tokenDirDefault
        }
    }

    # Config is source of truth: ask policy once (when missing) and save it.
    $policy = $null
    if ($configHasPolicy) {
        $policy = $vaultCfg['policy']
    }
    if (-not $configHasPolicy) {
        $policy = Read-JaxPromptString -Prompt 'Vault policy name (optional; blank keeps the login token)' -Default ''
    }

    # Config is source of truth: token TTL for optional child-token creation.
    $tokenTtl = $null
    if ($configHasTokenTtl) {
        $tokenTtl = [string]$vaultCfg['tokenTtl']
    }

    $shouldUpdateTokenTtl = $false
    if ($configHasTokenTtl) {
        $ttlPrompt = "Change Vault token TTL? (current: $tokenTtl)"
        $shouldUpdateTokenTtl = Read-JaxPromptBool -Prompt $ttlPrompt -Default $false
    }
    if ((-not $configHasTokenTtl) -or $shouldUpdateTokenTtl) {
        $ttlDefault = if ($configHasTokenTtl) { $tokenTtl } else { '8h' }
        $tokenTtl = Read-JaxPromptString -Prompt 'Vault token TTL (hours number or duration like 6h, 30m)' -Default $ttlDefault
        if ([string]::IsNullOrWhiteSpace($tokenTtl)) {
            $tokenTtl = $ttlDefault
        }
    }
    $tokenTtl = ConvertTo-JaxVaultTokenTtlValue $tokenTtl

    if ((-not $configHasAddress) -or (-not $configHasTokenDir) -or (-not $configHasPolicy) -or (-not $configHasTokenTtl) -or $shouldUpdateTokenTtl) {
        Update-JaxVaultRepoConfig -RepoRoot $repoRoot -VaultAddress $VaultAddress -TokenDir $tokenDir -Policy $policy -TokenTtl $tokenTtl @commonParams | Out-Null
        # Reload config so downstream path resolution uses the updated config.
        $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
        try { $vaultCfg = Get-JaxVaultPluginConfig -RepoRoot $repoRoot -Config $config } catch {}
    }

    $tokenPath = Get-JaxVaultTokenPath -RepoRoot $repoRoot -Config $config @commonParams

    $vaultTokenIsNonEmpty = -not [string]::IsNullOrWhiteSpace($VaultToken)
    $methodWasExplicit = $PSBoundParameters.ContainsKey('Method') -and -not [string]::IsNullOrWhiteSpace($Method)
    $tokenWasExplicitAndNonEmpty = $PSBoundParameters.ContainsKey('VaultToken') -and $vaultTokenIsNonEmpty

    # UX: env vars should NOT suppress the auth method prompt (token can be stale/expired).
    # Only skip prompting when user explicitly provided a non-empty token or explicitly specified method.
    if (-not $tokenWasExplicitAndNonEmpty -and -not $methodWasExplicit) {
        $allowedMethods = @('github', 'token')
        $Method = Read-JaxPromptString -Prompt "Select authentication method (github/token)" -Default 'github'
        if (-not ($allowedMethods -contains $Method.ToLowerInvariant())) {
            Write-Warning "Unknown auth method '$Method'. Falling back to 'token'."
            $Method = 'token'
        }
    }
    if ([string]::IsNullOrWhiteSpace($Method)) {
        $Method = 'token'
    }

    $Method = $Method.ToLowerInvariant()
    Write-Verbose "Selected method: $Method"
    if ($Method -eq 'github') {
        Write-Host "Authenticating via GitHub at auth/$authMount..." -ForegroundColor Cyan
        try {
            # Check if we have a GH token in env, else prompt
            $ghToken = if (Test-Path Env:\GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { $null }

            if ([string]::IsNullOrWhiteSpace($ghToken)) {
                $ghToken = Read-Host -Prompt "Enter GitHub Personal Access Token (hidden)" -AsSecureString | ConvertFrom-SecureString -AsPlainText
            }

            if ([string]::IsNullOrWhiteSpace($ghToken)) {
                Write-Error "GitHub token is required."
                return
            }

            # Send the GitHub token over stdin so it is not exposed in the
            # Vault process argument list. The configured mount supports
            # non-default paths such as auth/github-production.
            $json = $ghToken | vault write -format=json "auth/$authMount/login" 'token=-' 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
                Write-Error "Vault login with GitHub failed at auth/$authMount."
                return
            }

            $loginData = $json | ConvertFrom-Json
            $VaultToken = $loginData.auth.client_token
            Write-Host "Successfully authenticated with Vault via GitHub." -ForegroundColor Green

        } catch {
            Write-Error "Error during GitHub authentication: $_"
            return
        }
    } elseif ($Method -eq 'token') {
        if ([string]::IsNullOrWhiteSpace($VaultToken)) {
            $VaultToken = Read-Host -Prompt "Enter Vault Token (hidden)" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        }
    } else {
        Write-Warning "Method '$Method' is not yet fully implemented. Falling back to token prompt."
        if ([string]::IsNullOrWhiteSpace($VaultToken)) {
            $VaultToken = Read-Host -Prompt "Enter Vault Token (hidden)" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        }
    }

    if ([string]::IsNullOrWhiteSpace($VaultToken)) {
        Write-Error "Token cannot be empty."
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($policy)) {
        # Keep a reference to the current token (typically the GitHub login token) so warnings are not misleading.
        $loginToken = $VaultToken

        $env:VAULT_TOKEN = $VaultToken

        # Capture stderr so we can explain failures (do not swallow Vault errors).
        # Use an explicit args array to avoid any accidental literal `$tokenTtl` being passed through.
        $ttlArg = "-ttl=$tokenTtl"
        $formatArg = '-format=json'
        $policyArg = "-policy=$policy"
        $tokenCreateOutput = & vault token create $ttlArg $formatArg $policyArg 2>&1
        $tokenCreateExitCode = $LASTEXITCODE

        if ($tokenCreateExitCode -eq 0 -and $tokenCreateOutput) {
            try {
                $tokenData = $tokenCreateOutput | ConvertFrom-Json -ErrorAction Stop
                if ($tokenData -and $tokenData.auth -and $tokenData.auth.client_token) {
                    $VaultToken = [string]$tokenData.auth.client_token
                    Write-Host "Created token with TTL '$tokenTtl' and policy '$policy'." -ForegroundColor Green
                } else {
                    Write-Warning "Vault token create succeeded but returned no token; keeping current login token."
                }
            } catch {
                Write-Warning "Failed to parse token create response; keeping current login token."
            }
        } else {
            $details = $null
            if ($tokenCreateOutput) {
                $details = ([string]$tokenCreateOutput).Trim()
            }
            if ([string]::IsNullOrWhiteSpace($details)) {
                Write-Warning "Vault token create failed for policy '$policy' (ttl: '$tokenTtl', exit: $tokenCreateExitCode); keeping current login token."
            } else {
                Write-Warning "Vault token create failed for policy '$policy' (ttl: '$tokenTtl', exit: $tokenCreateExitCode). Vault said: $details"
            }

            # Restore the login token explicitly (defensive) and continue.
            $VaultToken = $loginToken
        }
    }

    # Verify/Validate by making a simple call?
    # For now, just save it.

    $tokenDir = Split-Path -Parent $tokenPath
    if (-not (Test-Path $tokenDir)) {
        New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null
    }
    Set-Content -Path $tokenPath -Value $VaultToken -Force
    Set-JaxVaultTokenPermissions -TokenDirectory $tokenDir -TokenPath $tokenPath

    # Also set in current session
    $env:VAULT_TOKEN = $VaultToken

    Write-Host "Vault token saved successfully." -ForegroundColor Green
}
