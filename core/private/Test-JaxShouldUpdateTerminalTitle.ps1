function Test-JaxShouldUpdateTerminalTitle {
    [CmdletBinding()]
    param()

    function Test-JaxIsAiAgentSession {
        [CmdletBinding()]
        param()

        if ($env:AI_AGENT -or $env:CMUX_AGENT_CODE) {
            return $true
        }

        if ($env:CODEX_THREAD_ID -or $env:CODEX_CI) {
            return $true
        }

        if ($env:CLAUDECODE -or $env:CLAUDE_CODE_ENTRYPOINT) {
            return $true
        }

        return $false
    }

    # Explicit kill switches (user or automation can force off)
    if ($env:JAX_DISABLE_TAB_TITLE -or $env:JAX_NO_TAB_TITLE -or $env:JAX_TAB_TITLE -eq '0' -or $env:JAX_TAB_TITLE -eq 'false') {
        return $false
    }

    # Never in CI / non-interactive automation
    if ($env:CI -or $env:GITHUB_ACTIONS -or $env:TEAMCITY_VERSION -or $env:GITLAB_CI -or $env:BUILDKITE -or $env:DRONE -or $env:SEMAPHORE) {
        return $false
    }

    # Explicit force (for power users on other terminals)
    if ($env:JAX_FORCE_TAB_TITLE -or $env:JAX_TAB_TITLE -eq '1' -or $env:JAX_TAB_TITLE -eq 'true') {
        return $true
    }

    # AI agent terminals often manage their own cmux tab title with task-level status.
    # Keep Jax's build-progress tab titles for human shells only, unless explicitly forced.
    if (Test-JaxIsAiAgentSession) {
        return $false
    }

    # Primary supported terminals: Ghostty (cmux runs inside Ghostty) and close cousins
    $isGhostty = ($env:TERM_PROGRAM -eq 'ghostty') -or
                 (-not [string]::IsNullOrWhiteSpace($env:GHOSTTY_BIN_DIR)) -or
                 (-not [string]::IsNullOrWhiteSpace($env:GHOSTTY_RESOURCES_DIR))

    # Strong signals: when these are present we are inside a cmux-managed surface/pane.
    # This is the important case for users who use named cmux workspaces + worktree-workspace (wtw).
    $isCmux = (-not [string]::IsNullOrWhiteSpace($env:CMUX_SURFACE_ID)) -or
              (-not [string]::IsNullOrWhiteSpace($env:CMUX_WORKSPACE_ID)) -or
              (-not [string]::IsNullOrWhiteSpace($env:CMUX)) -or
              (-not [string]::IsNullOrWhiteSpace($env:CMUX_SESSION)) -or
              (-not [string]::IsNullOrWhiteSpace($env:CMUX_SOCKET))

    $isWezterm = (-not [string]::IsNullOrWhiteSpace($env:WEZTERM_EXECUTABLE)) -or
                 (-not [string]::IsNullOrWhiteSpace($env:WEZTERM_PANE))

    $isIterm = $env:TERM_PROGRAM -eq 'iTerm.app'

    if ($isGhostty -or $isCmux -or $isWezterm -or $isIterm) {
        return $true
    }

    # cmux does not always inject CMUX_* env vars into the shell, so the env checks above
    # can miss a genuine cmux surface. As a last resort, ask cmux directly (cached per
    # process — whether we're inside cmux doesn't change for the life of this shell).
    if ($null -eq $script:JaxIsCmuxSurfaceCached) {
        $script:JaxIsCmuxSurfaceCached = [bool] (Resolve-JaxCmuxTarget).SurfaceId
    }
    if ($script:JaxIsCmuxSurfaceCached) {
        return $true
    }

    # Conservative default: do not touch titles in unknown terminals / scripts / docker / ssh without explicit force
    return $false
}
