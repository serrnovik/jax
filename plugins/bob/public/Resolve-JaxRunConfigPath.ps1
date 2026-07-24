function Resolve-JaxRunConfigPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string] $RepoRoot,
        [string] $BaseDir
    )

    if ($Path.StartsWith('^^') -or $Path.StartsWith('!!')) {
        $Path = $Path.Substring(2)
        $Path = $Path.TrimStart('\', '/')
        if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
            return (Join-Path $RepoRoot $Path)
        }
    }

    if ($Path.StartsWith('^') -or $Path.StartsWith('!')) {
        $Path = $Path.Substring(1)
        $Path = $Path.TrimStart('\', '/')
        if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
            return (Join-Path $RepoRoot $Path)
        }
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    if (-not [string]::IsNullOrWhiteSpace($BaseDir)) {
        return (Join-Path $BaseDir $Path)
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Join-Path $RepoRoot $Path)
    }

    return $Path
}
