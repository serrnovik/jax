function Get-JaxEnvironments {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $Config = Convert-JaxConfig -Config $Config
    $commonPSBoundParameters = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $dummyEnvConfig = @{}
    if ($Config.Keys -contains 'dummyEnv') {
        if ($Config['dummyEnv'] -is [string]) {
            $dummyEnvConfig = @{ name = $Config['dummyEnv'] }
        } elseif ($Config['dummyEnv'] -is [System.Collections.IDictionary]) {
            $dummyEnvConfig = $Config['dummyEnv']
        }
    }

    $dummyEnabled = $true
    if ($dummyEnvConfig.Keys -contains 'enabled') {
        $dummyEnabled = [bool]$dummyEnvConfig['enabled']
    }
    $dummyName = 'none'
    if ($dummyEnvConfig.Keys -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$dummyEnvConfig['name'])) {
        $dummyName = [string]$dummyEnvConfig['name']
    }
    $dummySkipEnvRoot = $true
    if ($dummyEnvConfig.Keys -contains 'skipEnvRoot') {
        $dummySkipEnvRoot = [bool]$dummyEnvConfig['skipEnvRoot']
    }

    function New-JaxDummyEnvironment {
        param (
            [string] $Name,
            [bool] $SkipEnvRoot
        )

        return [pscustomobject]@{
            Name             = $Name
            EnvDir           = $null
            FlowDir          = $null
            FlowConfigs      = @()
            HierarchyPaths   = @()
            HierarchyFlowDirs = @()
            IsDummy          = $true
            SkipEnvRoot      = $SkipEnvRoot
        }
    }

    $envs = @()
    $envRootPath = Join-Path $RepoRoot $Config.envRoot
    if (Test-Path -Path $envRootPath -PathType Container) {
        $envRootPath = (Resolve-Path $envRootPath).Path

        $flowDirNames = @($Config.flowDirNames)
        $flowDirs = Find-JaxFlowDirs -EnvRootPath $envRootPath -FlowDirNames $flowDirNames -CommonParameters $commonPSBoundParameters

        foreach ($flowDir in $flowDirs) {
            $envDir = Split-Path -Path $flowDir.FullName -Parent
            $envRelative = $envDir.Substring($envRootPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $envName = $envRelative -replace '\\', '/'
            $envNameParts = @($envName -split '/' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($envNameParts.Count -gt 0 -and
                [string]::Equals($envNameParts[-1], [string]$Config.commonDirName, [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $hierarchyPaths = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $envDir
            $hierarchyFlowDirs = New-Object 'System.Collections.Generic.List[string]'
            $flowDirSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($path in $hierarchyPaths) {
                foreach ($flowDirName in $flowDirNames) {
                    $candidate = Join-Path $path $flowDirName
                    if (Test-Path -Path $candidate -PathType Container) {
                        $resolved = (Resolve-Path $candidate).Path
                        if ($flowDirSeen.Add($resolved)) {
                            $hierarchyFlowDirs.Add($resolved) | Out-Null
                        }
                    }
                }
            }

            $flowConfigs = @()
            $flowConfigIndex = New-Object 'System.Collections.Generic.Dictionary[string, object]' ([System.StringComparer]::OrdinalIgnoreCase)
            $flowConfigOrder = New-Object 'System.Collections.Generic.List[string]'

            foreach ($flowDirPath in $hierarchyFlowDirs) {
                $flowFiles = @()
                foreach ($pattern in $Config.flowFilePatterns) {
                    $flowFiles += Get-ChildItem -Path $flowDirPath -Filter $pattern -File -ErrorAction SilentlyContinue
                }
                $flowFiles = $flowFiles | Sort-Object -Property FullName -Unique

                foreach ($flowFile in $flowFiles) {
                    $configKey = [IO.Path]::GetFileNameWithoutExtension($flowFile.Name)
                    if (-not $flowConfigIndex.ContainsKey($configKey)) {
                        $entry = New-JaxFlowConfig -EnvName $envName -ConfigFile $flowFile
                        $entry | Add-Member -NotePropertyName ConfigPaths -NotePropertyValue @() -Force
                        $flowConfigIndex[$configKey] = $entry
                        $flowConfigOrder.Add($configKey) | Out-Null
                    }

                    $entry = $flowConfigIndex[$configKey]
                    $resolvedPath = (Resolve-Path $flowFile.FullName).Path
                    $entry.ConfigPaths += $resolvedPath
                    $entry.ConfigPath = $resolvedPath
                    $entry.FlowDirPath = (Resolve-Path $flowDirPath).Path
                    $entry.EnvDirPath = (Resolve-Path (Split-Path -Parent $flowDirPath)).Path
                }
            }

            foreach ($key in $flowConfigOrder) {
                $flowConfigs += $flowConfigIndex[$key]
            }

            # Flow directories are often anchored in git before they contain a
            # configuration. They are not runnable environments until at least
            # one effective flow config exists in their hierarchy.
            if ($flowConfigs.Count -eq 0) {
                continue
            }

            $envs += [pscustomobject]@{
                Name        = $envName
                EnvDir      = $envDir
                FlowDir     = $flowDir.FullName
                FlowConfigs = $flowConfigs
                HierarchyPaths = $hierarchyPaths
                HierarchyFlowDirs = @($hierarchyFlowDirs)
            }
        }
    }

    $conventionalEnvRoots = @()
    if ($Config.Keys -contains 'conventionalEnvRoots') {
        $conventionalEnvRoots = @($Config['conventionalEnvRoots'])
    } elseif ($Config.Keys -contains 'buildEnvRoots') {
        # Legacy alias — Convert-JaxConfig normally normalizes this, but read it
        # defensively here in case a caller passes a raw config.
        $conventionalEnvRoots = @($Config['buildEnvRoots'])
    }
    $conventionalEnvRoots = @($conventionalEnvRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($conventionalEnvRoots.Count -gt 0) {
        $psakePattern = 'psakefile*.ps1'
        $hasPsakePatternOverride = ($null -ne $Config.tasks) -and ($null -ne $Config.tasks.psakeFilePattern)
        if ($hasPsakePatternOverride) {
            $psakePattern = [string]$Config.tasks.psakeFilePattern
        }
        $existingNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($envEntry in $envs) {
            $envEntryHasName = ($null -ne $envEntry) -and ($envEntry.PSObject.Properties.Match('Name').Count -gt 0)
            if ($envEntryHasName) {
                $existingNames.Add([string]$envEntry.Name) | Out-Null
            }
        }
        $seenDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $computedBuildCandidates = @()
        $relativeNameCounts = @{}
        foreach ($root in $conventionalEnvRoots) {
            $resolvedRoot = Resolve-JaxRepoRootedPath -Path $root -RepoRoot $RepoRoot @commonPSBoundParameters
            if (-not (Test-Path -Path $resolvedRoot -PathType Container)) {
                continue
            }
            $resolvedRoot = (Resolve-Path $resolvedRoot).Path
            $rootName = ([string]$root) -replace '\\', '/'
            $rootName = $rootName.Trim('/')
            if ([string]::IsNullOrWhiteSpace($rootName)) {
                continue
            }
            $psakeFiles = @(Get-ChildItem -Path $resolvedRoot -Filter $psakePattern -File -Recurse -ErrorAction SilentlyContinue)
            foreach ($psakeFile in $psakeFiles) {
                $moduleDir = Split-Path -Path $psakeFile.FullName -Parent
                if ([string]::IsNullOrWhiteSpace($moduleDir)) {
                    continue
                }
                $resolvedModuleDir = (Resolve-Path $moduleDir).Path
                if (-not $seenDirs.Add($resolvedModuleDir)) {
                    continue
                }
                $relative = $resolvedModuleDir.Substring($resolvedRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                if ([string]::IsNullOrWhiteSpace($relative)) {
                    continue
                }
                $relativeName = $relative -replace '\\', '/'
                $relativeNameKey = $relativeName.ToLowerInvariant()
                if (-not $relativeNameCounts.ContainsKey($relativeNameKey)) {
                    $relativeNameCounts[$relativeNameKey] = 0
                }
                $relativeNameCounts[$relativeNameKey]++
                $computedBuildCandidates += [pscustomobject]@{
                    RootName     = $rootName
                    RelativeName = $relativeName
                    RootedName   = "$rootName/$relativeName"
                    ModuleDir    = $resolvedModuleDir
                }
            }
        }

        foreach ($buildCandidate in $computedBuildCandidates) {
            $relativeName = [string]$buildCandidate.RelativeName
            $relativeNameKey = $relativeName.ToLowerInvariant()
            $isRelativeNameUnique = ([int]$relativeNameCounts[$relativeNameKey]) -eq 1
            $legacyName = "build/$relativeName"
            $rootedName = [string]$buildCandidate.RootedName
            $envName = if ($isRelativeNameUnique) { $legacyName } else { $rootedName }
            if (-not $existingNames.Add($envName)) {
                continue
            }

            $aliases = New-Object 'System.Collections.Generic.List[string]'
            if ($isRelativeNameUnique) {
                $aliases.Add($rootedName) | Out-Null
                $aliases.Add($relativeName) | Out-Null
            }
            $preferredCompletionName = if ($isRelativeNameUnique) { $relativeName } else { $rootedName }

            $hierarchyPaths = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $buildCandidate.ModuleDir @commonPSBoundParameters
            $envs += [pscustomobject]@{
                Name                    = $envName
                Aliases                 = @($aliases)
                PreferredCompletionName = $preferredCompletionName
                EnvDir                  = $buildCandidate.ModuleDir
                FlowDir                 = $null
                FlowConfigs             = @()
                HierarchyPaths          = $hierarchyPaths
                HierarchyFlowDirs       = @()
                IsComputed              = $true
            }
        }
    }

    if ($dummyEnabled) {
        $hasDummy = $false
        foreach ($envEntry in $envs) {
            if ($envEntry -and $envEntry.PSObject.Properties.Match('Name').Count -gt 0) {
                if ([string]::Equals([string]$envEntry.Name, $dummyName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $hasDummy = $true
                    break
                }
            }
        }
        if (-not $hasDummy) {
            $envs += (New-JaxDummyEnvironment -Name $dummyName -SkipEnvRoot:$dummySkipEnvRoot)
        }
    }

    return $envs
}
