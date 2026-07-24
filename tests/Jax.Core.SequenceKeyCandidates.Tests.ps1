$coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $coreModulePath -Force

Describe 'Get-JaxSequenceKeyCandidates' {
    BeforeAll {
        $script:fixtureRoot = Join-Path $PSScriptRoot 'fixtures/jax-client'
        $script:config = Get-JaxConfig -RepoRoot $script:fixtureRoot -SkipUserConfig
    }

    It 'returns build/scenario/library keys (sequence-only candidates) for env/flow selection' {
        $candidates = Get-JaxSequenceKeyCandidates -RepoRoot $script:fixtureRoot -Config $script:config -EnvWithOptionalFlow 'jax_client/dev/build' -Scenario 'default'
        $names = @($candidates | Select-Object -ExpandProperty Name | Sort-Object)

        $names | Should -Contain 'CommonBuild'
        $names | Should -Contain 'DevOnly'
        $names | Should -Contain 'lib_common'
        $names | Should -Contain 'lib_override'
        $names | Should -Contain 'deploy'
        $names | Should -Contain 'dev_script'

        ($candidates | Where-Object { $_.Name -eq 'lib_override' } | Select-Object -First 1).Kind | Should -Be 'library'
        ($candidates | Where-Object { $_.Name -eq 'deploy' } | Select-Object -First 1).Kind | Should -Be 'scenario'
    }
}
