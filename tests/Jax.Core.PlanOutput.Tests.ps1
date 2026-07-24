BeforeAll {
    $repo = Resolve-Path "$PSScriptRoot/.."
    Import-Module "$repo/core/Jax.Core.psm1" -Force
    $sourceFixture = Join-Path $repo 'tests/fixtures/jax-client'
    $fixtureRoot = Join-Path $TestDrive 'jax-client'
    Copy-Item -LiteralPath $sourceFixture -Destination $fixtureRoot -Recurse
    & git -C $fixtureRoot init --quiet
}

Describe "Enhanced Plan Output" {
    Context "Quick Plan (default)" {
        It "Shows args count for entities with args" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_step_1 -noCache 2>&1 | Out-String
            $testOutput | Should -Match "Args: 1 parameter set"
        }

        It "Shows scenario runner for sceny/scenario wrapper entities" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_batch -noCache 2>&1 | Out-String
            $testOutput | Should -Match "Runner: scenario"
        }
    }

    Context "Detailed Plan (-Detailed)" {
        It "Shows [DETAILED] indicator in header" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_batch -noCache -Detailed 2>&1 | Out-String
            $testOutput | Should -Match "\[DETAILED\]"
        }

        It "Shows expanded parameters with names and values" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_batch -noCache -Detailed 2>&1 | Out-String
            $testOutput | Should -Match "Parameters \(1 set\):"
            $testOutput | Should -Match "stepName:\s+step1"
            $testOutput | Should -Match "myData:\s+root-value-passed-down"
        }

        It "Slices scenario children when -from/-to are specified (detailed view)" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_batch -from test_step_1 -to test_step_2 -noCache -Detailed 2>&1 | Out-String
            $testOutput | Should -Match "2 entities"
            $testOutput | Should -Match "test_step_1"
            $testOutput | Should -Match "test_step_2"
            $testOutput | Should -Not -Match "test_step_3"
        }

        It "CLI DynamicParam overrides scenario args (detailed view)" {
            $testOutput = & pwsh -NoProfile -File "$repo/jax.ps1" -C $fixtureRoot plan -env jax_client/dev -only test_batch -from test_step_1 -to test_step_2 -noCache -Detailed -myData 'From USER param' 2>&1 | Out-String
            $testOutput | Should -Match "2 entities"
            $testOutput | Should -Match "myData:\s+From USER param"
        }
    }
}
