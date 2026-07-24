function Get-JaxScriptSearchPaths {
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
    $dirNames = @('scripts')
    if ($Config.scripts -and $Config.scripts.dirNames) {
        $dirNames = @($Config.scripts.dirNames)
    }

    foreach ($basePath in $hierarchy) {
        foreach ($dirName in $dirNames) {
            if ([string]::IsNullOrWhiteSpace($dirName)) {
                continue
            }
            $candidate = Join-Path $basePath $dirName
            if (-not $seen.ContainsKey($candidate)) {
                $paths += [ordered]@{
                    Path          = $candidate
                    DirectoryType = 'conventional'
                }
                $seen[$candidate] = $true
            }
        }
    }

    if ($Config.scripts -and $Config.scripts.nonConventionalDirs) {
        foreach ($dir in @($Config.scripts.nonConventionalDirs)) {
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
