# NOTE:
# Helper functions must live in module script scope (not inside Register-JaxDockerPlugin),
# because hook scriptblocks execute later and need to resolve these names.
function Get-JaxDockerIsCi {
    if (-not [string]::IsNullOrWhiteSpace($env:TEAMCITY_VERSION)) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($env:TEAMCITY_BUILD_PROPERTIES_FILE)) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($env:CI)) {
        $val = $env:CI.ToString().Trim().ToLowerInvariant()
        if ($val -eq '1' -or $val -eq 'true' -or $val -eq 'yes') { return $true }
    }
    return $false
}

function Get-JaxDockerDefaultsFromConfig {
    param(
        [System.Collections.IDictionary] $pluginConfig,
        [bool] $isCi
    )

    $localDefaults = @{
        push          = $false
        onlyLocalArch = $true
    }
    $ciDefaults = @{
        push          = $true
        onlyLocalArch = $false
    }

    if ($null -ne $pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
        if ($pluginConfig.Contains('defaults') -and $pluginConfig['defaults'] -is [System.Collections.IDictionary]) {
            $defs = $pluginConfig['defaults']
            if ($defs.Contains('local') -and $defs['local'] -is [System.Collections.IDictionary]) {
                $l = $defs['local']
                if ($l.Contains('push') -and $l['push'] -is [bool]) { $localDefaults.push = [bool]$l['push'] }
                if ($l.Contains('onlyLocalArch') -and $l['onlyLocalArch'] -is [bool]) { $localDefaults.onlyLocalArch = [bool]$l['onlyLocalArch'] }
            }
            if ($defs.Contains('ci') -and $defs['ci'] -is [System.Collections.IDictionary]) {
                $c = $defs['ci']
                if ($c.Contains('push') -and $c['push'] -is [bool]) { $ciDefaults.push = [bool]$c['push'] }
                if ($c.Contains('onlyLocalArch') -and $c['onlyLocalArch'] -is [bool]) { $ciDefaults.onlyLocalArch = [bool]$c['onlyLocalArch'] }
            }
        }
    }

    if ($isCi) { return $ciDefaults }
    return $localDefaults
}

function Get-JaxDockerStateOverrides {
    param(
        [hashtable] $context
    )

    $stateOnlyLocalArch = $null
    $stateUseLocalRegistry = $null

    if ($context.ContainsKey('State') -and $context['State'] -is [System.Collections.IDictionary]) {
        $st = $context['State']
        if ($st.Contains('plugins') -and $st['plugins'] -is [System.Collections.IDictionary]) {
            $plugins = $st['plugins']
            if ($plugins.Contains('docker') -and $plugins['docker'] -is [System.Collections.IDictionary]) {
                $prefs = $plugins['docker']
                if ($prefs.Contains('onlyLocalArch') -and $prefs['onlyLocalArch'] -is [bool]) { $stateOnlyLocalArch = [bool]$prefs['onlyLocalArch'] }
                if ($prefs.Contains('useLocalRegistry') -and $prefs['useLocalRegistry'] -is [bool]) { $stateUseLocalRegistry = [bool]$prefs['useLocalRegistry'] }
            }
        }
    }

    return @{
        # push is intentionally not persisted; require explicit CLI flag or config default.
        push             = $null
        onlyLocalArch    = $stateOnlyLocalArch
        useLocalRegistry = $stateUseLocalRegistry
    }
}

function Get-JaxDockerEffectiveSettings {
    param(
        [hashtable] $context,
        [System.Collections.IDictionary] $resolved,
        [System.Collections.IDictionary] $pluginConfig
    )

    $isCi = Get-JaxDockerIsCi
    $defaults = Get-JaxDockerDefaultsFromConfig -pluginConfig $pluginConfig -isCi $isCi
    $push = [bool]$defaults.push
    $onlyLocalArch = [bool]$defaults.onlyLocalArch
    $useLocalRegistry = $false
    $remoteBuildxK8s = $false

    # Apply persisted preferences (if present)
    $stateOverrides = Get-JaxDockerStateOverrides -context $context
    if ($stateOverrides.push -is [bool]) { $push = [bool]$stateOverrides.push }
    if ($stateOverrides.onlyLocalArch -is [bool]) { $onlyLocalArch = [bool]$stateOverrides.onlyLocalArch }
    if ($stateOverrides.useLocalRegistry -is [bool]) { $useLocalRegistry = [bool]$stateOverrides.useLocalRegistry }

    # CLI overrides always win
    $hasPushOverride = $false
    $hasLocalArchOverride = $false
    $hasUseLocalRegistryOverride = $false
    $hasRemoteBuildxOverride = $false
    if ($null -ne $resolved -and $resolved -is [System.Collections.IDictionary]) {
        if ($resolved.Contains('pushToDockerRegistry') -and [bool]$resolved['pushToDockerRegistry']) {
            $push = $true
            $useLocalRegistry = $false
            $hasPushOverride = $true
            $hasUseLocalRegistryOverride = $true
        }
        if ($resolved.Contains('pushLocal') -and [bool]$resolved['pushLocal']) {
            $push = $true
            $useLocalRegistry = $true
            $hasPushOverride = $true
            $hasUseLocalRegistryOverride = $true
        }
        if ($resolved.Contains('remoteBuildxK8s') -and [bool]$resolved['remoteBuildxK8s']) {
            $remoteBuildxK8s = $true
            $hasRemoteBuildxOverride = $true
        }
        # Arch selection:
        # - default comes from config (plugins.config.docker.defaults.*.onlyLocalArch)
        # - `-onlyLocalArch` forces single-arch
        # - `-allArch` forces multi-arch (i.e. disables onlyLocalArch) for this run
        if ($resolved.Contains('allArch') -and [bool]$resolved['allArch']) {
            $onlyLocalArch = $false
            $hasLocalArchOverride = $true
        }
        if ($resolved.Contains('onlyLocalArch') -and [bool]$resolved['onlyLocalArch']) {
            $onlyLocalArch = $true
            $hasLocalArchOverride = $true
        }
    }

    # Safety: require explicit CLI push flag to push.
    if (-not $hasPushOverride) {
        $push = $false
        $useLocalRegistry = $false
    }

    # Multi-arch without pushing is not generally useful; default to onlyLocalArch.
    # If user explicitly overrode arch selection via CLI, respect it.
    if ((-not $push) -and (-not $onlyLocalArch) -and (-not $hasLocalArchOverride)) {
        $onlyLocalArch = $true
    }

    $hasCliOverride = ($hasPushOverride -or $hasLocalArchOverride -or $hasUseLocalRegistryOverride -or $hasRemoteBuildxOverride)
    return @{
        push             = $push
        onlyLocalArch    = $onlyLocalArch
        useLocalRegistry = $useLocalRegistry
        remoteBuildxK8s  = $remoteBuildxK8s
        isCi             = $isCi
        hasCliOverride   = $hasCliOverride
    }
}

function Get-JaxDockerLocalRegistryOverrides {
    param(
        [System.Collections.IDictionary] $pluginConfig
    )

    $localRegistryName = $null
    $localThirdpartyNamespace = $null

    if ($null -ne $pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
        if ($pluginConfig.Contains('localRegistry') -and $pluginConfig['localRegistry'] -is [System.Collections.IDictionary]) {
            $lr = $pluginConfig['localRegistry']
            if ($lr.Contains('name') -and $lr['name'] -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$lr['name'])) {
                $localRegistryName = [string]$lr['name']
            }
            if ($lr.Contains('thirdpartyNamespace') -and $lr['thirdpartyNamespace'] -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$lr['thirdpartyNamespace'])) {
                $localThirdpartyNamespace = [string]$lr['thirdpartyNamespace']
            }
        }
    }

    return @{
        name                = $localRegistryName
        thirdpartyNamespace = $localThirdpartyNamespace
    }
}

function Register-JaxDockerPlugin {
    [CmdletBinding()]
    param()

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    if ($null -eq $commonParams) {
        $commonParams = @{}
    }

    # Compatibility CLI flags
    Register-JaxCliParameter `
        -Name 'pushToDockerRegistry' `
        -Aliases @('push', 'pushdocker', 'pushharbor', 'pushtodocker') `
        -Type 'switch' `
        -Scope 'docker'

    Register-JaxCliParameter -Name 'onlyLocalArch' -Aliases @() -Type 'switch' -Scope 'docker'
    Register-JaxCliParameter -Name 'allArch' -Aliases @('multiArch', 'multiarch') -Type 'switch' -Scope 'docker'
    Register-JaxCliParameter -Name 'pushLocal' -Aliases @() -Type 'switch' -Scope 'docker'
    Register-JaxCliParameter -Name 'remoteBuildxK8s' -Aliases @('rbk8s', 'remoteBuild') -Type 'switch' -Scope 'docker'

    # Persisted preference defaults (stored under state.plugins.docker.*)
    Register-JaxPersistentSetting -Scope 'plugins' -Key 'docker' -Default @{
        push             = $null
        onlyLocalArch    = $null
        useLocalRegistry = $null
    }

    $hooks = @{
        # Persist and apply docker build-related preferences.
        # This runs before the header is printed so follow-up hooks can see the effective settings.
        'BeforeRunHeader'   = {
            param($hook)

            $context = $hook.Context
            $pluginConfig = $hook.PluginConfig

            $resolved = $null
            if ($hook.Data -and $hook.Data.ContainsKey('Resolved')) {
                $resolved = $hook.Data['Resolved']
            }

            $effective = Get-JaxDockerEffectiveSettings -context $context -resolved $resolved -pluginConfig $pluginConfig

            # Persist user choice only when explicitly overridden via CLI.
            $noSave = $false
            if ($context.ContainsKey('NoSavedSettings') -and [bool]$context['NoSavedSettings']) { $noSave = $true }
            if ($resolved -and $resolved.Contains('noSavedSettings') -and [bool]$resolved['noSavedSettings']) { $noSave = $true }

            if ($effective.hasCliOverride -and (-not $noSave)) {
                Update-JaxState -RepoRoot $context['RepoRoot'] -Updates @{
                    plugins = @{
                        docker = @{
                            onlyLocalArch    = [bool]$effective.onlyLocalArch
                            useLocalRegistry = [bool]$effective.useLocalRegistry
                        }
                    }
                } | Out-Null
            }

            $context['DockerBuildSettings'] = $effective
            if ($resolved -and $resolved -is [System.Collections.IDictionary]) {
                $resolved['dockerBuildSettings'] = $effective
            }
        }

        # Inject docker build/push settings into the psake/script property merge pipeline:
        # RunConfig -> PsakeProperties -> Entity.Args -> CliArgs (highest precedence)
        'BeforeRunEntities' = {
            param($hook)

            $context = $hook.Context
            $pluginConfig = $hook.PluginConfig

            $effective = $null
            if ($context.ContainsKey('DockerBuildSettings') -and $context['DockerBuildSettings'] -is [System.Collections.IDictionary]) {
                $effective = $context['DockerBuildSettings']
            } else {
                $resolved = $null
                if ($context.ContainsKey('ResolvedOptions') -and $context['ResolvedOptions'] -is [System.Collections.IDictionary]) {
                    $resolved = $context['ResolvedOptions']
                }
                $effective = Get-JaxDockerEffectiveSettings -context $context -resolved $resolved -pluginConfig $pluginConfig
            }

            $override = @{
                module = @{
                    docker = @{
                        push          = [bool]$effective.push
                        onlyLocalArch = [bool]$effective.onlyLocalArch
                        buildx        = @{
                            remoteKubernetes = [bool]$effective.remoteBuildxK8s
                        }
                    }
                }
            }

            if ([bool]$effective.remoteBuildxK8s -and $pluginConfig -and $pluginConfig.Contains('remoteBuildxK8s') -and $pluginConfig['remoteBuildxK8s'] -is [System.Collections.IDictionary]) {
                $rb = $pluginConfig['remoteBuildxK8s']
                if ($rb.Contains('builderName')) {
                    $override.module.docker.buildx['builderName'] = [string]$rb['builderName']
                }
                if ($rb.Contains('kubernetesNamespace')) {
                    $override.module.docker.buildx['kubernetesNamespace'] = [string]$rb['kubernetesNamespace']
                }
                if ($rb.Contains('kubeContext')) {
                    $override.module.docker.buildx['kubeContext'] = [string]$rb['kubeContext']
                }
            }

            if ([bool]$effective.useLocalRegistry) {
                $localReg = Get-JaxDockerLocalRegistryOverrides -pluginConfig $pluginConfig
                if (-not [string]::IsNullOrWhiteSpace($localReg.name)) {
                    $override.module.docker['registry'] = @{ name = $localReg.name }
                } else {
                    Write-Warning "[docker] -pushLocal was set but plugins.config.docker.localRegistry.name is not configured; leaving registry unchanged."
                }
                if (-not [string]::IsNullOrWhiteSpace($localReg.thirdpartyNamespace)) {
                    if (-not $override.module.docker.ContainsKey('registry')) {
                        $override.module.docker['registry'] = @{}
                    }
                    $override.module.docker.registry['thirdparty_images'] = $localReg.thirdpartyNamespace
                }
            }

            $existingCliArgs = @{}
            if ($context.ContainsKey('CliArgs') -and $context['CliArgs'] -is [System.Collections.IDictionary]) {
                $existingCliArgs = $context['CliArgs']
            }
            $context['CliArgs'] = Merge-JaxHashtable -Base $existingCliArgs -Overlay $override
        }
    }

    Register-JaxPlugin -Name 'docker' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path @commonParams
}

# Auto-register on import
Register-JaxDockerPlugin
