Describe 'jax.ps1 list-envs' {
    It 'prints environment names and flow configs' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $scriptPath = (Resolve-Path (Join-Path $repoRoot 'jax.ps1')).Path
        $fixtureRoot = Join-Path $repoRoot 'tests/fixtures/jax-client'

        Push-Location $repoRoot
        try {
            $output = & $scriptPath -C $fixtureRoot 'list-envs' 6>&1 | ForEach-Object { "$_" }
        } finally {
            Pop-Location
        }

        @($output).Count | Should -BeGreaterThan 0
        ($output -join "`n") | Should -Match 'jax_client/dev \[build\]'
        ($output -join "`n") | Should -Not -Match '^\s*\[none\]$'
    }
}
