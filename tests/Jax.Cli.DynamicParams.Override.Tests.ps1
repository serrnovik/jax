Describe "Dynamic params override semantics" {
    It "CLI dynamic param overrides psake + script args at runtime (and extra params are ignored)" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $scriptPath = Join-Path $repoRoot 'jax.ps1'
        $sourceFixture = Join-Path $repoRoot 'tests/fixtures/jax-client'
        $fixtureRoot = Join-Path $TestDrive 'jax-client'
        Copy-Item -LiteralPath $sourceFixture -Destination $fixtureRoot -Recurse
        & git -C $fixtureRoot init --quiet

        Push-Location $repoRoot
        $oldRepoRoot = $env:JAX_REPO_ROOT
        try {
            # Capture all streams (Write-Host in runners/tasks uses information stream).
            # NOTE: do NOT pass -frm here. It triggers module reload which is useful for dev,
            # but it makes the Pester session non-deterministic (modules get replaced mid-run).
            $output = & $scriptPath -C $fixtureRoot run -env jax_client/dev -only test_batch -from test_step_1 -to test_step_2 -noCache -myData "From USER param" -unusedParam "ignored" *>&1 | Out-String
        } finally {
            $env:JAX_REPO_ROOT = $oldRepoRoot
            Pop-Location
        }

        $output | Should -Match "Props\.myData:"
        $output | Should -Match "From USER param"
        $output | Should -Match "Param myData:"
    }
}
