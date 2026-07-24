Describe "Jax CLI vault toggle" {
    It "Honors -novault (non-interactive)" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $scriptPath = Join-Path $repoRoot 'jax.ps1'
        $fixtureRoot = Join-Path $repoRoot 'tests/fixtures/jax-client'

        Push-Location $repoRoot
        try {
            # Run in a separate pwsh process so env vars (e.g. JAX_NO_CONFIG_SECRETS) don't leak into the test host.
            # Use -noSavedSettings to avoid mutating repo state during tests.
            $output = & pwsh -NoProfile -File $scriptPath -C $fixtureRoot info -env jax_client/dev -noCache -noSavedSettings -novault 2>&1 | Out-String
        } finally {
            Pop-Location
        }

        # Output contains ANSI hyperlinks / escape sequences; strip them before assertions.
        $clean = $output
        $clean = $clean -replace "\x1b\\][^\x07]*\x07", ''            # OSC (including hyperlinks)
        $clean = $clean -replace "\x1b\\[[0-9;]*[A-Za-z]", ''         # CSI
        $clean | Should -Not -Match "MetadataError"
        $clean | Should -Not -Match "conflicts with the parameter alias"
        # Be robust to formatting/emoji/box characters around the header.
        $normalized = $clean -replace "[^A-Za-z:\\s]", ''
        ($normalized -like '*Vault:*disabled*') | Should -BeTrue
    }
}
