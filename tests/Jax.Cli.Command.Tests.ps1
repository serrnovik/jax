$coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $coreModulePath -Force

Describe 'Resolve-JaxCliCommand' {
    It 'selects command when flags precede it' {
        $result = Resolve-JaxCliCommand -Command '-env' -CommandArgs @('sample-app/build', 'run', 'info')
        $result.Command | Should -Be 'run'
        $result.Args | Should -Be @('-env', 'sample-app/build', 'info')
    }

    It 'preserves command when already first' {
        $result = Resolve-JaxCliCommand -Command 'run' -CommandArgs @('-env', 'sample-app/build', 'info')
        $result.Command | Should -Be 'run'
        $result.Args | Should -Be @('-env', 'sample-app/build', 'info')
    }

    It 'resolves the r alias to run' {
        $result = Resolve-JaxCliCommand -Command 'r' -CommandArgs @('-env', 'sample-app/build', 'info')
        $result.Command | Should -Be 'run'
        $result.Args | Should -Be @('-env', 'sample-app/build', 'info')
    }

    It 'resolves the invoke alias to run' {
        $result = Resolve-JaxCliCommand -Command 'invoke' -CommandArgs @('-env', 'sample-app/build', 'info')
        $result.Command | Should -Be 'run'
        $result.Args | Should -Be @('-env', 'sample-app/build', 'info')
    }

    It 'treats skill as a known command' {
        $result = Resolve-JaxCliCommand -Command 'skill' -CommandArgs @()
        $result.Command | Should -Be 'skill'
        $result.Args | Should -Be @()
    }

    It 'treats info as a known command' {
        $result = Resolve-JaxCliCommand -Command 'info' -CommandArgs @()
        $result.Command | Should -Be 'info'
        $result.Args | Should -Be @()
    }

    It 'treats invoke as a known command (does not wrap it as an implicit task)' {
        $result = Resolve-JaxCliCommand -Command '-env' -CommandArgs @('sample-app/build', 'invoke', 'Build')
        $result.Command | Should -Be 'run'
        # 'invoke' should be consumed as the command, not prepended as a task arg
        $result.Args | Should -Be @('-env', 'sample-app/build', 'Build')
    }

    Context 'positional env/task shorthand' {
        It 'rewrites positional env+task into -env and -only' {
            $result = Resolve-JaxCliCommand -Command 'operations/wtw' -CommandArgs @('PublishWtw')
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('-env', 'operations/wtw', '-only', 'PublishWtw')
        }

        It 'rewrites env-only positional shorthand into -env' {
            $result = Resolve-JaxCliCommand -Command 'operations/wtw' -CommandArgs @()
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('-env', 'operations/wtw')
        }

        It 'joins multiple positional tasks with commas' {
            $result = Resolve-JaxCliCommand -Command 'operations/wtw' -CommandArgs @('TaskA', 'TaskB')
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('-env', 'operations/wtw', '-only', 'TaskA,TaskB')
        }

        It 'preserves flags interleaved with positional tasks' {
            $result = Resolve-JaxCliCommand -Command 'operations/wtw' -CommandArgs @('PublishWtw', '-nb')
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('-env', 'operations/wtw', '-only', 'PublishWtw', '-nb')
        }

        It 'works when explicit run command is provided' {
            $result = Resolve-JaxCliCommand -Command 'run' -CommandArgs @('operations/wtw', 'PublishWtw')
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('-env', 'operations/wtw', '-only', 'PublishWtw')
        }

        It 'does not rewrite plain task shorthand (no slash)' {
            $result = Resolve-JaxCliCommand -Command 'PublishWtw' -CommandArgs @()
            $result.Command | Should -Be 'run'
            $result.Args | Should -Be @('PublishWtw')
        }

        It 'does not rewrite when first arg is a known command' {
            $result = Resolve-JaxCliCommand -Command 'list-envs' -CommandArgs @('operations/wtw')
            $result.Command | Should -Be 'list-envs'
            $result.Args | Should -Be @('operations/wtw')
        }
    }
}
