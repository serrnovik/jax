BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
}

Describe 'Discovery helpers' {
    It 'returns scenario names from flow config' {
        $flow = @{
            suite = @{
                scenarios = @{
                    default = @{
                        build = @{
                            task = 'Build'
                        }
                    }
                    release = @{
                        deploy = @{
                            task = 'Deploy'
                        }
                    }
                }
            }
        }

        $names = Get-JaxScenarioNames -FlowConfig $flow
        $names | Should -Be @('default', 'release')
    }

    It 'returns scenario entity keys for selected scenario' {
        $flow = @{
            suite = @{
                scenarios = @{
                    default = @{
                        build = @{
                            runner = 'psake'
                            task   = 'Build'
                        }
                        deploy = @{
                            runner = 'psake'
                            task   = 'Deploy'
                        }
                    }
                }
            }
        }

        $keys = Get-JaxScenarioEntityKeys -FlowConfig $flow -Scenario 'default'
        $keys | Should -Be @('build', 'deploy')
    }
}
