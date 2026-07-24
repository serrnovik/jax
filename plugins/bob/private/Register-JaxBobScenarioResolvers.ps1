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

        $jaxConfig = Get-JaxConfig -RepoRoot $repoRoot
        $moduleRootDirName = 'code'
        if ($jaxConfig -and $jaxConfig.ContainsKey('modulePathInGit') -and $jaxConfig['modulePathInGit'] -is [System.Collections.IDictionary]) {
            $modulePathInGit = $jaxConfig['modulePathInGit']
            if ($modulePathInGit.ContainsKey('default') -and -not [string]::IsNullOrWhiteSpace($modulePathInGit['default'])) {
                $moduleRootDirName = [string]$modulePathInGit['default']
            }
        }

        $moduleDir = Join-Path $repoRoot (Join-Path $moduleRootDirName $Key)
        if (-not (Test-Path -Path $moduleDir -PathType Container)) {
            # Not a module path; let other resolvers handle it.
            return $null
        }

        # Find module bobfile/jaxfile
        $pluginDefaults = Get-JaxBobPluginDefaults
        $fileBaseNames = @($pluginDefaults.fileBaseNames)
        $fileExtensions = @($pluginDefaults.fileExtensions)
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
            throw "Library item '$Key' not found in scenarios-lib or suite.library."
        }

        $item = $library[$Key]
        if ($null -eq $item) {
            throw "Library item '$Key' is empty."
        }

        return Resolve-JaxBobScenarioItemRecursive -Key $Key -Value $item -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -IsLibraryItem
    }
}
