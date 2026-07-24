$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Jax plugin hooks' {
    It 'invokes enabled plugin hooks' {
        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $true

            Register-JaxPlugin -Name 'alpha' -Hooks @{
                BeforeRunEntity = { param($hook) $hook.Context['hits'] += 'alpha' }
            }
            Register-JaxPlugin -Name 'beta' -Hooks @{
                BeforeRunEntity = { param($hook) $hook.Context['hits'] += 'beta' }
            }

            $context = @{
                hits   = @()
                Config = @{
                    plugins = @{
                        enabled  = @('alpha', 'beta')
                        disabled = @()
                        paths    = @()
                    }
                }
            }

            Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{ }

            $context.hits | Should -Be @('alpha', 'beta')
        }
    }

    It 'skips disabled plugins' {
        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $true

            Register-JaxPlugin -Name 'alpha' -Hooks @{
                BeforeRunEntity = { param($hook) $hook.Context['hits'] += 'alpha' }
            }
            Register-JaxPlugin -Name 'beta' -Hooks @{
                BeforeRunEntity = { param($hook) $hook.Context['hits'] += 'beta' }
            }

            $context = @{
                hits   = @()
                Config = @{
                    plugins = @{
                        enabled  = @('alpha', 'beta')
                        disabled = @('beta')
                        paths    = @()
                    }
                }
            }

            Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{ }

            $context.hits | Should -Be @('alpha')
        }
    }
}
