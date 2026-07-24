$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxEnvironments' {
    It 'discovers envs and flow configs under env root' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $bossDir1 = Join-Path $envRoot 'client-a/dev/boss'
        $bossDir2 = Join-Path $envRoot 'client-b/prod/boss'
        New-Item -ItemType Directory -Path $bossDir1 -Force | Out-Null
        New-Item -ItemType Directory -Path $bossDir2 -Force | Out-Null

        Set-Content -Path (Join-Path $bossDir1 'build.yml') -Value "suite:" -Encoding ascii
        Set-Content -Path (Join-Path $bossDir2 'pack.yml') -Value "suite:" -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $config.flowDirNames = @('boss')
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config

        ($envs | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @('client-a/dev', 'client-b/prod', 'none')
        ($envs | Where-Object { $_.Name -eq 'client-a/dev' }).FlowConfigs[0].Configuration | Should -Be 'build'
        ($envs | Where-Object { $_.Name -eq 'client-b/prod' }).FlowConfigs[0].Configuration | Should -Be 'pack'
        ($envs | Where-Object { $_.Name -eq 'client-a/dev' }).FlowConfigs[0].Name | Should -Be 'client-a/dev/build'
        ($envs | Where-Object { $_.Name -eq 'client-a/dev' }).FlowConfigs[0].PrettyName | Should -Be 'Client A Dev Build'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'supports custom flowDirNames list' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $flowDir = Join-Path $envRoot 'client-x/dev/flows'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        Set-Content -Path (Join-Path $flowDir 'build.yml') -Value "suite:" -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.flowDirNames = @('flows')
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config

        ($envs | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @('client-x/dev', 'none')
        ($envs | Select-Object -ExpandProperty FlowDir) | Should -Match 'flows'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'includes single-level env directories in flow discovery' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        $flowDir = Join-Path $envRoot 'client-only/boss'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        Set-Content -Path (Join-Path $flowDir 'build.yml') -Value "suite:" -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $config.flowDirNames = @('boss')
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config

        ($envs | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @('client-only', 'none')
        ($envs | Where-Object { $_.Name -eq 'client-only' }).FlowConfigs[0].Configuration | Should -Be 'build'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'returns dummy env when env root is missing' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config

        $envs.Count | Should -Be 1
        $envs[0].Name | Should -Be 'none'
        $envs[0].IsDummy | Should -Be $true

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'adds computed build envs for module roots with psakefile' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $moduleDir = Join-Path $tempRoot 'code/sample-module'
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
        Set-Content -Path (Join-Path $moduleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.conventionalEnvRoots = @('code')
        $config.dummyEnv.enabled = $false
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config

        ($envs | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @('build/sample-module')
        $computedEnv = $envs | Where-Object { $_.Name -eq 'build/sample-module' } | Select-Object -First 1
        $computedEnv.EnvDir | Should -Be (Resolve-Path $moduleDir).Path
        $computedEnv.FlowConfigs.Count | Should -Be 0
        $computedEnv.IsComputed | Should -Be $true
        $computedEnv.PreferredCompletionName | Should -Be 'sample-module'
        @($computedEnv.Aliases) | Should -Contain 'code/sample-module'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'uses rooted names for duplicate computed build envs' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $codeModuleDir = Join-Path $tempRoot 'code/operations/backups'
        $toolsModuleDir = Join-Path $tempRoot 'tools/operations/backups'
        New-Item -ItemType Directory -Path $codeModuleDir -Force | Out-Null
        New-Item -ItemType Directory -Path $toolsModuleDir -Force | Out-Null
        Set-Content -Path (Join-Path $codeModuleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii
        Set-Content -Path (Join-Path $toolsModuleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.conventionalEnvRoots = @('code', 'tools')
        $config.dummyEnv.enabled = $false
        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config
        $envNames = @($envs | Select-Object -ExpandProperty Name | Sort-Object)

        $envNames | Should -Be @('code/operations/backups', 'tools/operations/backups')
        $codeComputedEnv = $envs | Where-Object { $_.Name -eq 'code/operations/backups' } | Select-Object -First 1
        $codeComputedEnv.PreferredCompletionName | Should -Be 'code/operations/backups'
        @($codeComputedEnv.Aliases).Count | Should -Be 0

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'accepts legacy buildEnvRoots alias and normalizes to conventionalEnvRoots' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $moduleDir = Join-Path $tempRoot 'code/sample-module'
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
        Set-Content -Path (Join-Path $moduleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: false
  buildEnvRoots:
    - code
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        ($config.Keys -contains 'conventionalEnvRoots') | Should -Be $true
        ($config.Keys -contains 'buildEnvRoots') | Should -Be $false
        @($config.conventionalEnvRoots) | Should -Be @('code')

        $envs = Get-JaxEnvironments -RepoRoot $tempRoot -Config $config
        ($envs | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @('build/sample-module')

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'accepts oldest legacy buildEnvRoot (singular) alias' {
        InModuleScope Jax.Core {
            $config = @{ buildEnvRoot = 'code' }
            $normalized = Convert-JaxConfig -Config $config
            ($normalized.Keys -contains 'conventionalEnvRoots') | Should -Be $true
            ($normalized.Keys -contains 'buildEnvRoot') | Should -Be $false
            @($normalized.conventionalEnvRoots) | Should -Be @('code')
        }
    }
}
