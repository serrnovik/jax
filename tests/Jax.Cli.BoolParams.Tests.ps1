Describe "Boolean task parameters bind as flags" {
    BeforeAll {
        $script:JaxRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:JaxScript = Join-Path $script:JaxRoot 'jax.ps1'
        $script:FixtureRoot = Join-Path $TestDrive 'jax-client'
        Copy-Item -LiteralPath (Join-Path $script:JaxRoot 'tests/fixtures/jax-client') -Destination $script:FixtureRoot -Recurse
        & git -C $script:FixtureRoot init --quiet

        # Invoke through the parser (not splatting) so the test exercises real command-line
        # token binding, which is the whole point of `-flag` vs `-flag:$true`.
        function Invoke-BoolFlagRun {
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
            # Strip ANSI so the highlighted task/param names do not break matching.
            return ($raw -replace "$([char]27)\[[0-9;]*m", '')
        }
    }

    It "defaults to the psake property value when the flag is absent" {
        Invoke-BoolFlagRun | Should -Match 'Props\.boolFlag: False'
    }

    It "accepts the bare flag, with no value" {
        Invoke-BoolFlagRun -ExtraArgs '-boolFlag' | Should -Match 'Props\.boolFlag: True'
    }

    It "accepts the colon form in both directions" {
        Invoke-BoolFlagRun -ExtraArgs '-boolFlag:$true' | Should -Match 'Props\.boolFlag: True'
        Invoke-BoolFlagRun -ExtraArgs '-boolFlag:$false' | Should -Match 'Props\.boolFlag: False'
    }

    It "still honors the legacy space-separated value" {
        Invoke-BoolFlagRun -ExtraArgs '-boolFlag $true' | Should -Match 'Props\.boolFlag: True'
        Invoke-BoolFlagRun -ExtraArgs '-boolFlag $false' | Should -Match 'Props\.boolFlag: False'
    }
}
