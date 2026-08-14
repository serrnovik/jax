function Update-JaxState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Updates,
        [string[]] $RemoveCoreKeys = @(),
        [string] $RepoRoot,
        [switch] $NoSavedSettings
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot @commonParams
    }

    $state = Get-JaxState -RepoRoot $RepoRoot -NoSavedSettings:$NoSavedSettings @commonParams
    $merged = Merge-JaxHashtable -Base $state -Overlay $Updates @commonParams

    # Core rule: never persist execution selectors in saved state (they are per-invocation only).
    # This prevents stale slicing surprises (e.g. "to" from yesterday truncating today's plan).
    # Plugins may persist their own settings under their own namespace (e.g. plugins.bob.*, plugins.test.*).
    if ($merged -is [System.Collections.IDictionary] -and $merged.Contains('core') -and $merged['core'] -is [System.Collections.IDictionary]) {
        $core = $merged['core']
        # A merge cannot express "forget this": removals are named explicitly,
        # so `settings unset <key>` does not have to reset the whole file.
        foreach ($k in @('from', 'to', 'only') + @($RemoveCoreKeys)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$k) -and $core.Contains($k)) {
                $core.Remove($k) | Out-Null
            }
        }
    }

    if (-not $NoSavedSettings) {
        $statePath = Get-JaxStatePath -RepoRoot $RepoRoot @commonParams
        $stateDir = Split-Path -Path $statePath -Parent
        if (-not (Test-Path -Path $stateDir -PathType Container)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }
        Write-JaxYaml -InputObject $merged -Path $statePath @commonParams
    }

    return $merged
}
