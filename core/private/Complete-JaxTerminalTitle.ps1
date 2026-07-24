function Complete-JaxTerminalTitle {
    <#
    .SYNOPSIS
        Finish-state tab title. Instead of restoring the pre-jax label, re-stamp the
        LAST task title with a ✓ (success) or ✗ (failure) glyph, so the tab keeps
        showing what was done.
    .DESCRIPTION
        Called from the same finally/catch sites that used to call
        Restore-JaxOriginalTerminalTitle. Reuses the surface stashed at capture time
        and the last body remembered by Set-JaxTerminalTabTitle. No-ops cleanly if no
        title was ever set this run (e.g. plan/dry-run). Clears state so the outer
        finally blocks and the next run start fresh, and so nested completions don't
        double-stamp.
    .PARAMETER Failed
        Force the failure glyph. Also honored via $script:JaxTitleRunFailed, which a
        runner catch sets before its finally runs.
    #>
    [CmdletBinding()]
    param(
        [switch] $Failed
    )

    try {
        $body = $script:JaxLastRenderedTitleBody
        if ([string]::IsNullOrWhiteSpace($body)) {
            # Nothing was set (or an outer finally already finalized) — nothing to do.
            return
        }

        $glyph = if ($Failed -or $script:JaxTitleRunFailed) { '✗' } else { '✓' }
        $display = "$glyph $body"

        Write-JaxTitleDebug ("COMPLETE glyph=[{0}] surface=[{1}] body=[{2}]" -f $glyph, $script:JaxCmuxTargetSurfaceId, $body)

        if ($script:JaxCmuxTargetSurfaceId) {
            Set-JaxCmuxSurfaceTitle -Title $display `
                -SurfaceId $script:JaxCmuxTargetSurfaceId `
                -WorkspaceId $script:JaxCmuxTargetWorkspaceId
        }
        elseif (Test-JaxShouldUpdateTerminalTitle) {
            $esc = [char]0x1b
            $bel = [char]0x07
            [Console]::Write("${esc}]0;${display}${bel}")
        }

        # Clear captured state so outer finally blocks no-op and the next run in this
        # process starts fresh.
        $script:JaxLastRenderedTitleBody    = $null
        $script:JaxOriginalCmuxSurfaceTitle = $null
        $script:JaxOriginalOscTerminalTitle = $null
        $script:JaxCmuxTargetSurfaceId      = $null
        $script:JaxCmuxTargetWorkspaceId    = $null
        $script:JaxHasMutatedTerminalTitle  = $false
        $script:JaxTitleRunFailed           = $false
        $script:JaxTitleSpinnerIndex        = 0
    }
    catch {
        Write-Debug "Complete-JaxTerminalTitle suppressed error: $($_.Exception.Message)"
    }
}
