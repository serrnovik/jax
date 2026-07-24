Describe 'Jax CLI -frm/-fr module reload' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:fixtureRoot = Join-Path $script:repoRoot 'tests/fixtures/jax-client'
    }

    It 'does not print missing-core-function errors during plugin registration' {
        $scriptPath = Join-Path $script:repoRoot 'jax.ps1'
        $output = & pwsh -NoProfile -File $scriptPath plan `
            -C $script:fixtureRoot `
            -env jax_client/dev `
            -only test_batch `
            -from test_step_1 `
            -to test_step_2 `
            -noCache `
            -frm `
            -Detailed `
            -myData "111" 2>&1 | Out-String

        $output | Should -Not -Match "The term 'Register-JaxPlugin' is not recognized"
        $output | Should -Not -Match "The term 'Register-JaxScenarioResolver' is not recognized"
        $output | Should -Not -Match "Register-JaxPlugin:"
        $output | Should -Not -Match "Register-JaxScenarioResolver:"
    }
}
