function Get-JaxLogDir {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    return (Join-Path $RepoRoot '.jax/logs')
}
