function Resolve-JaxRepoRootedPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string] $RepoRoot,
        [string] $WorkingDir
    )

    if ($Path.StartsWith('^/')) {
        if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            throw "RepoRoot is required to resolve git-rooted path '$Path'."
        }
        $relative = $Path.Substring(2)
        return (Join-Path $RepoRoot $relative)
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkingDir)) {
        return (Join-Path $WorkingDir $Path)
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Join-Path $RepoRoot $Path)
    }

    return $Path
}
