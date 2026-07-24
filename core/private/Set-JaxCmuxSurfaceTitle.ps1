function Set-JaxCmuxSurfaceTitle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Title,
        [string] $SurfaceId,
        [string] $WorkspaceId
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return
    }

    try {
        # Resolve the target surface if the caller didn't pass one. This works even when
        # cmux does not inject CMUX_SURFACE_ID into the shell (via `cmux identify`).
        if ([string]::IsNullOrWhiteSpace($SurfaceId)) {
            $target = Resolve-JaxCmuxTarget
            $SurfaceId = $target.SurfaceId
            if ([string]::IsNullOrWhiteSpace($WorkspaceId)) {
                $WorkspaceId = $target.WorkspaceId
            }
        }

        if ([string]::IsNullOrWhiteSpace($SurfaceId)) {
            return
        }

        $cmux = Get-Command cmux -ErrorAction SilentlyContinue
        if (-not $cmux) {
            return
        }

        # NB: $args is a PowerShell automatic variable — use a distinct name.
        $cmuxArgs = @('rename-tab')
        if (-not [string]::IsNullOrWhiteSpace($WorkspaceId)) {
            $cmuxArgs += @('--workspace', $WorkspaceId)
        }
        $cmuxArgs += @('--surface', $SurfaceId, '--', $Title)

        # Fire and forget, completely silent. This is what wtw and other tools do.
        & $cmux.Source @cmuxArgs 2>$null | Out-Null
    }
    catch {
        Write-Debug "Set-JaxCmuxSurfaceTitle suppressed error: $($_.Exception.Message)"
    }
}
