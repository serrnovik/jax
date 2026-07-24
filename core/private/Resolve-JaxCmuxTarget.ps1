function Resolve-JaxCmuxTarget {
    <#
    .SYNOPSIS
        Resolve the cmux surface (and workspace) to target for tab-title changes.
    .DESCRIPTION
        cmux does not reliably inject CMUX_SURFACE_ID / CMUX_WORKSPACE_ID into every
        shell it spawns, so relying on those alone silently disables tab-title updates.
        We honor the env vars when present, but otherwise fall back to
        `cmux identify --json`, which reports the calling (and focused) surface without
        requiring any environment variables — the same resolution cmux itself uses.

        Returns a hashtable @{ SurfaceId; WorkspaceId }; either value may be $null when
        nothing could be resolved (e.g. not running inside cmux).
    #>
    [CmdletBinding()]
    param()

    $result = @{ SurfaceId = $null; WorkspaceId = $null }

    if (-not [string]::IsNullOrWhiteSpace($env:CMUX_SURFACE_ID)) {
        $result.SurfaceId = [string]$env:CMUX_SURFACE_ID
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CMUX_WORKSPACE_ID)) {
        $result.WorkspaceId = [string]$env:CMUX_WORKSPACE_ID
    }

    # Env already gave us a surface — good enough; don't pay for a socket round-trip.
    if ($result.SurfaceId) {
        return $result
    }

    try {
        $cmux = Get-Command cmux -ErrorAction SilentlyContinue
        if (-not $cmux) {
            return $result
        }

        $raw = & $cmux.Source identify --json 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $result
        }

        $info = $raw | ConvertFrom-Json -ErrorAction Stop

        # Prefer the surface that invoked us (stable regardless of focus changes during
        # the run), then fall back to whatever surface is currently focused.
        foreach ($scope in @($info.caller, $info.focused)) {
            if (-not $scope) { continue }
            if (-not $result.SurfaceId -and $scope.surface_ref) {
                $result.SurfaceId = [string]$scope.surface_ref
            }
            if (-not $result.WorkspaceId -and $scope.workspace_ref) {
                $result.WorkspaceId = [string]$scope.workspace_ref
            }
            if ($result.SurfaceId) { break }
        }
    }
    catch {
        Write-Debug "Resolve-JaxCmuxTarget suppressed error: $($_.Exception.Message)"
    }

    return $result
}
