[CmdletBinding()]
param ()

$coreModulePath = Join-Path $PSScriptRoot 'core/Jax.Core.psm1'
Import-Module $coreModulePath -Force

# Autocomplete must be lightweight and must not import plugins:
# - registration should not depend on plugin modules being present
# - plugin registration expects core symbols in global scope, which is not guaranteed here

function New-JaxCompletionResult {
    param (
        [string] $Value,
        [string] $Display,
        [string] $ToolTip
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $label = if ([string]::IsNullOrWhiteSpace($Display)) { $Value } else { $Display }
    $tip = if ([string]::IsNullOrWhiteSpace($ToolTip)) { $label } else { $ToolTip }
    return [System.Management.Automation.CompletionResult]::new($Value, $label, 'ParameterValue', $tip)
}

function Get-JaxAutocompleteConfig {
    try {
        $cfg = Get-JaxConfig
        if ($cfg -is [System.Collections.IDictionary] -and $cfg.Contains('autocomplete') -and $cfg['autocomplete'] -is [System.Collections.IDictionary]) {
            return $cfg['autocomplete']
        }
    } catch {
    }
    return @{}
}

function Get-JaxAutocompleteIconMap {
    param(
        [System.Collections.IDictionary] $Config,
        [string] $Key
    )
    if ($null -ne $Config -and $Config.Contains($Key) -and $Config[$Key] -is [System.Collections.IDictionary]) {
        return $Config[$Key]
    }
    return @{}
}

function Get-JaxAutocompleteIconForKey {
    param(
        [System.Collections.IDictionary] $Map,
        [string] $Key,
        [string] $DefaultIcon
    )
    if ([string]::IsNullOrWhiteSpace($Key)) {
        return $DefaultIcon
    }
    if ($null -ne $Map -and $Map.Contains($Key)) {
        $v = $Map[$Key]
        if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) {
            return $v
        }
    }
    return $DefaultIcon
}

function Get-JaxAutocompleteOptionalIconForKey {
    param(
        [System.Collections.IDictionary] $Map,
        [string] $Key
    )
    if ([string]::IsNullOrWhiteSpace($Key)) {
        return $null
    }
    if ($null -ne $Map -and $Map.Contains($Key)) {
        $v = $Map[$Key]
        if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) {
            return $v
        }
    }
    return $null
}

function Get-JaxCompletionComputedEnvDisplay {
    param(
        [string] $Value,
        [System.Collections.IDictionary] $ClientIcons,
        [System.Collections.IDictionary] $FlowIcons,
        [string] $FallbackIcon
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $FallbackIcon
    }

    $pathParts = @($Value -split '/' | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($pathParts.Count -eq 0) {
        return "{0} {1}" -f $FallbackIcon, $Value
    }

    $firstPathPart = [string]$pathParts[0]
    $lastPathPart = [string]$pathParts[-1]
    $primaryIcon = Get-JaxAutocompleteIconForKey -Map $ClientIcons -Key $firstPathPart -DefaultIcon $FallbackIcon
    $secondaryIcon = $null
    if ($pathParts.Count -gt 1) {
        $secondaryIcon = Get-JaxAutocompleteOptionalIconForKey -Map $FlowIcons -Key $lastPathPart
    }

    if (-not [string]::IsNullOrWhiteSpace($secondaryIcon) -and $secondaryIcon -ne $primaryIcon) {
        return "{0} {1} {2}" -f $primaryIcon, $secondaryIcon, $Value
    }

    return "{0} {1}" -f $primaryIcon, $Value
}

function Get-JaxEnvAndFlowSelectionForCompletion {
    param(
        [string] $EnvWithOptionalFlow,
        [object[]] $Environments
    )
    $flowOverride = $null
    $envCandidate = $EnvWithOptionalFlow
    $hasEnvWithFlowCandidate = (-not [string]::IsNullOrWhiteSpace($EnvWithOptionalFlow)) -and $EnvWithOptionalFlow.Contains('/')
    if ($hasEnvWithFlowCandidate) {
        $parts = $EnvWithOptionalFlow -split '/'
        if ($parts.Count -gt 1) {
            $maybeFlow = $parts[-1]
            $maybeEnv = ($parts[0..($parts.Count - 2)] -join '/')
            $hasFlowOverrideCandidate = (-not [string]::IsNullOrWhiteSpace($maybeFlow)) -and (-not [string]::IsNullOrWhiteSpace($maybeEnv))
            if ($hasFlowOverrideCandidate) {
                $envMatch = $Environments | Where-Object { $_ -and $_.Name -and ([string]$_.Name -eq $maybeEnv) } | Select-Object -First 1
                if ($null -ne $envMatch) {
                    $hasFlow = $false
                    foreach ($flowCfg in @($envMatch.FlowConfigs)) {
                        $hasFlowConfig = ($null -ne $flowCfg) -and ($flowCfg.PSObject.Properties.Match('Configuration').Count -gt 0)
                        if ($hasFlowConfig) {
                            if ([string]$flowCfg.Configuration -eq $maybeFlow) {
                                $hasFlow = $true
                                break
                            }
                        }
                    }
                    if ($hasFlow) {
                        $flowOverride = $maybeFlow
                        $envCandidate = $maybeEnv
                    }
                }
            }
        }
    }
    $env = Resolve-JaxSelectedEnvironment -Environments $Environments -Env $envCandidate
    return [pscustomobject]@{
        Environment  = $env
        FlowOverride = $flowOverride
    }
}

function Get-JaxCompletionEnvChoices {
    param(
        [string] $StartsWith
    )
    $config = Get-JaxConfig
    $envs = Get-JaxEnvironments -Config $config
    $autoCfg = Get-JaxAutocompleteConfig
    $clientIcons = Get-JaxAutocompleteIconMap -Config $autoCfg -Key 'clientIcons'
    $flowIcons = Get-JaxAutocompleteIconMap -Config $autoCfg -Key 'flowIcons'

    # Reasonable defaults (can be overridden in config.autocomplete.*Icons)
    if (-not $flowIcons.Contains('build')) { $flowIcons['build'] = '🔨' }
    if (-not $flowIcons.Contains('pack')) { $flowIcons['pack'] = '📦' }
    if (-not $flowIcons.Contains('play')) { $flowIcons['play'] = '🧪' }
    if (-not $flowIcons.Contains('dev')) { $flowIcons['dev'] = '🧑‍💻' }
    if (-not $flowIcons.Contains('uat')) { $flowIcons['uat'] = '🧫' }
    if (-not $flowIcons.Contains('prod')) { $flowIcons['prod'] = '🚀' }
    if (-not $clientIcons.Contains('demo')) { $clientIcons['demo'] = '🧪' }
    if (-not $clientIcons.Contains('generic')) { $clientIcons['generic'] = '🌐' }
    if (-not $clientIcons.Contains('none')) { $clientIcons['none'] = '🚫' }
    if (-not $clientIcons.Contains('build')) { $clientIcons['build'] = '👷' }

    $choices = @()
    foreach ($env in @($envs | Sort-Object -Property Name)) {
        if ($null -eq $env -or [string]::IsNullOrWhiteSpace($env.Name)) {
            continue
        }
        $clientKey = ($env.Name -split '/')[0]
        $clientIcon = Get-JaxAutocompleteIconForKey -Map $clientIcons -Key $clientKey -DefaultIcon '📁'
        $flowConfigs = @($env.FlowConfigs)
        if ($flowConfigs.Count -eq 0) {
            $value = $env.Name
            $isComputedEnv = ($env.PSObject.Properties.Match('IsComputed').Count -gt 0) -and $env.IsComputed
            if ($env.PSObject.Properties.Match('PreferredCompletionName').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$env.PreferredCompletionName)) {
                $value = [string]$env.PreferredCompletionName
            }
            if (-not [string]::IsNullOrWhiteSpace($StartsWith) -and $value -notlike "$StartsWith*") {
                continue
            }
            $display = if ($isComputedEnv) {
                Get-JaxCompletionComputedEnvDisplay -Value $value -ClientIcons $clientIcons -FlowIcons $flowIcons -FallbackIcon $clientIcon
            } else {
                "{0} {1}" -f $clientIcon, $value
            }
            $tip = if ($env.EnvDir) { $env.EnvDir } else { 'no flow configs' }
            $aliasText = ''
            if ($env.PSObject.Properties.Match('Aliases').Count -gt 0) {
                $aliases = @($env.Aliases | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                if ($aliases.Count -gt 0) {
                    $aliasText = "`naliases: {0}" -f ($aliases -join ', ')
                }
            }
            if ($value -ne $env.Name) {
                $tip = "{0}`ncanonical: {1}{2}" -f $tip, $env.Name, $aliasText
            } elseif (-not [string]::IsNullOrWhiteSpace($aliasText)) {
                $tip = "{0}{1}" -f $tip, $aliasText
            }
            $choices += [pscustomobject]@{
                Name        = $value
                DisplayText = $display
                ToolTip     = $tip
            }
            continue
        }
        foreach ($flowCfg in $flowConfigs) {
            $flowName = [string]$flowCfg.Configuration
            if ([string]::IsNullOrWhiteSpace($flowName)) {
                continue
            }
            $value = "$($env.Name)/$flowName"
            if (-not [string]::IsNullOrWhiteSpace($StartsWith) -and $value -notlike "$StartsWith*") {
                continue
            }
            $flowIcon = Get-JaxAutocompleteIconForKey -Map $flowIcons -Key $flowName -DefaultIcon '⚙️'
            $display = "{0} {1} {2}  [{3}]" -f $clientIcon, $flowIcon, $env.Name, $flowName
            $tip = "{0}`nflow: {1}`nconfig: {2}" -f $env.EnvDir, $flowName, $flowCfg.ConfigPath
            $choices += [pscustomobject]@{
                Name        = $value
                DisplayText = $display
                ToolTip     = $tip
            }
        }
    }
    return $choices
}

function Get-JaxCompletionCommands {
    $commands = @(
        'help',
        'init',
        'init-compat',
        'env',
        'list-envs',
        'run',
        'r',
        'invoke',
        'plan',
        'autocomplete',
        'create-flavour',
        'settings',
        'skill',
        'info',
        'vault'
    )
    try {
        foreach ($entry in Get-JaxHelpEntries) {
            if ($entry -and $entry.Name) {
                $commands += [string]$entry.Name
            }
        }
    } catch {
    }
    return @($commands | Sort-Object -Unique)
}

function Get-JaxCompletionVaultCommands {
    return @('set', 'login', 'status', 'info', 'reset', 'help')
}

function Get-JaxCompletionFlags {
    $flags = @()
    try {
        foreach ($param in Get-JaxCliParameters) {
            if (-not $param) { continue }
            if ($param.Name) {
                $flags += ('-' + ([string]$param.Name).ToLowerInvariant())
            }
            foreach ($alias in @($param.Aliases)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$alias)) {
                    $flags += ('-' + ([string]$alias).ToLowerInvariant())
                }
            }
        }
    } catch {
    }
    return @($flags | Sort-Object -Unique)
}

function Get-JaxCompletionEnvironments {
    try {
        $config = Get-JaxConfig
        $envs = Get-JaxEnvironments -Config $config
        return @($envs | Sort-Object -Property Name)
    } catch {
        return @()
    }
}

function Get-JaxCompletionEnvNames {
    # env values are envName/flowConfig (e.g. sample-app/build)
    return @(Get-JaxCompletionEnvChoices | ForEach-Object { $_.Name } | Sort-Object -Unique)
}

function Get-JaxCompletionShortcutItems {
    <#
    .SYNOPSIS
        Shortcut name plus DisplayText/ToolTip. Tab completion uses Name as the list label;
        ToolTip carries the expansion; DisplayText is the ▶-prefixed line (tests / callers).
    #>
    $items = @()
    try {
        $config = Get-JaxConfig
        if ($config -is [System.Collections.IDictionary] -and $config.Contains('shortcuts') -and $config['shortcuts'] -is [System.Collections.IDictionary]) {
            $shortcuts = $config['shortcuts']
            foreach ($name in @($shortcuts.Keys | Sort-Object)) {
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                $raw = $shortcuts[$name]
                $args = @()
                if ($raw -is [System.Collections.IEnumerable] -and $raw -isnot [string]) {
                    $args = @($raw)
                } elseif ($null -ne $raw) {
                    $args = @($raw)
                }
                $argStr = if ($args.Count -gt 0) { ($args -join ' ').Trim() } else { '' }
                if ([string]::IsNullOrWhiteSpace($argStr)) { $argStr = '(empty)' }
                $items += [pscustomobject]@{
                    Name        = [string]$name
                    DisplayText = "▶ ${name}: $argStr"
                    ToolTip     = ('Shortcut: {0} -> `{1}`' -f $name, $argStr)
                }
            }
        }
    } catch {
    }
    return $items
}

function Get-JaxCompletionShortcutNames {
    return @((Get-JaxCompletionShortcutItems | ForEach-Object { $_.Name }) | Sort-Object)
}

function Get-JaxCompletionLastEnv {
    try {
        $repoRoot = Get-JaxRepoRoot
        $state = Get-JaxState -RepoRoot $repoRoot -ErrorAction SilentlyContinue
        if ($state -is [System.Collections.IDictionary] -and $state.Contains('core') -and $state['core'] -is [System.Collections.IDictionary]) {
            $core = $state['core']
            if ($core.Contains('env') -and -not [string]::IsNullOrWhiteSpace($core['env'])) {
                return $core['env']
            }
        }
    } catch {
    }
    return $null
}

function Get-JaxCompletionClients {
    $clients = @()
    foreach ($name in Get-JaxCompletionEnvNames) {
        if ($name -and $name.Contains('/')) {
            $clients += $name.Split('/')[0]
        }
    }
    return @($clients | Sort-Object -Unique)
}

function Get-JaxCompletionScenarioNames {
    param (
        [string] $EnvName
    )
    try {
        $config = Get-JaxConfig
        $envs = Get-JaxEnvironments -Config $config
        $selection = Get-JaxEnvAndFlowSelectionForCompletion -EnvWithOptionalFlow $EnvName -Environments $envs
        $env = $selection.Environment
        if ($null -eq $env) {
            return @()
        }
        $preferred = if ([string]::IsNullOrWhiteSpace($selection.FlowOverride)) { 'build' } else { $selection.FlowOverride }
        $flowConfig = Resolve-JaxSelectedFlowConfig -Environment $env -PreferredConfig $preferred
        if ($null -eq $flowConfig) {
            return @()
        }
        $flow = Get-JaxFlowConfig -Paths $flowConfig.ConfigPaths -ExpandVariables:$false
        return @(Get-JaxScenarioNames -FlowConfig $flow)
    } catch {
        return @()
    }
}

function Get-JaxCompletionTaskKeys {
    param (
        [string] $EnvName,
        [string] $ScenarioName
    )
    try {
        $config = Get-JaxConfig
        $envs = Get-JaxEnvironments -Config $config
        $selection = Get-JaxEnvAndFlowSelectionForCompletion -EnvWithOptionalFlow $EnvName -Environments $envs
        $env = $selection.Environment
        if ($null -eq $env) {
            return @()
        }
        $skipEnvRoot = $false
        if ($env.PSObject.Properties.Match('SkipEnvRoot').Count -gt 0 -and $env.SkipEnvRoot) {
            $skipEnvRoot = $true
        }
        if ($env.PSObject.Properties.Match('IsDummy').Count -gt 0 -and $env.IsDummy) {
            $skipEnvRoot = $true
        }
        $preferred = if ([string]::IsNullOrWhiteSpace($selection.FlowOverride)) { 'build' } else { $selection.FlowOverride }
        $flowConfig = Resolve-JaxSelectedFlowConfig -Environment $env -PreferredConfig $preferred
        $flow = $null
        if ($null -ne $flowConfig) {
            $flow = Get-JaxFlowConfig -Paths $flowConfig.ConfigPaths -ExpandVariables:$false
        }
        $context = @{
            RepoRoot = Get-JaxRepoRoot
            EnvDir   = $env.EnvDir
            Config   = $config
        }
        $discovered = Get-JaxDiscoveredRunEntities -RepoRoot $context.RepoRoot -EnvDir $context.EnvDir -Config $config -SkipEnvRoot:$skipEnvRoot
        $context['DiscoveredEntities'] = $discovered
        $context['DiscoveredEntityIndex'] = New-JaxRunEntityIndex -Entities $discovered

        $entities = @()
        # Completion must be fast and must not require plugin resolvers.
        # We include:
        # - discovered tasks/scripts
        # - build keys (suite.build or suite.modules keys)
        # - scenario step keys for the selected scenario (suite.scenarios.<scenario>)
        $entities += $discovered

        $suite = $null
        if ($flow -is [System.Collections.IDictionary] -and $flow.Contains('suite')) {
            $suite = $flow['suite']
        }
        if ($suite -is [System.Collections.IDictionary]) {
            $buildSection = $null
            $buildSectionNames = Get-JaxBuildSectionNames -Config $config
            foreach ($sectionName in @($buildSectionNames)) {
                if ($suite.Contains($sectionName)) {
                    $buildSection = $suite[$sectionName]
                    break
                }
            }
            if ($buildSection -is [System.Collections.IDictionary]) {
                foreach ($k in $buildSection.Keys) {
                    if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                    $buildKey = [string]$k
                    $entities += [ordered]@{ Key = $buildKey; Runner = 'scenario'; Provenance = 'build'; SourcePath = $flowConfig.ConfigPath; Aliases = @() }

                    # Also include explicit tasks listed under the build entry (so completion can suggest them).
                    $buildEntry = $buildSection[$k]
                    $tasks = $null
                    if ($buildEntry -is [string]) {
                        $tasks = @($buildEntry)
                    } elseif ($buildEntry -is [System.Collections.IDictionary]) {
                        if ($buildEntry.Contains('tasks')) { $tasks = $buildEntry['tasks'] }
                        elseif ($buildEntry.Contains('task')) { $tasks = $buildEntry['task'] }
                    }
                    if ($tasks -is [string]) {
                        $tasks = @($tasks)
                    }
                    if ($tasks -is [System.Collections.IEnumerable] -and $tasks -isnot [string]) {
                        foreach ($taskName in @($tasks)) {
                            if (-not [string]::IsNullOrWhiteSpace([string]$taskName)) {
                                $entities += [ordered]@{ Key = [string]$taskName; Runner = 'psake'; Provenance = "build:$buildKey"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }
                            }
                        }
                    }
                }
            }

            $scenarios = $null
            if ($suite.Contains('scenarios')) { $scenarios = $suite['scenarios'] }
            if ($scenarios -is [System.Collections.IDictionary]) {
                $scenarioToUse = $ScenarioName
                if ([string]::IsNullOrWhiteSpace($scenarioToUse)) {
                    if ($scenarios.Contains('default')) { $scenarioToUse = 'default' } else { $scenarioToUse = ($scenarios.Keys | Select-Object -First 1) }
                }
                if (-not [string]::IsNullOrWhiteSpace($scenarioToUse) -and $scenarios.Contains($scenarioToUse)) {
                    $scenarioConfig = $scenarios[$scenarioToUse]
                    if ($scenarioConfig -is [System.Collections.IDictionary]) {
                        foreach ($k in $scenarioConfig.Keys) {
                            if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                            $scenarioKey = [string]$k
                            $entities += [ordered]@{ Key = $scenarioKey; Runner = 'scenario'; Provenance = "scenario:$scenarioToUse"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }

                            $stepEntry = $scenarioConfig[$k]
                            $tasks = $null
                            if ($stepEntry -is [string]) {
                                $tasks = @($stepEntry)
                            } elseif ($stepEntry -is [System.Collections.IDictionary]) {
                                if ($stepEntry.Contains('tasks')) { $tasks = $stepEntry['tasks'] }
                                elseif ($stepEntry.Contains('task')) { $tasks = $stepEntry['task'] }
                            }
                            if ($tasks -is [string]) {
                                $tasks = @($tasks)
                            }
                            if ($tasks -is [System.Collections.IEnumerable] -and $tasks -isnot [string]) {
                                foreach ($taskName in @($tasks)) {
                                    if (-not [string]::IsNullOrWhiteSpace([string]$taskName)) {
                                        $entities += [ordered]@{ Key = [string]$taskName; Runner = 'psake'; Provenance = "scenario:${scenarioToUse}:${scenarioKey}"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }
                                    }
                                }
                            }
                        }
                    } elseif ($scenarioConfig -is [System.Collections.IEnumerable] -and $scenarioConfig -isnot [string]) {
                        foreach ($item in @($scenarioConfig)) {
                            if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                                $entities += [ordered]@{ Key = [string]$item; Runner = 'scenario'; Provenance = "scenario:$scenarioToUse"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }
                                continue
                            }
                            if ($item -is [System.Collections.IDictionary] -and $item.Count -eq 1) {
                                $ik = $item.Keys | Select-Object -First 1
                                if (-not [string]::IsNullOrWhiteSpace([string]$ik)) {
                                    $scenarioKey = [string]$ik
                                    $entities += [ordered]@{ Key = $scenarioKey; Runner = 'scenario'; Provenance = "scenario:$scenarioToUse"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }
                                    $stepEntry = $item[$ik]
                                    $tasks = $null
                                    if ($stepEntry -is [string]) {
                                        $tasks = @($stepEntry)
                                    } elseif ($stepEntry -is [System.Collections.IDictionary]) {
                                        if ($stepEntry.Contains('tasks')) { $tasks = $stepEntry['tasks'] }
                                        elseif ($stepEntry.Contains('task')) { $tasks = $stepEntry['task'] }
                                    }
                                    if ($tasks -is [string]) {
                                        $tasks = @($tasks)
                                    }
                                    if ($tasks -is [System.Collections.IEnumerable] -and $tasks -isnot [string]) {
                                        foreach ($taskName in @($tasks)) {
                                            if (-not [string]::IsNullOrWhiteSpace([string]$taskName)) {
                                                $entities += [ordered]@{ Key = [string]$taskName; Runner = 'psake'; Provenance = "scenario:${scenarioToUse}:${scenarioKey}"; SourcePath = $flowConfig.ConfigPath; Aliases = @() }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        $keys = @()
        foreach ($e in $entities) {
            if ($null -eq $e) { continue }
            $key = Get-JaxRunEntityKey -Entity $e
            if ([string]::IsNullOrWhiteSpace($key)) { continue }
            $runner = if ($e.Contains('Runner')) { [string]$e['Runner'] } else { '' }
            $src = if ($e.Contains('SourcePath')) { [string]$e['SourcePath'] } else { '' }
            $prov = if ($e.Contains('Provenance')) { [string]$e['Provenance'] } else { '' }
            $tooltip = if ([string]::IsNullOrWhiteSpace($src)) { $runner } else { "$runner ($prov) → $src" }
            $keys += [pscustomobject]@{ Name = $key; DisplayText = $key; ToolTip = $tooltip }

            # Avoid relying on core/private functions (autocomplete should work with public core only).
            if ($e -is [System.Collections.IDictionary] -and $e.Contains('Aliases') -and $null -ne $e['Aliases']) {
                foreach ($alias in @($e['Aliases'])) {
                    if ([string]::IsNullOrWhiteSpace([string]$alias)) { continue }
                    $aliasTip = if ([string]::IsNullOrWhiteSpace($src)) { "$alias (alias → $key)" } else { "$alias (alias → $key) → $src" }
                    $keys += [pscustomobject]@{ Name = [string]$alias; DisplayText = "$alias  (alias)"; ToolTip = $aliasTip }
                }
            }
        }

        return @($keys | Sort-Object -Property Name -Unique)
    } catch {
        return @()
    }
}

$script:JaxSequenceKeyIndexCache = @{}

function Get-JaxCompletionSequenceKeys {
    [CmdletBinding()]
    param (
        [string] $EnvName,
        [string] $ScenarioName
    )
    try {
        $repoRoot = Get-JaxRepoRoot
        $config = Get-JaxConfig -RepoRoot $repoRoot
        $cacheKey = "$EnvName|$ScenarioName"
        if ($script:JaxSequenceKeyIndexCache.ContainsKey($cacheKey)) {
            $cached = $script:JaxSequenceKeyIndexCache[$cacheKey]
            if ($cached -is [object[]]) { return $cached }
        }

        $candidates = Get-JaxSequenceKeyCandidates -RepoRoot $repoRoot -Config $config -EnvWithOptionalFlow $EnvName -Scenario $ScenarioName
        $results = @()
        foreach ($c in @($candidates)) {
            if ($null -eq $c) { continue }
            $results += [pscustomobject]@{
                Name        = [string]$c.Name
                DisplayText = [string]$c.Name
                ToolTip     = [string]$c.ToolTip
            }
        }
        $results = @($results | Sort-Object -Property Name -Unique)
        $script:JaxSequenceKeyIndexCache[$cacheKey] = $results
        return $results
    } catch {
        return @()
    }
}

$commandNames = @('jax', 'jx', 'jxs', 'jax.ps1', 'jxs.ps1', './jax/jax.ps1', './jax/jxs.ps1', 'jax/jax.ps1', 'jax/jxs.ps1', '.\\jax\\jax.ps1', '.\\jax\\jxs.ps1')
try {
    $jaxPs1Path = (Resolve-Path (Join-Path $PSScriptRoot 'jax.ps1') -ErrorAction SilentlyContinue).Path
    if (-not [string]::IsNullOrWhiteSpace($jaxPs1Path)) {
        $commandNames += $jaxPs1Path
    }
    $jxsPs1Path = (Resolve-Path (Join-Path $PSScriptRoot 'jxs.ps1') -ErrorAction SilentlyContinue).Path
    if (-not [string]::IsNullOrWhiteSpace($jxsPs1Path)) {
        $commandNames += $jxsPs1Path
    }
    $aliasCandidates = @()
    $aliasCandidates += $jaxPs1Path
    $aliasCandidates += $jxsPs1Path
    $aliasCandidates += 'jax'
    $aliasCandidates += 'jx'
    $aliasCandidates += 'jxs'
    foreach ($alias in @(Get-Alias -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($alias.Definition)) { continue }
        if ($aliasCandidates -contains $alias.Definition -or
            $alias.Definition -like '*jax.ps1' -or
            $alias.Definition -like '*jxs.ps1') {
            $commandNames += $alias.Name
        }
    }
} catch {
}

$jaxCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $tokens = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
        if ($tokens.Count -eq 0) {
            return
        }
        # jxs [script] <...>  ==  jx -sc <...>  (jax/jxs.ps1)
        $first = [string]$tokens[0]
        $isJxsCommand = ($first -eq 'jxs') -or
            ($first -ieq 'jxs.ps1') -or
            ($first -like '*\jxs.ps1') -or
            ($first -like '*/jxs.ps1')
        if ($isJxsCommand) {
            $rest = @()
            if ($tokens.Count -ge 2) {
                $rest = @($tokens[1..($tokens.Count - 1)])
            }
            $tokens = @('jx', '-sc') + $rest
        }

        # IMPORTANT: do NOT override native parameter-name completion.
        # This allows DynamicParam task/script parameters to appear after -only/-from/-to.
        if ($wordToComplete -like '-*') {
            return
        }

        # jx -sc <TAB> (only jx and -sc so far): must offer shortcut names, not run/plan/help/…
        # (Otherwise tokens.Count is 2, $completingCommand stays true, and the handler below lists jax subcommands.)
        $head = [string]$tokens[0]
        $isJaxEntry = ($head -in @('jax', 'jx', 'jxs')) -or
            $head -like '*\jax.ps1' -or $head -like '*/jax.ps1' -or
            $head -ieq 'jax.ps1' -or
            $head -like '*\jxs.ps1' -or $head -like '*/jxs.ps1' -or
            $head -ieq 'jxs.ps1'
        if ($isJaxEntry -and $tokens.Count -eq 2 -and ($tokens[1] -in @('-sc', '-Shortcut'))) {
            foreach ($entry in Get-JaxCompletionShortcutItems) {
                if ($entry.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $entry.Name -Display $entry.Name -ToolTip $entry.ToolTip
                }
            }
            return
        }

        $completingCommand = $true
        if ($tokens.Count -eq 2) {
            # If tokens[1] matches a full command and we are attempting to complete arguments (wordToComplete is empty or not matching start of command arg?)
            # Actually, if wordToComplete is empty, we are definitively past the command.
            # If wordToComplete is NOT empty, we might be completing the command OR start of an arg.
            # If wordToComplete matches the start of a command, we usually prefer command completion.
            # BUT if tokens[1] is EXACTLY 'run', and wordToComplete is empty, we are past it.
            if ([string]::IsNullOrWhiteSpace($wordToComplete) -and (Get-JaxCompletionCommands) -contains $tokens[1]) {
                $completingCommand = $false
            }
        }

        if ($tokens.Count -lt 2) {
            # jax <TAB>
            $completingCommand = $true
        }
        $subCmd = Get-JaxSubcommandFromTokens $tokens

        # Positional env shorthand: `jx <env-path> [task]` — first positional token contains '/'.
        # Treat as `run` and remember the env so task/scenario completion can use it.
        $positionalEnv = $null
        if ($subCmd -and $subCmd.Contains('/')) {
            $positionalEnv = $subCmd
            $subCmd = 'run'
        }

        if (-not [string]::IsNullOrWhiteSpace($subCmd)) {
            # Don't flip past command position when the user is still typing the second token
            # (so partial input like `jx op<TAB>` keeps offering commands + env choices).
            $stillTypingFirstToken = ($tokens.Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($wordToComplete) -and ([string]$tokens[1] -eq $wordToComplete))
            if (-not $stillTypingFirstToken) {
                $completingCommand = $false
            }
        }
        # If no explicit subcommand but run-like params are present, we're past command position
        if ($completingCommand -and -not $subCmd -and $tokens.Count -gt 2) {
            $hasRunLikeFlags = $false
            foreach ($tk in $tokens) {
                if ($tk -match '^-(?:e|env|o|only|f|from|t|to|s|scenario)$') {
                    $hasRunLikeFlags = $true
                    break
                }
            }
            if ($hasRunLikeFlags) {
                $completingCommand = $false
            }
        }

        if ($completingCommand) {
            foreach ($cmd in Get-JaxCompletionCommands) {
                if ($cmd -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $cmd -Display $cmd -ToolTip $cmd
                }
            }
            # Also offer env names so the positional shorthand `jx <env>` tab-completes.
            foreach ($choice in Get-JaxCompletionEnvChoices -StartsWith $wordToComplete) {
                New-JaxCompletionResult -Value $choice.Name -Display $choice.DisplayText -ToolTip $choice.ToolTip
            }
            if ($tokens.Count -le 2 -and $completingCommand) {
                return
            }
        }

        $prevToken = $null
        if ($tokens.Count -ge 2) {
            $lastToken = $tokens[-1]
            if ($lastToken -eq $wordToComplete -and $tokens.Count -ge 3) {
                $prevToken = $tokens[-2]
            } else {
                $prevToken = $lastToken
            }
        }

        $paramToken = $prevToken
        if ($paramToken -and $paramToken.StartsWith('-') -and $paramToken.Contains('=')) {
            $parts = $paramToken.TrimStart('-').Split('=', 2)
            $paramToken = "-$($parts[0])"
        }

        $paramName = $null
        if ($paramToken -and $paramToken.StartsWith('-')) {
            $paramName = $paramToken.TrimStart('-').ToLowerInvariant()
        }

        if ($paramName -in @('env', 'e')) {
            foreach ($choice in Get-JaxCompletionEnvChoices -StartsWith $wordToComplete) {
                New-JaxCompletionResult -Value $choice.Name -Display $choice.DisplayText -ToolTip $choice.ToolTip
            }
            return
        }

        if ($paramName -in @('shortcut', 'sc')) {
            foreach ($entry in Get-JaxCompletionShortcutItems) {
                if ($entry.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $entry.Name -Display $entry.Name -ToolTip $entry.ToolTip
                }
            }
            return
        }

        if ($paramName -eq 'client') {
            foreach ($client in Get-JaxCompletionClients) {
                if ($client -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $client -Display $client -ToolTip $client
                }
            }
            return
        }

        if ($paramName -in @('scenario', 's')) {
            $envName = $fakeBoundParameters['env']
            if (-not $envName) {
                $envName = $fakeBoundParameters['e']
            }
            if (-not $envName) {
                $envName = $positionalEnv
            }
            foreach ($scenario in Get-JaxCompletionScenarioNames -EnvName $envName) {
                if ($scenario -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $scenario -Display $scenario -ToolTip $scenario
                }
            }
            return
        }

        if ($paramName -in @('from', 'to', 'only', 'f', 't', 'o')) {
            $envName = $fakeBoundParameters['env']
            if (-not $envName) {
                $envName = $fakeBoundParameters['e']
            }
            # Token-based fallback: the global completer often has empty fakeBoundParameters.
            if (-not $envName) {
                for ($i = 1; $i -lt $tokens.Count - 1; $i++) {
                    if ($tokens[$i] -in @('-e', '-env') -and $tokens[$i + 1] -notlike '-*') {
                        $envName = $tokens[$i + 1]
                        break
                    }
                }
            }
            if (-not $envName) {
                $envName = $positionalEnv
            }
            $envFromState = $false
            if (-not $envName) {
                $envName = Get-JaxCompletionLastEnv
                $envFromState = $true
            }
            $scenarioName = $fakeBoundParameters['scenario']
            if (-not $scenarioName) {
                $scenarioName = $fakeBoundParameters['s']
            }
            if (-not $scenarioName) {
                for ($i = 1; $i -lt $tokens.Count - 1; $i++) {
                    if ($tokens[$i] -in @('-s', '-scenario') -and $tokens[$i + 1] -notlike '-*') {
                        $scenarioName = $tokens[$i + 1]
                        break
                    }
                }
            }
            $envTag = if ($envName) {
                if ($envFromState) { "[env: $envName (from state)] " } else { "[env: $envName] " }
            } else { '' }
            # For [string[]] -only, collect already-bound values so we can filter them out.
            # PowerShell speculatively binds the in-progress word as a value too — drop it from
            # the set so we keep prefix filtering on $wordToComplete and don't hide a task whose
            # full name the user is currently typing.
            $alreadyOnlyBound = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            if ($paramName -in @('only', 'o')) {
                $bv = $fakeBoundParameters['only']
                if ($bv -is [string]) { $alreadyOnlyBound.Add($bv) | Out-Null }
                elseif ($null -ne $bv -and $bv -is [System.Collections.IEnumerable]) {
                    foreach ($v in @($bv)) { if ($v) { $alreadyOnlyBound.Add([string]$v) | Out-Null } }
                }
            }
            if (-not [string]::IsNullOrEmpty($wordToComplete)) {
                $alreadyOnlyBound.Remove($wordToComplete) | Out-Null
            }
            foreach ($key in Get-JaxCompletionTaskKeys -EnvName $envName -ScenarioName $scenarioName) {
                if ($alreadyOnlyBound.Contains($key.Name)) { continue }
                if ($key.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $key.Name -Display $key.DisplayText -ToolTip "$envTag$($key.ToolTip)"
                }
            }
            return
        }

        # Implicit run task completion
        # If the subcommand is 'run'/'r'/'invoke' (or implied by presence of run params like -e),
        # and we are not completing a flag value (checked above),
        # then we suggest tasks (implicit -only).
        $isImplicitRun = $false
        if (-not $subCmd) {
            # No explicit subcommand — check if run-like params are present.
            # Check fakeBoundParameters first; fall back to token scan because
            # the global (no-ParameterName) completer often receives empty fakeBoundParameters,
            # especially for subsequent values of a [string[]] parameter like -only.
            $hasRunParams = $fakeBoundParameters.ContainsKey('env') -or
                $fakeBoundParameters.ContainsKey('e') -or
                $fakeBoundParameters.ContainsKey('only') -or
                $fakeBoundParameters.ContainsKey('o') -or
                $fakeBoundParameters.ContainsKey('from') -or
                $fakeBoundParameters.ContainsKey('f') -or
                $fakeBoundParameters.ContainsKey('to') -or
                $fakeBoundParameters.ContainsKey('t') -or
                $fakeBoundParameters.ContainsKey('scenario') -or
                $fakeBoundParameters.ContainsKey('s')
            if (-not $hasRunParams) {
                foreach ($tk in $tokens) {
                    if ($tk -match '^-(?:e|env|o|only|f|from|t|to|s|scenario)$') {
                        $hasRunParams = $true
                        break
                    }
                }
            }
            if ($hasRunParams) {
                $isImplicitRun = $true
            }
        }
        if ($subCmd -in @('run', 'r', 'invoke') -or $isImplicitRun) {
            # Only complete tasks if word doesn't look like a flag start
            if (-not ($wordToComplete -like '-*')) {
                $envName = $fakeBoundParameters['env']
                if (-not $envName) { $envName = $fakeBoundParameters['e'] }
                # Token-based env fallback: fakeBoundParameters is often empty in the global completer.
                if (-not $envName) {
                    for ($i = 1; $i -lt $tokens.Count - 1; $i++) {
                        if ($tokens[$i] -in @('-e', '-env') -and $tokens[$i + 1] -notlike '-*') {
                            $envName = $tokens[$i + 1]
                            break
                        }
                    }
                }
                if (-not $envName) { $envName = $positionalEnv }
                $envFromState = $false
                # Final fallback to persisted state
                if (-not $envName) {
                    $envName = Get-JaxCompletionLastEnv
                    $envFromState = $true
                }

                $scenarioName = $fakeBoundParameters['scenario']
                if (-not $scenarioName) { $scenarioName = $fakeBoundParameters['s'] }
                if (-not $scenarioName) {
                    for ($i = 1; $i -lt $tokens.Count - 1; $i++) {
                        if ($tokens[$i] -in @('-s', '-scenario') -and $tokens[$i + 1] -notlike '-*') {
                            $scenarioName = $tokens[$i + 1]
                            break
                        }
                    }
                }

                $envTag = if ($envName) {
                    if ($envFromState) { "[env: $envName (from state)] " } else { "[env: $envName] " }
                } else { '' }
                foreach ($key in Get-JaxCompletionTaskKeys -EnvName $envName -ScenarioName $scenarioName) {
                    if ($key.Name -like "$wordToComplete*") {
                        New-JaxCompletionResult -Value $key.Name -Display $key.DisplayText -ToolTip "$envTag$($key.ToolTip)"
                    }
                }
            }
        }

        if ($subCmd -eq 'vault') {
            $matches = @()
            foreach ($cmd in Get-JaxCompletionVaultCommands) {
                if ($cmd -like "$wordToComplete*") {
                    $matches += $cmd
                }
            }
            if ($matches.Count -eq 0 -and $prevToken -eq 'vault') {
                $matches = Get-JaxCompletionVaultCommands
            }
            foreach ($cmd in $matches) {
                New-JaxCompletionResult -Value $cmd -Display $cmd -ToolTip "vault $cmd"
            }
            return
        }
    } catch {
        return
    }
}

# Important: Jax CLI flags like -env/-to are NOT real PowerShell parameters on jax.ps1; they live inside CommandArgs.
# When a user types `./jax/jax.ps1 run -<TAB>`, PowerShell thinks it's completing *parameter names* and would never call
# a completer that is attached only to CommandArgs. Register for the whole command (all params) so we can intercept both:
# - flag completion (`run -<TAB>`)
# - value completion (`-env <TAB>`, `-to <TAB>`, etc.)
Register-ArgumentCompleter -CommandName $commandNames -ScriptBlock $jaxCompleter
Register-ArgumentCompleter -CommandName $commandNames -ParameterName 'CommandArgs' -ScriptBlock $jaxCompleter

# Also register explicit completers for DynamicParam run parameters on jax.ps1.
foreach ($cmd in @($commandNames | Sort-Object -Unique)) {
    foreach ($paramName in @('env', 'e')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            foreach ($choice in Get-JaxCompletionEnvChoices -StartsWith $wordToComplete) {
                New-JaxCompletionResult -Value $choice.Name -Display $choice.DisplayText -ToolTip $choice.ToolTip
            }
        }
    }

    foreach ($paramName in @('scenario', 's')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $envName = $null
            if ($fakeBoundParameters.ContainsKey('env')) { $envName = $fakeBoundParameters['env'] }
            foreach ($scenario in Get-JaxCompletionScenarioNames -EnvName $envName) {
                if ($scenario -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $scenario -Display $scenario -ToolTip $scenario
                }
            }
        }
    }

    foreach ($paramName in @('from', 'f', 'to', 't')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $envName = $null
            if ($fakeBoundParameters.ContainsKey('env')) { $envName = $fakeBoundParameters['env'] }
            if (-not $envName) { $envName = Get-JaxCompletionLastEnv }

            $scenarioName = $null
            if ($fakeBoundParameters.ContainsKey('scenario')) { $scenarioName = $fakeBoundParameters['scenario'] }
            foreach ($key in Get-JaxCompletionSequenceKeys -EnvName $envName -ScenarioName $scenarioName) {
                if ($key.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $key.Name -Display $key.DisplayText -ToolTip $key.ToolTip
                }
            }
        }
    }

    # -only: show everything (sequence keys + individual tasks/scripts)
    # For [string[]] $only, multiple -o values are allowed. The completer may be called with
    # $wordToComplete set to a previously-selected value (PowerShell quirk with [string[]] params).
    # We detect this, reset to '', and filter already-selected tasks from the results.
    foreach ($paramName in @('only', 'o')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $envName = $null
            if ($fakeBoundParameters.ContainsKey('env')) { $envName = $fakeBoundParameters['env'] }
            # Token-based fallback for env: fakeBoundParameters may be missing it for
            # subsequent values of a [string[]] parameter.
            if (-not $envName -and $commandAst) {
                $astTokens = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
                for ($i = 1; $i -lt $astTokens.Count - 1; $i++) {
                    if ($astTokens[$i] -in @('-e', '-env') -and $astTokens[$i + 1] -notlike '-*') {
                        $envName = $astTokens[$i + 1]
                        break
                    }
                }
            }
            if (-not $envName) { $envName = Get-JaxCompletionLastEnv }

            $scenarioName = $null
            if ($fakeBoundParameters.ContainsKey('scenario')) { $scenarioName = $fakeBoundParameters['scenario'] }
            if (-not $scenarioName -and $commandAst) {
                $astTokens = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
                for ($i = 1; $i -lt $astTokens.Count - 1; $i++) {
                    if ($astTokens[$i] -in @('-s', '-scenario') -and $astTokens[$i + 1] -notlike '-*') {
                        $scenarioName = $astTokens[$i + 1]
                        break
                    }
                }
            }

            $alreadyBound = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            if ($fakeBoundParameters.ContainsKey('only')) {
                $bv = $fakeBoundParameters['only']
                if ($bv -is [string]) { $alreadyBound.Add($bv) | Out-Null }
                elseif ($null -ne $bv -and $bv -is [System.Collections.IEnumerable]) {
                    foreach ($v in @($bv)) { if ($v) { $alreadyBound.Add([string]$v) | Out-Null } }
                }
            }
            # PowerShell speculatively binds the in-progress word — drop it so prefix
            # filtering on $wordToComplete still works for the first/typing value.
            if (-not [string]::IsNullOrEmpty($wordToComplete)) {
                $alreadyBound.Remove($wordToComplete) | Out-Null
            }
            foreach ($key in Get-JaxCompletionTaskKeys -EnvName $envName -ScenarioName $scenarioName) {
                if ($alreadyBound.Contains($key.Name)) { continue }
                if ($key.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $key.Name -Display $key.DisplayText -ToolTip $key.ToolTip
                }
            }
        }
    }

    # -sc/-shortcut: complete saved shortcut names (list = name; tooltip = expansion)
    foreach ($paramName in @('Shortcut', 'sc')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            foreach ($entry in Get-JaxCompletionShortcutItems) {
                if ($entry.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $entry.Name -Display $entry.Name -ToolTip $entry.ToolTip
                }
            }
        }
    }

    # -rsc: same name list as -sc (remove saved shortcut)
    foreach ($paramName in @('RemoveShortcut', 'rsc')) {
        Register-ArgumentCompleter -CommandName $cmd -ParameterName $paramName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            foreach ($entry in Get-JaxCompletionShortcutItems) {
                if ($entry.Name -like "$wordToComplete*") {
                    New-JaxCompletionResult -Value $entry.Name -Display $entry.Name -ToolTip $entry.ToolTip
                }
            }
        }
    }
}

# Native-style completer: this is the only reliable way to complete *non-parameter* flags like -env/-to for a script-based CLI.
# It works for aliases (e.g. `jax`) and for invoking the script path directly.
function ConvertTo-JaxCompletionResults {
    param(
        [object[]] $items
    )
    foreach ($i in @($items)) {
        if ($null -eq $i) { continue }
        if ($i -is [System.Management.Automation.CompletionResult]) {
            $i
            continue
        }
        if ($i -is [string]) {
            New-JaxCompletionResult -Value $i -Display $i -ToolTip $i
            continue
        }
        if ($i.PSObject.Properties.Name -contains 'Name') {
            $name = [string]$i.Name
            $display = if ($i.PSObject.Properties.Name -contains 'DisplayText') { [string]$i.DisplayText } else { $name }
            $tip = if ($i.PSObject.Properties.Name -contains 'ToolTip') { [string]$i.ToolTip } else { $display }
            New-JaxCompletionResult -Value $name -Display $display -ToolTip $tip
        }
    }
}

function Get-JaxBoundArgsFromTokens {
    param([string[]] $tokens)

    $ht = @{}
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]
        if (-not $t) { continue }
        if ($t -notlike '-*') { continue }

        $namePart = $t
        $valuePart = $null
        if ($t.Contains('=')) {
            $parts = $t.TrimStart('-').Split('=', 2)
            $namePart = $parts[0]
            $valuePart = $parts[1]
        } else {
            $namePart = $t.TrimStart('-')
            if (($i + 1) -lt $tokens.Count) {
                $next = $tokens[$i + 1]
                if ($next -and $next -notlike '-*') {
                    $valuePart = $next
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($namePart)) { continue }
        $key = $namePart.ToLowerInvariant()
        if ($null -ne $valuePart) {
            $ht[$key] = $valuePart
        } else {
            $ht[$key] = $true
        }
    }
    return $ht
}

function Get-JaxSubcommandFromTokens {
    param([string[]] $tokens)
    # tokens[0] is the command itself; scan for the first non-flag token
    # that is not a flag value (e.g. "jax -e env run" -> run).
    if ($tokens.Count -lt 2) {
        return $null
    }
    for ($i = 1; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        if ($t -like '-*') {
            # Skip flag + optional value.
            if (($i + 1) -lt $tokens.Count) {
                $next = $tokens[$i + 1]
                if ($next -and $next -notlike '-*') {
                    $i++
                }
            }
            continue
        }
        return $t
    }
    return $null
}

# Note: native completers are for external programs; jax is a PowerShell script.
# Compatibility flags are real parameters on `jax.ps1`, so standard parameter completion works.
