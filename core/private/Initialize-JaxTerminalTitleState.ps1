# Module-scoped state for terminal / cmux tab-title management.
#
# Jax.Core.psm1 runs under `Set-StrictMode -Version Latest`, where reading a
# never-assigned $script: variable throws. The tab-title helpers read this state
# (JaxHasMutatedTerminalTitle, JaxOriginalCmuxSurfaceTitle, etc.) on their very
# first call, so we MUST give every variable a defined value at import time —
# otherwise Set-/Restore-/Test- throw, the callers swallow it in try/catch, and
# the whole feature silently no-ops.
#
# This file is dot-sourced by the module loader, so these `$script:` assignments
# land in the module scope that the functions see. It defines no functions.

$script:JaxHasMutatedTerminalTitle  = $false   # have we changed the title this run?
$script:JaxOriginalCmuxSurfaceTitle = $null    # captured tab label to restore (e.g. "WTW Shell")
$script:JaxOriginalOscTerminalTitle = $null    # captured OSC title for plain terminals
$script:JaxCmuxTargetSurfaceId      = $null     # surface we renamed (reused for restore)
$script:JaxCmuxTargetWorkspaceId    = $null     # workspace context for that surface
$script:JaxIsCmuxSurfaceCached      = $null     # tri-state cache: $null = not yet probed

# Finish-state tab title: instead of restoring the pre-jax label we leave the last
# task on the tab, prefixed with a spinner frame while running and ✓/✗ once done.
$script:JaxTitleSpinnerFrames       = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
$script:JaxTitleSpinnerIndex        = 0         # advances on every running-title update
$script:JaxLastRenderedTitleBody    = $null     # last body (no state glyph) for the finish mark
$script:JaxTitleRunFailed           = $false    # set by a runner catch so finish shows ✗ not ✓
