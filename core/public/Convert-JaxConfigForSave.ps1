function Convert-JaxConfigForSave {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config
    )

    $copy = Merge-JaxHashtable -Base @{} -Overlay $Config
    $copy = Convert-JaxConfig -Config $copy

    function Get-JaxListValue {
        param (
            [object] $Value
        )

        if ($null -eq $Value) {
            return ,@()
        }
        if ($Value -is [string]) {
            return ,@($Value)
        }
        if ($Value -is [System.Collections.IDictionary]) {
            return ,@()
        }
        return ,@($Value)
    }

    function Convert-JaxOrderedMap {
        param (
            [System.Collections.IDictionary] $Map,
            [string[]] $KeyOrder = @()
        )

        $ordered = [ordered]@{}
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($key in $KeyOrder) {
            if ($Map.Keys -contains $key) {
                $ordered[$key] = $Map[$key]
                $seen.Add($key) | Out-Null
            }
        }

        $extraKeys = @($Map.Keys | Where-Object { -not $seen.Contains($_) } | Sort-Object)
        foreach ($key in $extraKeys) {
            $ordered[$key] = $Map[$key]
        }

        return $ordered
    }

    $ordered = [ordered]@{}
    $ordered['envRoot'] = $copy['envRoot']
    $dummyEnv = @{}
    if ($copy.Keys -contains 'dummyEnv') {
        if ($copy['dummyEnv'] -is [string]) {
            $dummyEnv = @{ name = $copy['dummyEnv'] }
        } elseif ($copy['dummyEnv'] -is [System.Collections.IDictionary]) {
            $dummyEnv = $copy['dummyEnv']
        }
    }
    $ordered['dummyEnv'] = [ordered]@{
        enabled     = $dummyEnv['enabled']
        name        = $dummyEnv['name']
        skipEnvRoot = $dummyEnv['skipEnvRoot']
    }
    $ordered['flowDirNames'] = Get-JaxListValue $copy['flowDirNames']
    $ordered['flowFilePatterns'] = Get-JaxListValue $copy['flowFilePatterns']
    $ordered['buildSectionNames'] = Get-JaxListValue $copy['buildSectionNames']
    $ordered['conventionalEnvRoots'] = Get-JaxListValue $copy['conventionalEnvRoots']
    $ordered['commonDirName'] = $copy['commonDirName']
    $ordered['scenarioLibDirName'] = $copy['scenarioLibDirName']

    $tasks = @{}
    if ($copy.Keys -contains 'tasks' -and $copy['tasks'] -is [System.Collections.IDictionary]) {
        $tasks = $copy['tasks']
    }
    $ordered['tasks'] = [ordered]@{
        psakeFilePattern    = $tasks['psakeFilePattern']
        nonConventionalDirs = Get-JaxListValue $tasks['nonConventionalDirs']
    }

    $scripts = @{}
    if ($copy.Keys -contains 'scripts' -and $copy['scripts'] -is [System.Collections.IDictionary]) {
        $scripts = $copy['scripts']
    }
    $ordered['scripts'] = [ordered]@{
        dirNames            = Get-JaxListValue $scripts['dirNames']
        nonConventionalDirs = Get-JaxListValue $scripts['nonConventionalDirs']
    }

    $modulePathInGit = @{}
    if ($copy.Keys -contains 'modulePathInGit' -and $copy['modulePathInGit'] -is [System.Collections.IDictionary]) {
        $modulePathInGit = $copy['modulePathInGit']
    }
    $ordered['modulePathInGit'] = Convert-JaxOrderedMap -Map $modulePathInGit

    $ordered['taskIgnoreList'] = Get-JaxListValue $copy['taskIgnoreList']

    $aliases = @{}
    if ($copy.Keys -contains 'aliases' -and $copy['aliases'] -is [System.Collections.IDictionary]) {
        $aliases = $copy['aliases']
    }
    $ordered['aliases'] = Convert-JaxOrderedMap -Map $aliases

    # Shortcuts: map of shortcut-name -> array of CLI arg strings
    $shortcuts = @{}
    if ($copy.Keys -contains 'shortcuts' -and $copy['shortcuts'] -is [System.Collections.IDictionary]) {
        $shortcuts = $copy['shortcuts']
    }
    $orderedShortcuts = [ordered]@{}
    foreach ($scKey in ($shortcuts.Keys | Sort-Object)) {
        $scVal = $shortcuts[$scKey]
        if ($scVal -is [System.Collections.IEnumerable] -and $scVal -isnot [string]) {
            $orderedShortcuts[$scKey] = @($scVal)
        } else {
            $orderedShortcuts[$scKey] = $scVal
        }
    }
    $ordered['shortcuts'] = $orderedShortcuts

    $plugins = @{}
    if ($copy.Keys -contains 'plugins' -and $copy['plugins'] -is [System.Collections.IDictionary]) {
        $plugins = $copy['plugins']
    }

    $pluginsConfig = @{}
    if ($plugins.Keys -contains 'config' -and $plugins['config'] -is [System.Collections.IDictionary]) {
        $pluginsConfig = $plugins['config']
    }

    $pluginOrder = @('bob', 'cleaning', 'machine', 'vault', 'dotenv', 'dotnet', 'node', 'docker', 'packaging', 'tests', 'helm', 'publish')

    $orderedPluginConfig = [ordered]@{}
    foreach ($pluginName in $pluginOrder) {
        if (-not ($pluginsConfig.Keys -contains $pluginName)) {
            continue
        }
        $pluginConfig = $pluginsConfig[$pluginName]
        if ($pluginName -eq 'bob' -and $pluginConfig -is [System.Collections.IDictionary]) {
            $git = @{}
            if ($pluginConfig.Keys -contains 'git' -and $pluginConfig['git'] -is [System.Collections.IDictionary]) {
                $git = $pluginConfig['git']
            }
            $layers = @{}
            if ($pluginConfig.Keys -contains 'layers' -and $pluginConfig['layers'] -is [System.Collections.IDictionary]) {
                $layers = $pluginConfig['layers']
            }

            $ignoreMissingPlaceholders = if ($pluginConfig.Keys -contains 'ignoreMissingPlaceholders') {
                $pluginConfig['ignoreMissingPlaceholders']
            } else {
                $pluginConfig['ignoreMissingVariables']
            }

            $orderedBob = [ordered]@{
                fileBaseNames         = Get-JaxListValue $pluginConfig['fileBaseNames']
                fileExtensions        = Get-JaxListValue $pluginConfig['fileExtensions']
                defaults              = if ($pluginConfig['defaults'] -is [System.Collections.IDictionary]) { Convert-JaxOrderedMap -Map $pluginConfig['defaults'] } else { @{} }
                expandVariables       = $pluginConfig['expandVariables']
                ignoreMissingPlaceholders = $ignoreMissingPlaceholders
                git                   = [ordered]@{
                    require  = $git['require']
                    allowInit = $git['allowInit']
                    prompt   = $git['prompt']
                }
                layers                = [ordered]@{
                    repoCommonPatterns    = Get-JaxListValue $layers['repoCommonPatterns']
                    localOverridePatterns = Get-JaxListValue $layers['localOverridePatterns']
                    ciOverridePatterns    = Get-JaxListValue $layers['ciOverridePatterns']
                    flavourDir            = $layers['flavourDir']
                    flavourPatterns       = Get-JaxListValue $layers['flavourPatterns']
                    ciEnvVars             = Get-JaxListValue $layers['ciEnvVars']
                    overrides             = if ($layers['overrides'] -is [System.Collections.IDictionary]) { Convert-JaxOrderedMap -Map $layers['overrides'] } else { @{} }
                }
            }

            $orderedPluginConfig[$pluginName] = $orderedBob
            continue
        }

        if ($pluginConfig -is [System.Collections.IDictionary]) {
            $orderedPluginConfig[$pluginName] = Convert-JaxOrderedMap -Map $pluginConfig
        } else {
            $orderedPluginConfig[$pluginName] = $pluginConfig
        }
    }

    $extraPlugins = @($pluginsConfig.Keys | Where-Object { $pluginOrder -notcontains $_ } | Sort-Object)
    foreach ($pluginName in $extraPlugins) {
        $pluginConfig = $pluginsConfig[$pluginName]
        if ($pluginConfig -is [System.Collections.IDictionary]) {
            $orderedPluginConfig[$pluginName] = Convert-JaxOrderedMap -Map $pluginConfig
        } else {
            $orderedPluginConfig[$pluginName] = $pluginConfig
        }
    }

    $ordered['plugins'] = [ordered]@{
        enabled  = Get-JaxListValue $plugins['enabled']
        disabled = Get-JaxListValue $plugins['disabled']
        paths    = Get-JaxListValue $plugins['paths']
        config   = $orderedPluginConfig
    }

    $cache = @{}
    if ($copy.Keys -contains 'cache' -and $copy['cache'] -is [System.Collections.IDictionary]) {
        $cache = $copy['cache']
    }
    $ordered['cache'] = [ordered]@{
        enabled = $cache['enabled']
        dir     = $cache['dir']
    }

    $knownKeys = @(
        'envRoot',
        'dummyEnv',
        'flowDirNames',
        'flowFilePatterns',
        'buildSectionNames',
        'conventionalEnvRoots',
        'commonDirName',
        'scenarioLibDirName',
        'tasks',
        'scripts',
        'modulePathInGit',
        'taskIgnoreList',
        'aliases',
        'shortcuts',
        'plugins',
        'cache'
    )

    foreach ($key in @($copy.Keys | Where-Object { $knownKeys -notcontains $_ } | Sort-Object)) {
        $ordered[$key] = $copy[$key]
    }

    return $ordered
}
