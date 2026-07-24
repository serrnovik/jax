function Get-JaxTaskSearchPaths {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [System.Collections.IDictionary] $Config,
        [string] $EnvDir,
        [switch] $SkipEnvRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $paths = @()
    $seen = @{}
    $hierarchy = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir -SkipEnvRoot:$SkipEnvRoot @commonParams
    foreach ($path in $hierarchy) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and -not $seen.ContainsKey($path)) {
            $paths += [ordered]@{
                Path          = $path
                DirectoryType = 'conventional'
            }
            $seen[$path] = $true
        }
    }

    if ($Config.tasks -and $Config.tasks.nonConventionalDirs) {
        foreach ($dir in @($Config.tasks.nonConventionalDirs)) {
            if ([string]::IsNullOrWhiteSpace($dir)) {
                continue
            }
            $resolved = Resolve-JaxRepoRootedPath -Path $dir -RepoRoot $RepoRoot @commonParams
            if (-not $seen.ContainsKey($resolved)) {
                $paths += [ordered]@{
                    Path          = $resolved
                    DirectoryType = 'nonConventional'
                }
                $seen[$resolved] = $true
            }
        }
    }

    return @($paths)
}
