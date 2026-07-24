function Get-JaxCurrentCmuxSurfaceTitle {
    [CmdletBinding()]
    param(
        [string] $SurfaceId
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SurfaceId)) {
            $SurfaceId = (Resolve-JaxCmuxTarget).SurfaceId
        }
        if ([string]::IsNullOrWhiteSpace($SurfaceId)) {
            return $null
        }

        $cmux = Get-Command cmux -ErrorAction SilentlyContinue
        if (-not $cmux) {
            return $null
        }

        # Preferred: structured output
        $raw = & $cmux.Source list-pane-surfaces --json 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $parsed -or -not $parsed.surfaces) {
            return $null
        }

        # Exact match by ref
        $match = $parsed.surfaces | Where-Object {
            ($_.ref -eq $SurfaceId) -or ($_.surface_ref -eq $SurfaceId) -or ($_.id -eq $SurfaceId)
        } | Select-Object -First 1

        if ($match -and -not [string]::IsNullOrWhiteSpace($match.title)) {
            return [string]$match.title
        }

        # Fallback: the currently selected surface in this pane
        $selected = $parsed.surfaces | Where-Object { $_.selected } | Select-Object -First 1
        if ($selected -and -not [string]::IsNullOrWhiteSpace($selected.title)) {
            return [string]$selected.title
        }
    }
    catch {
        Write-Debug "Get-JaxCurrentCmuxSurfaceTitle suppressed error: $($_.Exception.Message)"
    }

    return $null
}
