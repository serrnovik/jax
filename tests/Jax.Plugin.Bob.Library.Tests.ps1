Describe 'Get-JaxBobScenarioLibrary' {
    BeforeAll {
        $script:CoreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
        $script:PluginPath = Join-Path $PSScriptRoot '../plugins/bob/Jax.Plugin.Bob.psm1'
        Import-Module $script:CoreModulePath -Force
        Import-Module $script:PluginPath -Force -DisableNameChecking
    }

    BeforeEach {
        if (-not (Get-Module Jax.Core)) {
            Import-Module $script:CoreModulePath -Force
        }
        if (-not (Get-Module Jax.Plugin.Bob)) {
            Import-Module $script:PluginPath -Force -DisableNameChecking
        }
    }

    It 'merges scenarios-lib layers with suite.library overriding' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $commonLibDir = Join-Path $envRoot 'common/scenarios-lib'
        $clientLibDir = Join-Path $envRoot 'acme/common/scenarios-lib'
        $envLibDir = Join-Path $envRoot 'acme/dev/scenarios-lib'
        New-Item -ItemType Directory -Path $commonLibDir -Force | Out-Null
        New-Item -ItemType Directory -Path $clientLibDir -Force | Out-Null
        New-Item -ItemType Directory -Path $envLibDir -Force | Out-Null

        @'
foo:
  runner: psake
  task: CommonTask
bar:
  runner: psake
  task: CommonBar
'@ | Set-Content -Path (Join-Path $commonLibDir 'lib.yml') -Encoding ascii

        @'
foo:
  task: ClientTask
'@ | Set-Content -Path (Join-Path $clientLibDir 'lib.yml') -Encoding ascii

        @'
foo:
  task: EnvTask
'@ | Set-Content -Path (Join-Path $envLibDir 'lib.yml') -Encoding ascii

        $flowConfig = @{
            suite = @{
                library = @{
                    foo = @{
                        task = 'FlowTask'
                    }
                }
            }
        }

        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $envDir = Join-Path $envRoot 'acme/dev'
        $result = Get-JaxBobScenarioLibrary -RepoRoot $tempRoot -EnvDir $envDir -Config $config -FlowConfig $flowConfig

        $result.Library.foo.task | Should -Be 'FlowTask'
        $result.Library.foo.runner | Should -Be 'psake'
        $result.Library.bar.task | Should -Be 'CommonBar'
        $result.Paths.Count | Should -Be 3

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Scenario library usage' {
    BeforeAll {
        $script:CoreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
        $script:PluginPath = Join-Path $PSScriptRoot '../plugins/bob/Jax.Plugin.Bob.psm1'
        Import-Module $script:CoreModulePath -Force
        Import-Module $script:PluginPath -Force -DisableNameChecking
    }

    BeforeEach {
        if (-not (Get-Module Jax.Core)) {
            Import-Module $script:CoreModulePath -Force
        }
        if (-not (Get-Module Jax.Plugin.Bob)) {
            Import-Module $script:PluginPath -Force -DisableNameChecking
        }
    }

    It 'resolves null scenario items from scenarios-lib' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $libDir = Join-Path $envRoot 'common/scenarios-lib'
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null

        @'
deploy:
  runner: psake
  task: DeployApp
'@ | Set-Content -Path (Join-Path $libDir 'deploy.yml') -Encoding ascii

        $flowConfig = @{
            suite = @{
                scenarios = @{
                    default = @{
                        deploy = $null
                    }
                }
            }
        }

        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $false
        }
        Register-JaxBobPlugin

        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $context = @{
            RepoRoot = $tempRoot
            EnvDir   = Join-Path $envRoot 'common'
            Config   = $config
        }

        $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -Context $context)
        $context.ContainsKey('ScenarioLibrary') | Should -Be $true
        $context.ScenarioLibrary.deploy.task | Should -Be 'DeployApp'
        $entities.Count | Should -Be 1
        $entities[0].Runner | Should -Be 'psake'
        $entities[0].Tasks | Should -Be @('DeployApp')

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'expands library steps recursively' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $libDir = Join-Path $envRoot 'common/scenarios-lib'
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null

        @'
deploy:
  runner: psake
  task: DeployTask
flow:
  steps:
    prepare:
      runner: psake
      task: PrepareTask
    deploy:
'@ | Set-Content -Path (Join-Path $libDir 'lib.yml') -Encoding ascii

        $flowConfig = @{
            suite = @{
                scenarios = @{
                    default = @{
                        flow = $null
                    }
                }
            }
        }

        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $false
        }
        Register-JaxBobPlugin

        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $context = @{
            RepoRoot = $tempRoot
            EnvDir   = Join-Path $envRoot 'common'
            Config   = $config
        }

        $entities = @(Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -Context $context)
        $entities.Count | Should -Be 2
        $entities[0].Tasks | Should -Be @('PrepareTask')
        $entities[1].Tasks | Should -Be @('DeployTask')

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
