function Get-JaxState {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [switch] $NoSavedSettings
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot @commonParams
    }

    Initialize-JaxStateDefaults @commonParams

    $defaults = $script:JaxStateDefaults
    if ($NoSavedSettings) {
        return $defaults
    }

    $statePath = Get-JaxStatePath -RepoRoot $RepoRoot @commonParams
    if (-not (Test-Path -Path $statePath -PathType Leaf)) {
        return $defaults
    }

    $state = Read-JaxYaml -Path $statePath @commonParams
    if ($null -eq $state) {
        return $defaults
    }

    if ($state -isnot [System.Collections.IDictionary]) {
        throw "Invalid Jax state at '$statePath': expected map/object."
    }

    # Backward compatibility: strip execution selectors if they exist in old state files.
    if ($state -is [System.Collections.IDictionary] -and $state.Contains('core') -and $state['core'] -is [System.Collections.IDictionary]) {
        $core = $state['core']
        foreach ($k in @('from', 'to', 'only')) {
            if ($core.Contains($k)) {
                $core.Remove($k) | Out-Null
            }
        }
    }

    return Merge-JaxHashtable -Base $defaults -Overlay $state @commonParams
}
