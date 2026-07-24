$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Invoke-JaxEnvInit' {
    It 'creates env hierarchy and flow files' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') | Out-Null

        Invoke-JaxEnvInit -RepoRoot $tempRoot -EnvRoot 'env' -Client 'acme' -Env 'dev' -DefaultFlow 'build' -AdditionalFlows @('publish', 'k8s') -EnableVault:$false -EnableDotenv:$false -IncludeState:$false | Out-Null

        (Test-Path -Path (Join-Path $tempRoot 'env/common/flows') -PathType Container) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/acme/common/flows') -PathType Container) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/acme/dev/flows') -PathType Container) | Should -Be $true

        (Test-Path -Path (Join-Path $tempRoot 'env/acme/dev/flows/build.yml') -PathType Leaf) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/acme/dev/flows/publish.yml') -PathType Leaf) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/acme/dev/flows/k8s.yml') -PathType Leaf) | Should -Be $true

        (Test-Path -Path (Join-Path $tempRoot 'env/common/psakefile.ps1') -PathType Leaf) | Should -Be $true
        (Test-Path -Path (Join-Path $tempRoot 'env/common/scenarios-lib/sample.yml') -PathType Leaf) | Should -Be $true

        (Test-Path -Path (Join-Path $tempRoot '.jax/.gitignore') -PathType Leaf) | Should -Be $true
        $gitIgnore = Get-Content -Path (Join-Path $tempRoot '.jax/.gitignore')
        $gitIgnore | Should -Contain 'state.yml'
        $gitIgnore | Should -Contain 'logs/'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'adds explicit plugin overrides without expanding all defaults' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.jax') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null
        Set-Content -Path (Join-Path $tempRoot '.jax/jax.config.yml') -Value 'jax: {}' -Encoding ascii

        Invoke-JaxEnvInit -RepoRoot $tempRoot -EnvRoot 'env' -Client 'acme' -Env 'dev' `
            -DefaultFlow 'build' -AdditionalFlows @() -EnableVault -EnableDotenv:$false `
            -IncludeState:$false | Out-Null

        $rawConfig = Get-Content -Path (Join-Path $tempRoot '.jax/jax.config.yml') -Raw
        $rawConfig | Should -Not -Match '(?m)^\s{2}envRoot:'
        $rawConfig | Should -Not -Match '(?m)^\s{2}autocomplete:'

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $config.plugins.enabled | Should -Contain 'machine'
        $config.plugins.enabled | Should -Contain 'bob'
        $config.plugins.enabled | Should -Contain 'vault'
        $config.plugins.disabled | Should -Not -Contain 'vault'
        $config.plugins.config.vault.enabled | Should -BeTrue

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
