$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Jax CLI saved state does not leak stale from/to' {
    It 'Clears saved -to when user explicitly passes -from (without -to)' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $sourceFixture = Join-Path $repoRoot 'tests/fixtures/jax-client'
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('jax-state-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $sourceFixture -Destination $fixtureRoot -Recurse
        & git -C $fixtureRoot init --quiet
        $statePath = Join-Path $fixtureRoot '.jax/state.yml'
        $stateDir = Split-Path -Path $statePath -Parent

        $hadExisting = Test-Path -Path $statePath -PathType Leaf
        $existing = $null
        if ($hadExisting) {
            $existing = Get-Content -LiteralPath $statePath -Raw
        }

        if (-not (Test-Path -Path $stateDir -PathType Container)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }

        try {
            # Seed a stale "to" into saved state.
            # NOTE: current behavior intentionally strips from/to/only when reading/writing state.
            # This test ensures a stale 'to' does not truncate a plan when the user provides -from only.
            @"
core:
  env: jax_client/dev
  to: stale_to_value
"@ | Set-Content -LiteralPath $statePath -Encoding UTF8

            $scriptPath = Join-Path $repoRoot 'jax.ps1'
            $output = & pwsh -NoProfile -File $scriptPath -C $fixtureRoot plan -env jax_client/dev -from CommonBuild -noCache 2>&1 | Out-String
            $output | Should -Not -Match 'stale_to_value'
            # Also verify the end of the chain is present (regression guard against stale slicing).
            $output | Should -Match 'dev_script'
        } finally {
            if ($hadExisting) {
                $existing | Set-Content -LiteralPath $statePath -Encoding UTF8
            } else {
                Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
