function Resolve-JaxContainerPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $HostPath,
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $ContainerRoot = '/jax/src'
    )

    $resolvedHostPath = Resolve-JaxRepoRootedPath -Path $HostPath -RepoRoot $RepoRoot
    $resolvedHostPath = [IO.Path]::GetFullPath($resolvedHostPath)
    $repoRootFull = [IO.Path]::GetFullPath($RepoRoot)

    if ($resolvedHostPath.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $resolvedHostPath.Substring($repoRootFull.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $containerPath = Join-Path $ContainerRoot $relative
        return ($containerPath -replace '\\', '/')
    }

    return ($resolvedHostPath -replace '\\', '/')
}
