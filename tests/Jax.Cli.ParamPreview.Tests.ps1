Describe "Dry-run resolves the parameters an entity would receive" {
    BeforeAll {
        $script:JaxRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:JaxScript = Join-Path $script:JaxRoot 'jax.ps1'
        $script:FixtureRoot = Join-Path $TestDrive 'jax-client'
        Copy-Item -LiteralPath (Join-Path $script:JaxRoot 'tests/fixtures/jax-client') -Destination $script:FixtureRoot -Recurse
        & git -C $script:FixtureRoot init --quiet

        function Invoke-PreviewRun {
            param([string] $ExtraArgs = '')

            $command = "& '{0}' -C '{1}' run -env jax_client/dev -only ShowBoolFlag -noCache {2} *>&1" -f
                $script:JaxScript, $script:FixtureRoot, $ExtraArgs

            Push-Location $script:JaxRoot
            $oldRepoRoot = $env:JAX_REPO_ROOT
            try {
                $raw = (Invoke-Expression $command | Out-String)
            } finally {
                $env:JAX_REPO_ROOT = $oldRepoRoot
                Pop-Location
            }
            return ($raw -replace "$([char]27)\[[0-9;]*m", '')
        }
    }

    Context "-dryRun" {
        It "reports a CLI-supplied value and marks its source" {
            Invoke-PreviewRun -ExtraArgs '-boolFlag -dryRun' | Should -Match 'boolFlag\s+bool\s+True\s+cli'
        }

        It "reports the properties{} default when nothing overrides it" {
            Invoke-PreviewRun -ExtraArgs '-dryRun' | Should -Match 'boolFlag\s+bool\s+False\s+default'
        }

        It "surfaces a CLI param the entity does not declare instead of dropping it" {
            $output = Invoke-PreviewRun -ExtraArgs '-typoParam hello -dryRun'
            $output | Should -Match 'typoParam'
            $output | Should -Match 'not declared'
        }

        It "redacts sensitive parameter names" {
            $output = Invoke-PreviewRun -ExtraArgs '-apiKey "sk-must-not-appear" -dryRun'
            $output | Should -Match '\[redacted\]'
            $output | Should -Not -Match 'sk-must-not-appear'
        }

        It "does not list Jax's own CLI flags as task parameters" {
            Invoke-PreviewRun -ExtraArgs '-boolFlag -dryRun' | Should -Not -Match 'dryRun\s.*not declared'
        }

        It "keeps properties declared after a brace in a comment or a hashtable default" {
            # The block used to be captured with a non-greedy regex that ended at
            # the first '}' in the file, so anything below a brace vanished from
            # the CLI contract without a warning.
            Invoke-PreviewRun -ExtraArgs '-dryRun' | Should -Match 'afterBraceComment\s+string\s+reached\s+default'
        }

        It "binds a CLI value to a property declared after a brace" {
            Invoke-PreviewRun -ExtraArgs '-afterBraceComment overridden -dryRun' |
                Should -Match 'afterBraceComment\s+string\s+overridden\s+cli'
        }
    }

    Context "-dryRunDeep" {
        It "attaches ResolvedParameters to the emitted JSON" {
            $output = Invoke-PreviewRun -ExtraArgs '-boolFlag:$false -dryRunDeep'
            $json = ($output -split "(?m)^(?=\[|\{)", 2)[-1]
            $parsed = $json | ConvertFrom-Json
            $row = @($parsed.ResolvedParameters) | Where-Object { $_.Name -eq 'boolFlag' }
            $row | Should -Not -BeNullOrEmpty
            [bool]$row.Value | Should -BeFalse
            $row.Source | Should -Be 'cli'
        }
    }
}
