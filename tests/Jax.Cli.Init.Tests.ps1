$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Invoke-JaxInit' {
    It 'creates repo scaffold and config file' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') | Out-Null

        $queue = New-Object 'System.Collections.Queue'
        $queue.Enqueue('n')

        Invoke-JaxInit -RepoRoot $tempRoot -Client 'acme' -Env 'dev' -FlowConfig 'build' -InputQueue $queue

        (Test-Path -Path (Join-Path $tempRoot '.jax/jax.config.yml') -PathType Leaf) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot '.jax/.gitignore') -PathType Leaf) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/acme/dev/flows/build.yml') -PathType Leaf) | Should -Be $true

        $rawConfig = Get-Content -Path (Join-Path $tempRoot '.jax/jax.config.yml') -Raw
        $repoConfig = Read-JaxYaml -Path (Join-Path $tempRoot '.jax/jax.config.yml')
        $repoConfig.jax.envRoot | Should -Be 'env'
        @($repoConfig.jax.flowDirNames) | Should -Be @('flows')
        @($repoConfig.jax.conventionalEnvRoots) | Should -Be @('code')
        @($repoConfig.jax.plugins.enabled) | Should -Be @('machine', 'bob', 'vault', 'docker')
        $repoConfig.jax.plugins.config.vault.enabled | Should -BeFalse
        $repoConfig.jax.plugins.config.vault.authMount | Should -Be 'github'
        $rawConfig | Should -Match '🧪'
        $rawConfig | Should -Not -Match '\\U0001F9EA'
        $rawConfig | Should -Not -Match '(?i)boss|bobfile|TEAMCITY_VERSION|configs/jax/tc-|\.build/\*\*/\*\.psm1'

        (Test-Path -Path (Join-Path $tempRoot 'configs/jax/common/sample.yml')) | Should -Be $false
        (Test-Path -Path (Join-Path $tempRoot 'configs/jax/local-override.sample.yml')) | Should -Be $false
        (Test-Path -Path (Join-Path $tempRoot 'configs/jax/ci-sample.yml')) | Should -Be $false
        (Test-Path -Path (Join-Path $tempRoot 'configs/jax-flavours/sample.yml')) | Should -Be $false

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.autocomplete.clientIcons.demo | Should -Be '🧪'
        $config.autocomplete.flowIcons.build | Should -Be '🔨'

        foreach ($relativeAnchor in @(
            'env/common/flows/.gitkeep',
            'env/common/scripts/.gitkeep',
            'env/common/scenarios-lib/.gitkeep',
            'env/acme/common/flows/.gitkeep',
            'env/acme/common/scripts/.gitkeep',
            'env/acme/common/scenarios-lib/.gitkeep',
            'env/acme/dev/flows/.gitkeep',
            'env/acme/dev/scripts/.gitkeep',
            'env/acme/dev/scenarios-lib/.gitkeep'
        )) {
            (Test-Path -Path (Join-Path $tempRoot $relativeAnchor) -PathType Leaf) | Should -Be $true
        }

        $gitIgnore = Get-Content -Path (Join-Path $tempRoot '.jax/.gitignore')
        $gitIgnore | Should -Contain 'state.yml'
        $gitIgnore | Should -Contain 'logs/'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Invoke-JaxInitCompatConfig' {
    It 'writes a compatibility config with bob patterns' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') | Out-Null

        Invoke-JaxInitCompatConfig -RepoRoot $tempRoot | Out-Null
        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig

        $config.flowDirNames[0] | Should -Be 'boss'
        $config.plugins.config.bob.layers.repoCommonPatterns | Should -Contain 'code/bob-*-common.yml'
        $config.plugins.config.bob.layers.flavourDir | Should -Be 'configs/jax-flavours'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
