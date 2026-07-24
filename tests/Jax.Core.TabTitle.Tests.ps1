# Focused unit tests for the cmux/terminal tab-title finish-state feature.
# These dot-source the individual private function files (they aren't exported by
# the module) into this scope, alongside the module-state initializer so the
# $script: spinner/last-body state resolves to the same scope the functions see.

BeforeAll {
    $private = Join-Path $PSScriptRoot '../core/private'
    . (Join-Path $private 'Initialize-JaxTerminalTitleState.ps1')
    . (Join-Path $private 'Get-JaxShortEnvToken.ps1')
    . (Join-Path $private 'Get-JaxTitleSpinnerFrame.ps1')
    . (Join-Path $private 'Get-JaxTabTitleForRun.ps1')
    . (Join-Path $private 'Test-JaxShouldUpdateTerminalTitle.ps1')

    # Get-JaxTabTitleForRun consults Get-JaxConfig; stub it so icon resolution is
    # deterministic (no user config / autocomplete overrides).
    function Get-JaxConfig { param([Parameter(ValueFromRemainingArguments)]$rest) @{} }

    $script:JaxTitleEnvNames = @(
        'AI_AGENT',
        'BUILDKITE',
        'CI',
        'CLAUDECODE',
        'CLAUDE_CODE_ENTRYPOINT',
        'CMUX',
        'CMUX_AGENT_CODE',
        'CMUX_SESSION',
        'CMUX_SOCKET',
        'CMUX_SURFACE_ID',
        'CMUX_WORKSPACE_ID',
        'CODEX_CI',
        'CODEX_THREAD_ID',
        'DRONE',
        'GHOSTTY_BIN_DIR',
        'GHOSTTY_RESOURCES_DIR',
        'GITHUB_ACTIONS',
        'GITLAB_CI',
        'JAX_DISABLE_TAB_TITLE',
        'JAX_FORCE_TAB_TITLE',
        'JAX_NO_TAB_TITLE',
        'JAX_TAB_TITLE',
        'SEMAPHORE',
        'TEAMCITY_VERSION',
        'TERM_PROGRAM',
        'WEZTERM_EXECUTABLE',
        'WEZTERM_PANE'
    )
    $script:JaxOriginalTitleEnv = @{}
    foreach ($name in $script:JaxTitleEnvNames) {
        $script:JaxOriginalTitleEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }

    function Clear-JaxTitleEnv {
        foreach ($name in $script:JaxTitleEnvNames) {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        $script:JaxIsCmuxSurfaceCached = $null
    }

    function Restore-JaxTitleEnv {
        foreach ($name in $script:JaxTitleEnvNames) {
            [Environment]::SetEnvironmentVariable($name, $script:JaxOriginalTitleEnv[$name], 'Process')
        }
        $script:JaxIsCmuxSurfaceCached = $null
    }
}

AfterAll {
    Restore-JaxTitleEnv
}

Describe 'Get-JaxShortEnvToken' {
    It 'keeps the client part and truncates to five chars with an ellipsis' {
        Get-JaxShortEnvToken -EnvName 'demo-app/build' | Should -Be 'demo-…'
    }
    It 'keeps the first non-flow segment' {
        Get-JaxShortEnvToken -EnvName 'ab/cd/ef' | Should -Be 'ab'
    }
    It 'drops a leading flow segment so the env name wins (build/wtw -> wtw)' {
        Get-JaxShortEnvToken -EnvName 'build/wtw' | Should -Be 'wtw'
    }
    It 'drops a trailing flow segment (demo-app/build -> demo-…)' {
        Get-JaxShortEnvToken -EnvName 'demo-app/build' | Should -Be 'demo-…'
    }
    It 'also drops a segment matching the explicit FlowName' {
        Get-JaxShortEnvToken -EnvName 'ops/wtw' -FlowName 'ops' | Should -Be 'wtw'
    }
    It 'leaves short names untouched' {
        Get-JaxShortEnvToken -EnvName 'dev' | Should -Be 'dev'
    }
    It 'returns empty for blank input' {
        Get-JaxShortEnvToken -EnvName ''   | Should -Be ''
        Get-JaxShortEnvToken -EnvName '  ' | Should -Be ''
    }
}

Describe 'Get-JaxTitleSpinnerFrame' {
    BeforeEach { $script:JaxTitleSpinnerIndex = 0 }

    It 'advances one frame per call' {
        Get-JaxTitleSpinnerFrame | Should -Be '⠋'
        Get-JaxTitleSpinnerFrame | Should -Be '⠙'
        Get-JaxTitleSpinnerFrame | Should -Be '⠹'
    }
    It 'wraps around at the end of the frame set' {
        $script:JaxTitleSpinnerIndex = $script:JaxTitleSpinnerFrames.Count - 1
        Get-JaxTitleSpinnerFrame | Should -Be $script:JaxTitleSpinnerFrames[-1]
        Get-JaxTitleSpinnerFrame | Should -Be $script:JaxTitleSpinnerFrames[0]
    }
}

Describe 'Get-JaxTabTitleForRun layout' {
    It 'orders bracketed short env then task then arrow current' {
        $t = Get-JaxTabTitleForRun -EntityKey 'build' -EnvName 'demo-app' -FlowName 'build' -CurrentPsakeTask 'EnsureFlutter'
        $t | Should -Be '[demo-…] build → EnsureFlutter'
    }
    It 'omits the arrow when the current task equals the entity key' {
        $t = Get-JaxTabTitleForRun -EntityKey 'build' -EnvName 'demo-app' -FlowName 'build' -CurrentPsakeTask 'build'
        $t | Should -Be '[demo-…] build'
    }
    It 'puts the env token before the task' {
        $t = Get-JaxTabTitleForRun -EntityKey 'pack' -EnvName 'sample-app/pack' -FlowName 'pack'
        $t | Should -Match '\[sampl…\] pack$'
    }
}

Describe 'Test-JaxShouldUpdateTerminalTitle' {
    BeforeEach {
        Clear-JaxTitleEnv
    }

    It 'updates titles for human cmux shells' {
        $env:CMUX_SURFACE_ID = 'surface:1'

        Test-JaxShouldUpdateTerminalTitle | Should -BeTrue
    }

    It 'does not update titles in Codex agent shells' {
        $env:CMUX_SURFACE_ID = 'surface:1'
        $env:CODEX_THREAD_ID = 'thread-123'

        Test-JaxShouldUpdateTerminalTitle | Should -BeFalse
    }

    It 'does not update titles in Claude agent shells' {
        $env:CMUX_SURFACE_ID = 'surface:1'
        $env:CLAUDECODE = '1'

        Test-JaxShouldUpdateTerminalTitle | Should -BeFalse
    }

    It 'lets an explicit force override agent suppression' {
        $env:CMUX_SURFACE_ID = 'surface:1'
        $env:CODEX_THREAD_ID = 'thread-123'
        $env:JAX_FORCE_TAB_TITLE = '1'

        Test-JaxShouldUpdateTerminalTitle | Should -BeTrue
    }
}
