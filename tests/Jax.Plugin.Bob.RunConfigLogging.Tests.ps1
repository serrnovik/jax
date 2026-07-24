$coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $coreModulePath -Force

$pluginPath = Join-Path $PSScriptRoot '../plugins/bob/Jax.Plugin.Bob.psm1'
Import-Module $pluginPath -Force -DisableNameChecking

Describe 'Jax bob plugin run-config logging' {
    BeforeAll {
        function New-JaxClientFixtureCopy {
            $sourceFixture = Join-Path $PSScriptRoot 'fixtures/jax-client'
            $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $null = New-Item -Path $parent -ItemType Directory -Force
            $fixtureRoot = Join-Path $parent 'jax-client'
            Copy-Item -Path $sourceFixture -Destination $fixtureRoot -Recurse -Force
            return $fixtureRoot
        }
    }

    It 'does not write run-config log when SuppressRunConfigLog is true (DynamicParam safety)' {
        $fixtureRoot = New-JaxClientFixtureCopy
        $config = Get-JaxConfig -RepoRoot $fixtureRoot -SkipUserConfig
        $envDir = Join-Path $fixtureRoot 'env/jax_client/dev'

        $logDir = Join-Path $fixtureRoot '.jax/logs'
        if (Test-Path -Path $logDir) {
            Remove-Item -Path $logDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        $context = @{
            SuppressRunConfigLog = $true
        }

        $null = Get-JaxBobRunConfig -RepoRoot $fixtureRoot -EnvDir $envDir -Config $config -PluginConfig @{} -Context $context

        (Test-Path -Path $logDir) | Should -Be $false
    }

    It 'injects boss.suite.* from flow suite into run-config for backwards compatibility' {
        $fixtureRoot = New-JaxClientFixtureCopy
        $config = Get-JaxConfig -RepoRoot $fixtureRoot -SkipUserConfig
        $envDir = Join-Path $fixtureRoot 'env/jax_client/dev'

        $flowConfig = @{
            suite = @{
                name = 'jax-client-suite'
                client = 'acme'
                env_type = 'dev'
                env = '{{ boss.suite.client }}/{{ boss.suite.env_type }}'
            }
        }

        $ctx = @{
            SuppressRunConfigLog = $true
        }

        $result = Get-JaxBobRunConfig -RepoRoot $fixtureRoot -EnvDir $envDir -Config $config -PluginConfig @{} -FlowConfig $flowConfig -Context $ctx
        $result.Config.boss.suite.name | Should -Be 'jax-client-suite'
        $result.Config.boss.suite.env | Should -Be 'acme/dev'
    }

    It 'expands flow suite version placeholders using injected boss suite' {
        $fixtureRoot = New-JaxClientFixtureCopy
        $config = Get-JaxConfig -RepoRoot $fixtureRoot -SkipUserConfig
        $envDir = Join-Path $fixtureRoot 'env/jax_client/dev'

        $flowConfig = @{
            suite = @{
                name = 'jax-client-suite'
                client = 'acme'
                env_type = 'dev'
                env = '{{ boss.suite.client }}/{{ boss.suite.env_type }}'
                version = @{
                    base = '0.1'
                    number = '{{ boss.suite.version.base }}.{{ env.tc.source.chain.build.counter }}'
                }
            }
        }

        $ctx = @{
            SuppressRunConfigLog = $true
            VariablesOverride = @{
                env = @{
                    tc = @{
                        source = @{
                            chain = @{
                                build = @{
                                    counter = 123
                                }
                            }
                        }
                    }
                }
            }
        }

        $result = Get-JaxBobRunConfig -RepoRoot $fixtureRoot -EnvDir $envDir -Config $config -PluginConfig @{} -FlowConfig $flowConfig -Context $ctx
        $result.Config.boss.suite.version.base | Should -Be '0.1'
        $result.Config.boss.suite.version.number | Should -Be '0.1.123'
        $result.Config.flow.suite.version.number | Should -Be '0.1.123'
    }
}
