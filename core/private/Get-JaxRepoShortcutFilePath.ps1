function Get-JaxRepoShortcutFilePath {
    <#
    .SYNOPSIS
        Path to the repo-local shortcut file (.jax/jax.shortcut.yml).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    return (Join-Path $RepoRoot '.jax' 'jax.shortcut.yml')
}
