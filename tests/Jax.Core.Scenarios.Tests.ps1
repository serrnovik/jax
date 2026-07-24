$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxScenarioRunEntities' {
    It 'preserves scenario item order' {
        $flow = @{
            suite = @{
                scenarios = [ordered]@{
                    default = [ordered]@{
                        first  = @{ runner = 'psake'; tasks = @('Task1') }
                        second = @{ runner = 'script'; script = 'do.ps1' }
                    }
                }
            }
        }

        $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flow -Scenario 'default')
        $entities[0].Key | Should -Be 'first'
        $entities[1].Key | Should -Be 'second'
    }

    It 'defaults to the default scenario when no scenario is provided' {
        $flow = @{
            suite = @{
                scenarios = [ordered]@{
                    default = [ordered]@{
                        only = 'Build'
                    }
                    other = [ordered]@{
                        other = 'OtherTask'
                    }
                }
            }
        }

        $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flow)
        $entities[0].Runner | Should -Be 'psake'
        $entities[0].Tasks | Should -Be @('Build')
    }

    It 'maps string values to script or psake' {
        $flow = @{
            suite = @{
                scenarios = [ordered]@{
                    default = [ordered]@{
                        task = 'Build'
                        script = 'run.ps1'
                    }
                }
            }
        }

        $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flow -Scenario 'default')
        $entities[0].Runner | Should -Be 'psake'
        $entities[0].Tasks | Should -Be @('Build')
        $entities[1].Runner | Should -Be 'pwshscript'
        $entities[1].Script | Should -Be 'run.ps1'
    }

    It 'uses string list values as stable entity keys' {
        $flow = @{
            suite = @{
                scenarios = [ordered]@{
                    default = @('EnvInfo')
                }
            }
        }

        $scenarioEntities = @(Get-JaxScenarioRunEntities -FlowConfig $flow -Scenario 'default')
        $scenarioEntities.Count | Should -Be 1
        $scenarioEntities[0].Key | Should -Be 'EnvInfo'
        $scenarioEntities[0].Tasks | Should -Be @('EnvInfo')

        $discoveredEntities = @(
            @{ Key = 'EnvInfo'; Runner = 'psake'; Tasks = @('EnvInfo') }
        )
        $plan = @(Resolve-JaxRunPlan -ScenarioEntities $scenarioEntities -IndividualEntities $discoveredEntities -Only 'EnvInfo')
        $plan.Count | Should -Be 1
        $plan[0].Key | Should -Be 'EnvInfo'
    }

    It 'supports custom scenario resolvers' {
        InModuleScope Jax.Core {
            $original = $script:JaxScenarioResolvers
            $script:JaxScenarioResolvers = @()

            Register-JaxScenarioResolver -Name 'custom' -Order -100 -Handler {
                param($Key, $Value, $ScenarioName, $ProvenancePath)
                if ($Value -ne 'Custom') {
                    return $null
                }
                $entity = New-JaxRunEntity -Key $Key -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath
                $entity.Runner = 'pwshscript'
                $entity.Script = 'custom.ps1'
                return $entity
            }

            $flow = @{
                suite = @{
                    scenarios = [ordered]@{
                        default = [ordered]@{
                            only = 'Custom'
                        }
                    }
                }
            }

            $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flow -Scenario 'default')
            $entities[0].Runner | Should -Be 'pwshscript'
            $entities[0].Script | Should -Be 'custom.ps1'

            $script:JaxScenarioResolvers = $original
        }
    }
}
