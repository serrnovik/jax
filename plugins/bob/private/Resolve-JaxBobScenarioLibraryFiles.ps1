function Resolve-JaxBobScenarioLibraryFiles {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $paths = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir
    $dirName = $Config.scenarioLibDirName
    if ([string]::IsNullOrWhiteSpace($dirName)) {
        $dirName = 'scenarios-lib'
    }

    $files = New-Object 'System.Collections.Generic.List[string]'
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($path in $paths) {
        $libraryDir = Join-Path $path $dirName
        if (-not (Test-Path -Path $libraryDir -PathType Container)) {
            continue
        }

        $candidates = @()
        $candidates += Get-ChildItem -Path $libraryDir -Filter '*.yml' -File -Recurse -ErrorAction SilentlyContinue
        $candidates += Get-ChildItem -Path $libraryDir -Filter '*.yaml' -File -Recurse -ErrorAction SilentlyContinue
        $candidates = $candidates | Sort-Object -Property FullName -Unique

        foreach ($file in $candidates) {
            $resolved = (Resolve-Path $file.FullName).Path
            if ($seen.Add($resolved)) {
                $files.Add($resolved) | Out-Null
            }
        }
    }

    return @($files)
}
