Describe 'Jax.Plugin.Coverage' {
    BeforeAll {
        $script:jaxRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        Import-Module (Join-Path $script:jaxRoot 'core/Jax.Core.psm1') -Global -Force
        $script:coverageEnvNames = @('VITEST_COVERAGE', 'FLUTTER_COVERAGE', 'SWIFT_COVERAGE', 'PYTHON_COVERAGE', 'PESTER_COVERAGE', 'COVERAGE_DIR')
        $script:savedEnv = @{}
        foreach ($name in $script:coverageEnvNames) {
            # Invoke-Tests.ps1 runs under strict mode, where $null.Value throws for an unset variable.
            $script:savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
        }
    }

    AfterAll {
        foreach ($name in $script:coverageEnvNames) {
            if ($null -eq $script:savedEnv[$name]) {
                Remove-Item "Env:$name" -ErrorAction SilentlyContinue
            } else {
                Set-Item "Env:$name" -Value $script:savedEnv[$name]
            }
        }
    }

    It 'clears only the running entity coverage dir, leaving parallel runs intact' {
        $repoRoot = Join-Path $TestDrive 'repo'
        $otherEntityFile = Join-Path $repoRoot 'coverage/other-entity/.tmp/coverage-1.json'
        $staleFile = Join-Path $repoRoot 'coverage/code-pkg--TestPkg/coverage-final.json'
        foreach ($file in @($otherEntityFile, $staleFile)) {
            New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
            Set-Content -LiteralPath $file -Value '{}'
        }

        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $true
        }
        Import-Module (Join-Path $script:jaxRoot 'plugins/coverage/Jax.Plugin.Coverage.psm1') -Global -Force

        $context = @{
            RepoRoot = $repoRoot
            Config   = @{ plugins = @{ enabled = @('coverage'); disabled = @(); paths = @() } }
        }
        Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $context -Data @{ Resolved = @{ coverage = $true; noSavedSettings = $true } }
        Test-Path -LiteralPath $staleFile | Should -BeTrue

        Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{
            Entity = @{ Name = 'TestPkg'; SourcePath = (Join-Path $repoRoot 'code/pkg') }
        }

        $env:COVERAGE_DIR | Should -Be 'coverage/code-pkg--TestPkg'
        Test-Path -LiteralPath $staleFile | Should -BeFalse
        Test-Path -LiteralPath $otherEntityFile | Should -BeTrue
    }
}
