Describe "Task parameters shadowed by Jax's own flags" {
    BeforeAll {
        $script:JaxRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:JaxScript = Join-Path $script:JaxRoot 'jax.ps1'
        $script:FixtureRoot = Join-Path $TestDrive 'jax-shadow'
        Copy-Item -LiteralPath (Join-Path $script:JaxRoot 'tests/fixtures/jax-shadow') -Destination $script:FixtureRoot -Recurse
        & git -C $script:FixtureRoot init --quiet

        # Through the parser, not splatting: the bug was in command-line binding,
        # so the test has to bind real tokens the way a shell does. The refusal is
        # a terminating error, which unwinds past *>&1 — catch it the way the shell
        # launcher does, so the message is assertable alongside normal output.
        function Invoke-ShadowRun {
            param(
                [string] $Env = 'shadow_client/dev',
                [string] $Only = 'ShowShadowedParam',
                [string] $ExtraArgs = ''
            )

            $command = "& '{0}' -C '{1}' run -env {2} -only {3} -noCache {4} *>&1" -f
                $script:JaxScript, $script:FixtureRoot, $Env, $Only, $ExtraArgs

            Push-Location $script:JaxRoot
            $oldRepoRoot = $env:JAX_REPO_ROOT
            try {
                $raw = (Invoke-Expression $command | Out-String)
            } catch {
                $raw = $_.Exception.Message
            } finally {
                $env:JAX_REPO_ROOT = $oldRepoRoot
                Pop-Location
            }
            return ($raw -replace "$([char]27)\[[0-9;]*m", '')
        }
    }

    It "refuses the run when the shadowed flag was passed" {
        $output = Invoke-ShadowRun -ExtraArgs '-client shadow_client'

        $output | Should -Match '-client did not reach the task'
        $output | Should -Match 'ShowShadowedParam'
        # The task must not have run with its default as if the override arrived.
        $output | Should -Not -Match 'Props\.client: claude'
    }

    It "names every remedy in the failure" {
        $output = Invoke-ShadowRun -ExtraArgs '-client shadow_client'

        $output | Should -Match 'rename the task parameter'
        $output | Should -Match "flow file's 'args:'"
    }

    It "warns, but still runs, when the flag was not passed" {
        $output = Invoke-ShadowRun

        $output | Should -Match "'client' is a name Jax binds for itself"
        $output | Should -Match 'Props\.client: claude'
    }

    It "leaves a non-colliding parameter of the same task bindable" {
        $output = Invoke-ShadowRun -ExtraArgs '-ownParam overridden'

        $output | Should -Match 'Props\.ownParam: overridden'
        $output | Should -Not -Match 'did not reach the task'
    }

    It "says nothing about a psakefile that declares no colliding name" {
        $output = Invoke-ShadowRun -Env 'shadow_client/clean' -Only 'NoShadowHere' -ExtraArgs '-mcpClient codex'

        $output | Should -Match 'Props\.mcpClient: codex'
        $output | Should -Not -Match 'binds for itself'
        $output | Should -Not -Match 'did not reach the task'
    }

    It "catches the collision in a script param() too" {
        $output = Invoke-ShadowRun -Only 'shadow-script' -ExtraArgs '-client shadow_client'

        $output | Should -Match '-client did not reach the task'
        $output | Should -Not -Match 'Script\.client: claude'
    }
}

Describe "-client discarded by a fully qualified -env" {
    BeforeAll {
        $script:JaxRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:JaxScript = Join-Path $script:JaxRoot 'jax.ps1'
        $script:FixtureRoot = Join-Path $TestDrive 'jax-shadow-client'
        Copy-Item -LiteralPath (Join-Path $script:JaxRoot 'tests/fixtures/jax-shadow') -Destination $script:FixtureRoot -Recurse
        & git -C $script:FixtureRoot init --quiet

        function Invoke-ClientSelectorRun {
            param([string] $ExtraArgs = '')

            $command = "& '{0}' -C '{1}' run -env shadow_client/clean -only NoShadowHere -noCache {2} *>&1" -f
                $script:JaxScript, $script:FixtureRoot, $ExtraArgs

            Push-Location $script:JaxRoot
            $oldRepoRoot = $env:JAX_REPO_ROOT
            try {
                $raw = (Invoke-Expression $command | Out-String)
            } catch {
                $raw = $_.Exception.Message
            } finally {
                $env:JAX_REPO_ROOT = $oldRepoRoot
                Pop-Location
            }
            return ($raw -replace "$([char]27)\[[0-9;]*m", '')
        }
    }

    It "refuses the run when the flag contradicts the env" {
        $output = Invoke-ClientSelectorRun -ExtraArgs '-client codex'

        $output | Should -Match "-client 'codex' cannot be honoured"
        $output | Should -Match "already names its client"
        # The task must not run under the client the user did not ask for.
        $output | Should -Not -Match 'Props\.mcpClient'
    }

    It "points at the environment the user probably meant" {
        $output = Invoke-ClientSelectorRun -ExtraArgs '-client codex'

        $output | Should -Match '-env codex/<environment>'
        $output | Should -Match 'jax list-envs'
    }

    It "runs when the flag agrees with the env" {
        $output = Invoke-ClientSelectorRun -ExtraArgs '-client shadow_client'

        $output | Should -Not -Match 'cannot be honoured'
        $output | Should -Match 'Props\.mcpClient'
    }

    It "runs when no client was typed" {
        $output = Invoke-ClientSelectorRun

        $output | Should -Not -Match 'cannot be honoured'
        $output | Should -Match 'Props\.mcpClient'
    }
}
