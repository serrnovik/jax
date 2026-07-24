$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force
Import-Module (Join-Path $PSScriptRoot '../plugins/cleaning/Jax.Plugin.Cleaning.psm1') -Force

Describe 'Jax cleaning plugin' {
    It 'runs only when enabled' {
        InModuleScope Jax.Core {
            $script:JaxPluginsLoaded = $true
            $script:JaxPluginRegistry = @()
            Register-JaxCleaningPlugin

            $context = @{
                Config = @{
                    plugins = @{
                        enabled  = @('cleaning')
                        disabled = @()
                        config   = @{
                            cleaning = @{
                                enabled = $true
                            }
                        }
                    }
                }
            }

            Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $context -Data @{ }

            $context['CleaningInvoked'] | Should -Be $true
        }
    }

    It 'skips when not enabled' {
        InModuleScope Jax.Core {
            $script:JaxPluginsLoaded = $true
            $script:JaxPluginRegistry = @()
            Register-JaxCleaningPlugin

            $context = @{
                Config = @{
                    plugins = @{
                        enabled  = @()
                        disabled = @('cleaning')
                        config   = @{
                            cleaning = @{
                                enabled = $true
                            }
                        }
                    }
                }
            }

            Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $context -Data @{ }

            $context.ContainsKey('CleaningInvoked') | Should -Be $false
        }
    }
}
