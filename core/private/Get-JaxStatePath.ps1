function Get-JaxStatePath {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    return (Join-Path $RepoRoot '.jax/state.yml')
}
