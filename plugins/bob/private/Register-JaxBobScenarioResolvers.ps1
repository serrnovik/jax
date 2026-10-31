function Resolve-JaxBobModuleDirectory {
    param (
        [string] $RepoRoot,
        [string] $Key,
        [System.Collections.IDictionary] $Config
    )

    # modulePathInGit maps a module key (docker, helm) onto a root other than `default`.
    # A mapped root that does not exist falls through to default, then `code`, so a stale
    # map entry cannot hide the module that actually lives under the default root.
    $rootNames = New-Object 'System.Collections.Generic.List[string]'
    $seenRoots = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Add-JaxBobModuleRoot {
        param([string] $Name)
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return
        }
        $trimmed = $Name.Trim().Trim('/', '\')
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            return
        }
        if ($seenRoots.Add($trimmed)) {
            $rootNames.Add($trimmed) | Out-Null
        }
    }

    $modulePathInGit = $null
    if ($null -ne $Config -and $Config.ContainsKey('modulePathInGit') -and $Config['modulePathInGit'] -is [System.Collections.IDictionary]) {
        $modulePathInGit = $Config['modulePathInGit']
    }
    if ($null -ne $modulePathInGit) {
        if ($modulePathInGit.ContainsKey($Key)) {
            Add-JaxBobModuleRoot -Name ([string]$modulePathInGit[$Key])
        }
        if ($modulePathInGit.ContainsKey('default')) {
            Add-JaxBobModuleRoot -Name ([string]$modulePathInGit['default'])
        }
    }
    Add-JaxBobModuleRoot -Name 'code'

    foreach ($rootName in $rootNames) {
        $candidate = Join-Path $RepoRoot (Join-Path $rootName $Key)
        if (Test-Path -Path $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Register-JaxBobScenarioResolvers {
    Register-JaxScenarioResolver -Name 'bob-build-module' -Order -20 -Handler {
        param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

        # In boss/build.yml, suite.modules entries may be empty (null) which means "run module default task".
        # This must NOT be treated as a library reference. Library references are for sceny steps, not build modules.
        if ($ScenarioName -ne 'build') {
            return $null
        }

        $repoRoot = $null
        if ($Context -and $Context.ContainsKey('RepoRoot')) {
            $repoRoot = $Context['RepoRoot']
        }
        if ([string]::IsNullOrWhiteSpace($repoRoot)) {
            $repoRoot = Get-JaxRepoRoot
        }

        $jaxConfig = $null
        if ($Context -and $Context.ContainsKey('Config') -and $Context['Config'] -is [System.Collections.IDictionary]) {
            $jaxConfig = $Context['Config']
        }
        if ($null -eq $jaxConfig) {
            $jaxConfig = Get-JaxConfig -RepoRoot $repoRoot
        }

        $moduleDir = Resolve-JaxBobModuleDirectory -RepoRoot $repoRoot -Key $Key -Config $jaxConfig
        if ([string]::IsNullOrWhiteSpace($moduleDir)) {
            # Not a module path; let other resolvers handle it.
            return $null
        }

        # Find module bobfile/jaxfile. Repo config can opt into bobfile; the default stays jaxfile.
        $bobPluginConfig = $null
        if ($jaxConfig.ContainsKey('plugins') -and $jaxConfig['plugins'] -is [System.Collections.IDictionary]) {
            $plugins = $jaxConfig['plugins']
            if ($plugins.ContainsKey('config') -and $plugins['config'] -is [System.Collections.IDictionary]) {
                $pluginConfigs = $plugins['config']
                if ($pluginConfigs.ContainsKey('bob') -and $pluginConfigs['bob'] -is [System.Collections.IDictionary]) {
                    $bobPluginConfig = $pluginConfigs['bob']
                }
            }
        }
        $resolvedBobConfig = Get-JaxBobPluginConfig -PluginConfig $bobPluginConfig
        $fileBaseNames = @($resolvedBobConfig['fileBaseNames'])
        $fileExtensions = @($resolvedBobConfig['fileExtensions'])
        $candidateBobFile = $null
        foreach ($baseName in $fileBaseNames) {
            foreach ($ext in $fileExtensions) {
                $trimmedExt = [string]$ext
                if ($trimmedExt.StartsWith('.')) {
                    $trimmedExt = $trimmedExt.TrimStart('.')
                }
                $candidate = Join-Path $moduleDir ("{0}.{1}" -f $baseName, $trimmedExt)
                if (Test-Path -Path $candidate -PathType Leaf) {
                    $candidateBobFile = (Resolve-Path $candidate).Path
                    break
                }
            }
            if ($candidateBobFile) { break }
        }

        $moduleConfig = @{}
        if ($candidateBobFile) {
            $moduleConfig = Read-JaxRunConfigFile -Path $candidateBobFile -RepoRoot $repoRoot

            # Opt-in: local/CI/named override layers win over the module file, the way
            # machine overrides are applied on top of each module in older layouts.
            if ($resolvedBobConfig.Contains('applyLayersToModules') -and [bool]$resolvedBobConfig['applyLayersToModules'] -and
                $Context -and $Context.ContainsKey('RunConfigLayerConfig') -and $Context['RunConfigLayerConfig'] -is [System.Collections.IDictionary]) {
                $moduleConfig = Merge-JaxHashtable -Base $moduleConfig -Overlay $Context['RunConfigLayerConfig']
            }

            $varsOverride = $null
            if ($Context -and $Context.ContainsKey('VariablesOverride')) {
                $varsOverride = $Context['VariablesOverride']
            }
            $moduleConfig = Expand-JaxPlaceholders -Config $moduleConfig -Override $varsOverride -SourcePaths @($candidateBobFile)
        }

        # Find module psakefile (prefer psakefile.ps1, else first matching psakefile*.ps1)
        $psakeFile = $null
        $preferred = Join-Path $moduleDir 'psakefile.ps1'
        if (Test-Path -Path $preferred -PathType Leaf) {
            $psakeFile = (Resolve-Path $preferred).Path
        } else {
            $candidates = @(Get-ChildItem -Path $moduleDir -File -Filter 'psakefile*.ps1' -ErrorAction SilentlyContinue)
            if ($candidates.Count -gt 0) {
                $psakeFile = $candidates[0].FullName
            }
        }
        if ([string]::IsNullOrWhiteSpace($psakeFile)) {
            throw "Module '$Key' was found at '$moduleDir' but no psakefile*.ps1 was found."
        }

        $entity = [ordered]@{
            Key        = $Key
            Runner     = 'psake'
            Tasks      = @()
            Script     = $null
            Args       = $null
            PsakeFile  = $psakeFile
            Container  = $null
            Scenario   = $ScenarioName
            Provenance = 'psake -> module'
            SourcePath = $ProvenancePath
        }

        # If tasks are specified under suite.modules.<name>.tasks use them; otherwise leave empty so psake runs default task.
        if ($Value -is [System.Collections.IDictionary] -and $Value.Contains('tasks') -and $null -ne $Value['tasks']) {
            if ($Value['tasks'] -is [string]) {
                $entity.Tasks = @($Value['tasks'])
            } else {
                $entity['Tasks'] = @($Value['tasks'])
            }
        }

        if ($moduleConfig -is [System.Collections.IDictionary] -and $moduleConfig.Count -gt 0) {
            $entity['Args'] = $moduleConfig
        }

        return $entity
    }

    Register-JaxScenarioResolver -Name 'bob-prototype' -Order -5 -Handler {
        param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

        if ($Value -is [System.Collections.IDictionary] -and ($Value.Keys -contains 'steps')) {
            $resolved = Resolve-JaxBobScenarioItemRecursive -Key $Key -Value $Value -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context
            $resolvedEntities = @()
            if ($resolved -is [System.Collections.IEnumerable] -and $resolved -isnot [string]) {
                $resolvedEntities = @($resolved)
            }
            $args = $null
            if ($Value.Keys -contains 'args') {
                $args = $Value['args']
            }
            return [ordered]@{
                Key        = $Key
                Runner     = 'scenario'
                Entities   = $resolvedEntities
                Tasks      = @()
                Script     = $null
                Args       = $args
                PsakeFile  = $null
                Container  = $null
                Scenario   = $ScenarioName
                Provenance = 'scenario -> bob-prototype'
                SourcePath = $ProvenancePath
            }
        }

        return $null
    }

    Register-JaxScenarioResolver -Name 'bob-library' -Order -10 -Handler {
        param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

        if ($null -ne $Value) {
            return $null
        }
        if ($null -eq $Context -or -not $Context.ContainsKey('ScenarioLibrary')) {
            return $null
        }

        $library = $Context['ScenarioLibrary']
        if ($null -eq $library -or $library -isnot [System.Collections.IDictionary]) {
            return $null
        }

        if (-not $library.Contains($Key)) {
            # Legacy-format scenarios use a null step for a task name that is not in
            # scenarios-lib. Default stays throw so a typo'd library reference still fails.
            $missingLibraryItem = 'throw'
            if ($Context.ContainsKey('Config') -and $Context['Config'] -is [System.Collections.IDictionary]) {
                $cfg = $Context['Config']
                if ($cfg.ContainsKey('plugins') -and $cfg['plugins'] -is [System.Collections.IDictionary]) {
                    $plugins = $cfg['plugins']
                    if ($plugins.ContainsKey('config') -and $plugins['config'] -is [System.Collections.IDictionary]) {
                        $pluginConfigs = $plugins['config']
                        if ($pluginConfigs.ContainsKey('bob') -and $pluginConfigs['bob'] -is [System.Collections.IDictionary]) {
                            $bobConfig = $pluginConfigs['bob']
                            if ($bobConfig.ContainsKey('missingLibraryItem') -and -not [string]::IsNullOrWhiteSpace([string]$bobConfig['missingLibraryItem'])) {
                                $missingLibraryItem = [string]$bobConfig['missingLibraryItem']
                            }
                        }
                    }
                }
            }
            if ($missingLibraryItem -eq 'skip') {
                return $null
            }
            throw "Library item '$Key' not found in scenarios-lib or suite.library."
        }

        $item = $library[$Key]
        if ($null -eq $item) {
            throw "Library item '$Key' is empty."
        }

        return Resolve-JaxBobScenarioItemRecursive -Key $Key -Value $item -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -IsLibraryItem
    }
}
