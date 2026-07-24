$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxConfig' {
    It 'uses generic defaults without legacy repository conventions' {
        InModuleScope Jax.Core {
            $config = Get-JaxDefaultConfig

            @($config.flowDirNames) | Should -Be @('flows')
            @($config.conventionalEnvRoots) | Should -Be @('code')
            @($config.plugins.config.bob.fileBaseNames) | Should -Be @('jaxfile')
            @($config.plugins.config.bob.layers.ciOverridePatterns) |
                Should -Be @('configs/jax/ci-*.yml', 'configs/jax/ci-*.yaml')
            @($config.plugins.config.bob.layers.ciEnvVars) | Should -Be @('CI')
            @($config.plugins.enabled) | Should -Be @('machine', 'bob', 'vault', 'docker')
            $config.plugins.config.vault.enabled | Should -BeFalse
            $config.plugins.config.vault.authMount | Should -Be 'github'
            @($config.moduleReload.excludePathPatterns).Count | Should -Be 0
        }
    }

    It 'uses repo config to override defaults' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: envs
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $config.envRoot | Should -Be 'envs'
        $config.commonDirName | Should -Be 'common'
        $config.scenarioLibDirName | Should -Be 'scenarios-lib'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'uses user config to override repo config' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env-repo
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $userConfigPath = Join-Path $tempRoot 'user.yml'
        @'
jax:
  envRoot: env-user
'@ | Set-Content -Path $userConfigPath -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath $userConfigPath
        $config.envRoot | Should -Be 'env-user'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'normalizes legacy bossDirName to flowDirNames' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  bossDirName: boss
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.flowDirNames | Should -Be @('flows', 'boss')
        ($config.Keys -contains 'bossDirName') | Should -Be $false

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'uses legacy jax.config.yml when .jax config is missing' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $legacyConfigPath = Join-Path $tempRoot 'jax.config.yml'
        @'
jax:
  envRoot: legacy-env
'@ | Set-Content -Path $legacyConfigPath -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.envRoot | Should -Be 'legacy-env'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'throws when config types are invalid' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot:
    - wrong
  tasks: "nope"
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        { Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig } | Should -Throw "*envRoot*"
        { Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig } | Should -Throw "*tasks*"

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'keeps empty list fields when preparing config for save' {
        InModuleScope Jax.Core {
            $config = @{
                envRoot = 'env'
                flowDirNames = @()
                flowFilePatterns = @()
                tasks = @{ psakeFilePattern = 'psakefile*.ps1' }
                scripts = @{ dirNames = @('scripts') }
                modulePathInGit = @{}
                taskIgnoreList = $null
                aliases = @{}
                plugins = @{
                    enabled = @('bob')
                    disabled = @()
                    paths = @()
                    config = @{}
                }
                cache = @{ enabled = $true; dir = '.jax/cache' }
            }

            $saved = Convert-JaxConfigForSave -Config $config

            (@($saved.tasks.nonConventionalDirs).Count) | Should -Be 0
            (@($saved.scripts.nonConventionalDirs).Count) | Should -Be 0
            (@($saved.taskIgnoreList).Count) | Should -Be 0
        }
    }
}

Describe 'Write-JaxYaml and Read-JaxYaml (UTF-8)' {
    It 'round-trips emoji in a nested jax value' {
        $temp = Join-Path ([IO.Path]::GetTempPath()) ('jax-utf8-' + [guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        try {
            $p = Join-Path $temp 'test.yml'
            $payload = @{
                jax = @{
                    userNote = 'Plugin 🧪 notes'
                }
            }
            Write-JaxYaml -Path $p -InputObject $payload
            $raw = Get-Content -Path $p -Raw
            $raw | Should -Match '🧪'
            $raw | Should -Not -Match '\\U0001F9EA'
            # Literal Unicode must still round-trip through the configured YAML provider.
            $read = Read-JaxYaml -Path $p
            $read.jax.userNote | Should -Be 'Plugin 🧪 notes'
        } finally {
            Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
