# Integration: -sc (shortcut) must not update core env in .jax/state.yml
$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'jax.ps1 -sc does not persist env to state' {
    It 'leaves core.env in state.yml unchanged after plan via shortcut' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $scriptPath = Join-Path $repoRoot 'jax.ps1'
        $sourceFixture = Join-Path $repoRoot 'tests/fixtures/jax-client'
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("jax-sc-state-{0}" -f [guid]::NewGuid().ToString('n'))
        Copy-Item -Path $sourceFixture -Destination $tempRoot -Recurse
        & git -C $tempRoot init --quiet

        $jaxDir = Join-Path $tempRoot '.jax'
        New-Item -ItemType Directory -Path $jaxDir -Force | Out-Null
        $statePath = Join-Path $jaxDir 'state.yml'
        @"
core:
  env: jax_client/dev
  client: ''
  scenario: default
"@ | Set-Content -LiteralPath $statePath -Encoding utf8

        $configPath = Join-Path $tempRoot 'jax.config.yml'
        $configTail = @'

  shortcuts:
    sc_no_state: ['-e', 'jax_client/prod', '-plan', '-only', 'prod_script']
'@
        Add-Content -LiteralPath $configPath -Value $configTail -Encoding utf8

        try {
            $out = & pwsh -NoProfile -Command @"
`$ErrorActionPreference = 'Stop'
`$env:JAX_REPO_ROOT = '$tempRoot'
& '$scriptPath' -sc sc_no_state 2>&1 | Out-String
"@
            $out | Should -Not -Match 'Failed to expand shortcut|Shortcut ''sc_no_state'' not found'

            $raw = Get-Content -LiteralPath $statePath -Raw
            $raw | Should -Match 'jax_client/dev'
            $raw | Should -Not -Match 'jax_client/prod'
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
