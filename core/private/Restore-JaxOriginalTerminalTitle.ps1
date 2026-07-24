function Restore-JaxOriginalTerminalTitle {
    [CmdletBinding()]
    param(
        [switch] $Force
    )

    try {
        $didSomething = $false

        Write-JaxTitleDebug ("RESTORE entry: original=[{0}] stashSurface=[{1}] stashWs=[{2}] force=[{3}]" -f $script:JaxOriginalCmuxSurfaceTitle, $script:JaxCmuxTargetSurfaceId, $script:JaxCmuxTargetWorkspaceId, $Force)

        # Cmux surface title restore (the important one for named tabs like "WTW Shell").
        # Restore the SAME surface we renamed (stashed at capture time), falling back to a
        # fresh resolve only if the stash is missing.
        if ($script:JaxOriginalCmuxSurfaceTitle) {
            try {
                $surfaceId = $script:JaxCmuxTargetSurfaceId
                $workspaceId = $script:JaxCmuxTargetWorkspaceId
                if ([string]::IsNullOrWhiteSpace($surfaceId)) {
                    $target = Resolve-JaxCmuxTarget
                    $surfaceId = $target.SurfaceId
                    $workspaceId = $target.WorkspaceId
                }
                if ($surfaceId -and (Get-Command cmux -ErrorAction SilentlyContinue)) {
                    # NB: $args is a PowerShell automatic variable — use a distinct name.
                    $cmuxArgs = @('rename-tab')
                    if (-not [string]::IsNullOrWhiteSpace($workspaceId)) {
                        $cmuxArgs += @('--workspace', $workspaceId)
                    }
                    $cmuxArgs += @('--surface', $surfaceId, '--', $script:JaxOriginalCmuxSurfaceTitle)

                    & cmux @cmuxArgs 2>$null | Out-Null
                    $didSomething = $true
                    Write-JaxTitleDebug ("RESTORE rename-tab fired surface=[{0}] -> [{1}] exit=[{2}]" -f $surfaceId, $script:JaxOriginalCmuxSurfaceTitle, $LASTEXITCODE)
                }
                else {
                    Write-JaxTitleDebug ("RESTORE skipped: surfaceId=[{0}] cmuxPresent=[{1}]" -f $surfaceId, [bool](Get-Command cmux -ErrorAction SilentlyContinue))
                }
            } catch {
                Write-Debug "Cmux title restore failed (non-fatal): $($_.Exception.Message)"
            }
        }

        # OSC restore (best effort). We don't reliably have the previous OSC title captured
        # in all cases, so we only do this if we previously stashed one (rare for pure-OSC terminals).
        if ($script:JaxOriginalOscTerminalTitle) {
            try {
                if (Test-JaxShouldUpdateTerminalTitle) {
                    $esc = [char]0x1b
                    $bel = [char]0x07
                    [Console]::Write("${esc}]0;$($script:JaxOriginalOscTerminalTitle)${bel}")
                    $didSomething = $true
                }
            } catch {}
        }

        if ($didSomething -or $Force) {
            # Clear captured state so a subsequent run in the same process can capture fresh
            $script:JaxOriginalCmuxSurfaceTitle = $null
            $script:JaxOriginalOscTerminalTitle = $null
            $script:JaxCmuxTargetSurfaceId = $null
            $script:JaxCmuxTargetWorkspaceId = $null
            $script:JaxHasMutatedTerminalTitle = $false
        }
    }
    catch {
        Write-Debug "Restore-JaxOriginalTerminalTitle suppressed error: $($_.Exception.Message)"
    }
}
