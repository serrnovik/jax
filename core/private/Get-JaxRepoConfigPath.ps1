function Get-JaxRepoConfigPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    return (Join-Path $RepoRoot '.jax/jax.config.yml')
}
