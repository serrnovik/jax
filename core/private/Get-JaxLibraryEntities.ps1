function Get-JaxLibraryEntities {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config,
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($EnvDir)) {
        return @()
    }

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot @commonParams
    }

    $paths = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir @commonParams
    $dirName = 'scenarios-lib'
    if ($Config.scenarioLibDirName) {
        $dirName = $Config.scenarioLibDirName
    }

    $seenFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $entities = @()
    $discoveredKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $scenarioLibrary = @{}

    $context = @{
        RepoRoot = $RepoRoot
        EnvDir   = $EnvDir
        Config   = $Config
    }

    foreach ($path in $paths) {
        $libraryDir = Join-Path $path $dirName
        if (-not (Test-Path -Path $libraryDir -PathType Container)) {
            continue
        }

        $files = @(Get-ChildItem -Path $libraryDir -Filter '*.yml' -File -Recurse -ErrorAction SilentlyContinue)
        $files += @(Get-ChildItem -Path $libraryDir -Filter '*.yaml' -File -Recurse -ErrorAction SilentlyContinue)

        foreach ($file in $files) {
            if (-not $seenFiles.Add($file.FullName)) {
                continue
            }

            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                $yaml = ConvertFrom-Yaml $content -AllDocuments:$false -Ordered
                if ($yaml -is [System.Collections.IDictionary]) {
                    # Make the current library available for resolvers that need cross-references (e.g. bob-library).
                    $scenarioLibrary = Merge-JaxHashtable -Base $scenarioLibrary -Overlay $yaml @commonParams
                    $context['ScenarioLibrary'] = $scenarioLibrary

                    foreach ($key in $yaml.Keys) {
                        # Ignore keys starting with lib_ (conventions?)
                        if ($key.ToString().StartsWith('lib_')) { continue }

                        if ($discoveredKeys.Add($key)) {
                             $val = $yaml[$key]
                             try {
                                 $entity = Convert-JaxScenarioItemToRunEntity -Key $key -Value $val -ScenarioName "Library:$key" -ProvenancePath $file.FullName -Context $context @commonParams
                                 $entities += $entity
                             } catch {
                                 # Fallback: create stub if resolution fails (e.g. missing referenced libs during discovery)
                                 # Write-Warning "Discovery (Partial): $key ($($file.Name))"
                                 $entities += New-JaxRunEntity -Key $key -ScenarioName "Library:$key" -ProvenancePath $file.FullName @commonParams
                             }
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to parse library file '$($file.FullName)': $_"
            }
        }
    }

    return $entities
}
