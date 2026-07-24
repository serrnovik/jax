$corePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $corePath -Force

InModuleScope 'Jax.Core' {
    Describe "Library Fallback Selection" {
        BeforeAll {
             # No mock resolver needed if core logic is correct
        }

        Context "When -only is used and item is NOT in the default scenario" {
            It "Should find and run the item from ScenarioLibrary" {
                # Mock Context
                $mockLibrary = @{
                    'my-lib-task' = @{
                        runner = 'pwshscript'
                        script = 'scripts/lib-script.ps1'
                    }
                }
                $context = @{
                    ScenarioLibrary = $mockLibrary
                }

                # Scenario entities (does NOT contain my-lib-task)
                $scenarioEntities = @(
                    @{ Key = 'build' ; Runner = 'psake' ; Task = 'Build' }
                )

                # Call Resolve-JaxRunPlan with -Only 'my-lib-task'
                $plan = @(Resolve-JaxRunPlan -ScenarioEntities $scenarioEntities -Only 'my-lib-task' -Context $context)

               # $plan | ForEach-Object { Write-Host "Plan Item: $($_.Key) - $($_.Task)" }
                $plan.Count | Should -Be 1
                $plan[0].Key | Should -Be 'my-lib-task'
            }
        }

        Context "When -only is used and item IS in the default scenario" {
            It "Should run the item from the scenario (precedence)" {
                $mockLibrary = @{
                    'build' = @{ runner = 'pwshscript'; script = 'lib-build.ps1' }
                }
                $context = @{
                    ScenarioLibrary = $mockLibrary
                }

                $scenarioEntities = @(
                    @{ Key = 'build' ; Runner = 'psake' ; Tasks = @('FlowBuild') }
                )

                $plan = @(Resolve-JaxRunPlan -ScenarioEntities $scenarioEntities -Only 'build' -Context $context)

                $plan.Count | Should -Be 1
                $plan[0].Tasks | Should -Contain 'FlowBuild'
            }
        }

        Context "When -only selects a multi-step library item" {
            It "Should apply -from/-to within that library item" {
                # Multi-step library item
                $mockLibrary = @{
                    'complex-deploy' = @(
                        @{ runner = 'psake'; task = 'Step1' },
                        @{ runner = 'psake'; task = 'Step2' },
                        @{ runner = 'psake'; task = 'Step3' }
                    )
                }
                $context = @{
                    ScenarioLibrary = $mockLibrary
                    RepoRoot = "/tmp"
                }

                # Call with -Only 'complex-deploy' AND -From 'Step2'
                # Force array
                $plan = @(Resolve-JaxRunPlan -Only 'complex-deploy' -From 'Step2' -Context $context)

                $plan.Count | Should -Be 2
                $plan[0].Tasks | Should -Contain 'Step2'
                $plan[1].Tasks | Should -Contain 'Step3'
            }
        }
    }
}
