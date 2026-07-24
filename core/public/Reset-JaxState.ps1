function Reset-JaxState {
    [CmdletBinding()]
    param (
        [string] $RepoRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot @commonParams
    }

    $statePath = Get-JaxStatePath -RepoRoot $RepoRoot @commonParams
    if (Test-Path -Path $statePath -PathType Leaf) {
        Remove-Item -Path $statePath -Force
    }
}
