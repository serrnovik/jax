BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
}

Describe 'Help registry' {
    It 'registers and returns help entries' {
        InModuleScope Jax.Core {
            $script:JaxHelpRegistry = @()
        }

        Register-JaxHelpEntry -Name 'demo' -Summary 'Demo command' -Usage @('jax demo')
        $entries = Get-JaxHelpEntries

        $entries.Count | Should -Be 1
        $entries[0].Name | Should -Be 'demo'
        $entries[0].Summary | Should -Be 'Demo command'
    }
}
