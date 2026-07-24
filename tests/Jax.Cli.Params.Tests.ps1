BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
}

Describe 'Resolve-JaxCliArgs' {
    It 'parses core flags and values' {
        $args = @(
            '-env', 'acme/dev',
            '-client', 'acme',
            '-scenario', 'default',
            '-from', 'build',
            '-to', 'deploy',
            '-only', 'test',
            '-noBuild',
            '-buildChainOnly',
            '-dryRun',
            '-plan',
            '-dryRunDeep',
            '-noCache',
            '-dv',
            '-forceReloadModules',
            '-clearOutput',
            '-beep'
        )
        $result = Resolve-JaxCliArgs -Args $args
        $values = $result.Values

        $values.env | Should -Be 'acme/dev'
        $values.client | Should -Be 'acme'
        $values.scenario | Should -Be 'default'
        $values.from | Should -Be 'build'
        $values.to | Should -Be 'deploy'
        $values.only | Should -Be 'test'
        $values.noBuild | Should -Be $true
        $values.buildChainOnly | Should -Be $true
        $values.dryRun | Should -Be $true
        $values.plan | Should -Be $true
        $values.dryRunDeep | Should -Be $true
        $values.noCache | Should -Be $true
        $values.dv | Should -Be $true
        $values.forceReloadModules | Should -Be $true
        $values.clearOutput | Should -Be $true
        $values.beep | Should -Be $true
    }

    It 'respects aliases and equals syntax' {
        $args = @(
            '-e=team/dev',
            '-f', 'build',
            '-t', 'deploy',
            '-s', 'default',
            '-o', 'test',
            '-nb',
            '-bo',
            '-co',
            '-be',
            '-forceReloadModules',
            '-dryRunShort'
        )
        $result = Resolve-JaxCliArgs -Args $args
        $values = $result.Values

        $values.env | Should -Be 'team/dev'
        $values.from | Should -Be 'build'
        $values.to | Should -Be 'deploy'
        $values.scenario | Should -Be 'default'
        $values.only | Should -Be 'test'
        $values.noBuild | Should -Be $true
        $values.buildChainOnly | Should -Be $true
        $values.clearOutput | Should -Be $true
        $values.beep | Should -Be $true
        $values.forceReloadModules | Should -Be $true
        $values.plan | Should -Be $true
    }

    It 'normalizes noSavedSettings aliases to the canonical name' {
        foreach ($flag in @('-noSave', '-nss', '-noSavedSettings')) {
            $result = Resolve-JaxCliArgs -Args @($flag)
            $result.Values.noSavedSettings | Should -Be $true -Because "flag $flag should set noSavedSettings"
        }
    }

    It 'tracks unknown arguments' {
        $result = Resolve-JaxCliArgs -Args @('-unknown', 'value', 'positional')
        $result.Unknown | Should -Be @('-unknown', 'value')
        $result.Remaining | Should -Be @('positional')
    }
}
