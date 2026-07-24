function Set-JaxTerminalTabTitle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Title
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return
    }

    try {
        if (-not (Test-JaxShouldUpdateTerminalTitle)) {
            return
        }

        # Lazy one-time capture of the pre-jax title so we can reliably restore it later
        # (including on crashes, Ctrl-C, or exceptions). Only capture on the first mutation
        # of a given top-level jax invocation.
        if (-not $script:JaxHasMutatedTerminalTitle) {
            $script:JaxHasMutatedTerminalTitle = $true

            # Resolve the cmux surface ONCE (env vars if injected, else `cmux identify`)
            # and reuse it for both the rename and the later restore, so they always act
            # on the same tab even if focus moves to another surface mid-run.
            $target = Resolve-JaxCmuxTarget
            $script:JaxCmuxTargetSurfaceId = $target.SurfaceId
            $script:JaxCmuxTargetWorkspaceId = $target.WorkspaceId

            # Capture the tab's current title (e.g. "WTW Shell") so we can restore it on
            # completion, exceptions, or Ctrl-C.
            if (-not $script:JaxOriginalCmuxSurfaceTitle -and $script:JaxCmuxTargetSurfaceId) {
                $currentCmux = Get-JaxCurrentCmuxSurfaceTitle -SurfaceId $script:JaxCmuxTargetSurfaceId
                if ($currentCmux) {
                    $script:JaxOriginalCmuxSurfaceTitle = $currentCmux
                }
            }
            Write-JaxTitleDebug ("CAPTURE surface=[{0}] ws=[{1}] original=[{2}] firstTitle=[{3}]" -f $script:JaxCmuxTargetSurfaceId, $script:JaxCmuxTargetWorkspaceId, $script:JaxOriginalCmuxSurfaceTitle, $Title)
        }

        # Remember the bare body (no glyph) so Complete-JaxTerminalTitle can re-stamp it
        # with ✓/✗ on finish instead of restoring the pre-jax label.
        $script:JaxLastRenderedTitleBody = $Title

        # Prepend a spinner frame so the tab reads as "in progress". The frame advances
        # per update, so it visibly cycles as inner psake tasks run.
        $display = "$(Get-JaxTitleSpinnerFrame) $Title"

        # 1. For cmux-managed surfaces (named tabs + wtw), the visible tab label is
        #    controlled by `cmux rename-tab`, not terminal OSC sequences.
        if ($script:JaxCmuxTargetSurfaceId) {
            Set-JaxCmuxSurfaceTitle -Title $display `
                -SurfaceId $script:JaxCmuxTargetSurfaceId `
                -WorkspaceId $script:JaxCmuxTargetWorkspaceId
        }
        else {
            # 2. Plain terminals (Ghostty/iTerm/WezTerm/Alacritty without a cmux surface):
            #    emit the classic OSC title sequence. We skip this inside cmux so we don't
            #    leave a stale pane title that could shadow the restored tab label.
            $esc = [char]0x1b
            $bel = [char]0x07
            [Console]::Write("${esc}]0;${display}${bel}")
        }
    }
    catch {
        # Titles are purely cosmetic. Never let a failure affect the actual work.
        Write-Debug "Set-JaxTerminalTabTitle suppressed error: $($_.Exception.Message)"
    }
}
