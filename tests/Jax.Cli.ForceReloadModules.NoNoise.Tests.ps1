Describe 'Jax CLI -frm/-fr module reload' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        # Run against a copy that is itself a git repo: the bob plugin prompts
        # interactively when the -C root has no .git, and that prompt hangs
        # forever under Pester (stdout is captured, stdin is still the tty).
        $script:fixtureRoot = Join-Path $TestDrive 'jax-client'
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'tests/fixtures/jax-client') -Destination $script:fixtureRoot -Recurse
        & git -C $script:fixtureRoot init --quiet
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
