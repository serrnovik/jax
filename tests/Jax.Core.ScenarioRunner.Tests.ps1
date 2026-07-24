BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    Import-Module "$repoRoot/core/Jax.Core.psm1" -Force
}

Describe 'Jax Scenario Runner Integration' {
    BeforeAll {
        $script:testRoot = "$TestDrive/jax-scenario-runner-test"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:testRoot/jax" -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:testRoot/env/test/flows" -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Directory -Path "$script:testRoot/env/test/scenarios-lib" -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Directory -Path "$script:testRoot/scripts" -Force | Out-Null

        # Create test psakefile
        $psakeContent = @'
task Test1 {
    Write-Host "PSAKE_TEST1_EXECUTED"
    Write-Host "stepName: $($properties.stepName)"
    Write-Host "myData: $($properties.myData)"
}

task Test2 {
    Write-Host "PSAKE_TEST2_EXECUTED"
    Write-Host "stepName: $($properties.stepName)"
    Write-Host "myData: $($properties.myData)"
}
'@
        Set-Content -Path "$script:testRoot/psakefile.ps1" -Value $psakeContent

        # Create test pwsh script
        $scriptContent = @'
param($stepName, $myData)
Write-Host "PWSH_SCRIPT_EXECUTED"
Write-Host "stepName: $stepName"
Write-Host "myData: $myData"
'@
        Set-Content -Path "$script:testRoot/scripts/test-script.ps1" -Value $scriptContent

        # Create scenarios-lib test file
        $scenariosLibContent = @'
test_batch:
  runner: scenario
  args:
    myData: 'root-value'
  steps:
    - step1
    - step2
    - step3

test_batch_sceny:
  runner: sceny
  args:
    myData: 'alias-test'
  steps:
    - step1

step1:
  runner: psake
  script: 'psakefile.ps1'
  tasks:
    - Test1
  args:
    stepName: 'step1'

step2:
  runner: pwsh
  script: 'scripts/test-script.ps1'
  args:
    stepName: 'step2'

step3:
  runner: psake
  script: 'psakefile.ps1'
  tasks:
    - Test2
  args:
    stepName: 'step3'
    myData: 'overridden-value'

edge_case_psake_with_script_only:
  runner: psake
  script: 'psakefile.ps1'
  tasks:
    - Test1
'@
        Set-Content -Path "$script:testRoot/env/test/scenarios-lib/test.yml" -Value $scenariosLibContent

        # Initialize git repo
        Push-Location $script:testRoot
        git init 2>&1 | Out-Null
        git config user.email "test@example.com" 2>&1 | Out-Null
        git config user.name "Test User" 2>&1 | Out-Null
        Pop-Location

        $env:JAX_REPO_ROOT = $script:testRoot
    }

    AfterAll {
        $env:JAX_REPO_ROOT = $null
        if (Test-Path $script:testRoot) {
            Remove-Item -Recurse -Force $script:testRoot -ErrorAction SilentlyContinue
        }
    }

    Context 'Scenario Runner with Mixed Steps' {
        It 'resolves scenario runner correctly' {
            InModuleScope Jax.Core -ArgumentList $script:testRoot {
                param($testRoot)
                $config = Get-JaxConfig -RepoRoot $testRoot
                $libraryEntities = Get-JaxLibraryEntities -RepoRoot $testRoot -Config $config -EnvDir "$testRoot/env/test"

                $testBatch = $libraryEntities | Where-Object { $_.Key -eq 'test_batch' }
                $testBatch | Should -Not -BeNullOrEmpty
                $testBatch.Runner | Should -Be 'scenario'
                $testBatch.Entities | Should -Not -BeNullOrEmpty
                $testBatch.Entities.Count | Should -Be 3
            }
        }

        It 'resolves sceny alias to scenario runner' {
            InModuleScope Jax.Core -ArgumentList $script:testRoot {
                param($testRoot)
                $config = Get-JaxConfig -RepoRoot $testRoot
                $libraryEntities = Get-JaxLibraryEntities -RepoRoot $testRoot -Config $config -EnvDir "$testRoot/env/test"

                $testBatchSceny = $libraryEntities | Where-Object { $_.Key -eq 'test_batch_sceny' }
                $testBatchSceny | Should -Not -BeNullOrEmpty
                $testBatchSceny.Runner | Should -Be 'scenario'
            }
        }

        It 'resolves nested step entities correctly' {
            InModuleScope Jax.Core -ArgumentList $script:testRoot {
                param($testRoot)
                $config = Get-JaxConfig -RepoRoot $testRoot
                $libraryEntities = Get-JaxLibraryEntities -RepoRoot $testRoot -Config $config -EnvDir "$testRoot/env/test"

                $step1 = $libraryEntities | Where-Object { $_.Key -eq 'step1' }
                $step1 | Should -Not -BeNullOrEmpty
                $step1.Runner | Should -Be 'psake'
                $step1.PsakeFile | Should -Be 'psakefile.ps1'

                $step2 = $libraryEntities | Where-Object { $_.Key -eq 'step2' }
                $step2 | Should -Not -BeNullOrEmpty
                $step2.Runner | Should -Be 'pwshscript'

                $step3 = $libraryEntities | Where-Object { $_.Key -eq 'step3' }
                $step3 | Should -Not -BeNullOrEmpty
                $step3.Runner | Should -Be 'psake'
            }
        }
    }

    Context 'Edge Cases' {
        It 'handles psake runner with script instead of psakeFile' {
            InModuleScope Jax.Core -ArgumentList $script:testRoot {
                param($testRoot)
                $config = Get-JaxConfig -RepoRoot $testRoot
                $libraryEntities = Get-JaxLibraryEntities -RepoRoot $testRoot -Config $config -EnvDir "$testRoot/env/test"

                $edgeCase = $libraryEntities | Where-Object { $_.Key -eq 'edge_case_psake_with_script_only' }
                $edgeCase | Should -Not -BeNullOrEmpty
                $edgeCase.Runner | Should -Be 'psake'
                # The resolver should normalize script to PsakeFile
                $edgeCase.PsakeFile | Should -Be 'psakefile.ps1'
            }
        }
    }

    Context 'NoCache Flag' {
        It 'accepts NoCache parameter in Get-JaxLibraryEntities' {
            InModuleScope Jax.Core -ArgumentList $script:testRoot {
                param($testRoot)
                $config = Get-JaxConfig -RepoRoot $testRoot
                { Get-JaxLibraryEntities -RepoRoot $testRoot -Config $config -EnvDir "$testRoot/env/test" -NoCache } | Should -Not -Throw
            }
        }

        It 'accepts NoCache parameter in Get-JaxDiscoveredRunEntities' {
            $config = Get-JaxConfig -RepoRoot $script:testRoot
            { Get-JaxDiscoveredRunEntities -RepoRoot $script:testRoot -Config $config -EnvDir "$script:testRoot/env/test" -NoCache } | Should -Not -Throw
        }
    }

    Context 'Runner Name Resolution' {
        It 'resolves sceny to scenario' {
            InModuleScope Jax.Core {
                $result = Resolve-JaxRunnerName -Name 'sceny'
                $result | Should -Be 'scenario'
            }
        }

        It 'resolves scenario to scenario' {
            InModuleScope Jax.Core {
                $result = Resolve-JaxRunnerName -Name 'scenario'
                $result | Should -Be 'scenario'
            }
        }

        It 'resolves bossscenario to scenario' {
            InModuleScope Jax.Core {
                $result = Resolve-JaxRunnerName -Name 'bossscenario'
                $result | Should -Be 'scenario'
            }
        }
    }
}
