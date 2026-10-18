BeforeAll {
    $script:jaxRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:scriptPath = Join-Path $script:jaxRoot 'jax.ps1'
    $script:fixtureRoot = Join-Path $script:jaxRoot 'tests/fixtures/jax-client'
    Import-Module (Join-Path $script:jaxRoot 'core/Jax.Core.psm1') -Force
}

Describe 'Test-JaxTaskPatternMatch' {
    It 'matches a case-insensitive substring' {
        InModuleScope Jax.Core {
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'terraform' | Should -BeTrue
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'TERRA' | Should -BeTrue
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'helm' | Should -BeFalse
        }
    }

    It 'treats * and ? as wildcards anywhere in the name' {
        InModuleScope Jax.Core {
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'ensure*install' | Should -BeTrue
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'terra?orm' | Should -BeTrue
            Test-JaxTaskPatternMatch -Name 'EnsureTerraformInstalled' -Pattern 'install*ensure' | Should -BeFalse
        }
    }

    It 'treats brackets literally' {
        InModuleScope Jax.Core {
            Test-JaxTaskPatternMatch -Name 'Build' -Pattern '[B]uild' | Should -BeFalse
        }
    }
}

Describe 'Find-JaxTasks' {
    It 'finds a task in every environment that has it, and filters environments' {
        $config = Get-JaxConfig -RepoRoot $script:fixtureRoot
        $all = @(Find-JaxTasks -RepoRoot $script:fixtureRoot -Config $config -Pattern 'devonly' -NoCache 6>$null)
        @($all | ForEach-Object Task | Sort-Object -Unique) | Should -Be @('DevOnly')
        @($all.Env) | Should -Contain 'jax_client/dev'

        $common = @(Find-JaxTasks -RepoRoot $script:fixtureRoot -Config $config -Pattern 'common*' -EnvPattern 'prod' -NoCache 6>$null)
        $common.Count | Should -BeGreaterThan 0
        @($common.Env | Sort-Object -Unique) | Should -Be @('jax_client/prod')
    }
}

Describe 'jax.ps1 search' {
    It 'prints a runnable command per match' {
        Push-Location $script:jaxRoot
        try {
            $output = & $script:scriptPath -C $script:fixtureRoot 'search' 'devonly' 6>&1 | ForEach-Object { "$_" }
        } finally {
            Pop-Location
        }
        ($output -join "`n") | Should -Match 'jx -e jax_client/dev run -o DevOnly'
    }

    It 'prints usage without a pattern' {
        Push-Location $script:jaxRoot
        try {
            $output = & $script:scriptPath -C $script:fixtureRoot 'search' 6>&1 | ForEach-Object { "$_" }
        } finally {
            Pop-Location
        }
        ($output -join "`n") | Should -Match 'Usage: jax search'
    }
}
