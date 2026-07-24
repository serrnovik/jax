$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Resolve-JaxEnvSelection' {
    It 'returns flow override when env contains a flow suffix' {
        $envs = @(
            [pscustomobject]@{ Name = 'sample-app' },
            [pscustomobject]@{ Name = 'client/dev' }
        )

        $result = Resolve-JaxEnvSelection -Environments $envs -Env 'sample-app/build'
        $result.Environment.Name | Should -Be 'sample-app'
        $result.FlowOverride | Should -Be 'build'
    }

    It 'uses exact env match when available' {
        $envs = @(
            [pscustomobject]@{ Name = 'client/dev' },
            [pscustomobject]@{ Name = 'client/prod' }
        )

        $result = Resolve-JaxEnvSelection -Environments $envs -Env 'client/dev'
        $result.Environment.Name | Should -Be 'client/dev'
        $result.FlowOverride | Should -Be $null
    }

    It 'resolves computed build env rooted and short aliases' {
        $envs = @(
            [pscustomobject]@{
                Name = 'build/operations/backups'
                Aliases = @('code/operations/backups', 'operations/backups')
            }
        )

        (Resolve-JaxEnvSelection -Environments $envs -Env 'build/operations/backups').Environment.Name | Should -Be 'build/operations/backups'
        (Resolve-JaxEnvSelection -Environments $envs -Env 'code/operations/backups').Environment.Name | Should -Be 'build/operations/backups'
        (Resolve-JaxEnvSelection -Environments $envs -Env 'operations/backups').Environment.Name | Should -Be 'build/operations/backups'
    }

    It 'does not resolve duplicated computed build envs by short alias' {
        $envs = @(
            [pscustomobject]@{
                Name = 'code/operations/backups'
                Aliases = @()
            },
            [pscustomobject]@{
                Name = 'tools/operations/backups'
                Aliases = @()
            }
        )

        { Resolve-JaxEnvSelection -Environments $envs -Env 'operations/backups' } | Should -Throw "*Environment 'operations/backups' was not found*"
        (Resolve-JaxEnvSelection -Environments $envs -Env 'code/operations/backups').Environment.Name | Should -Be 'code/operations/backups'
    }

    It 'throws on ambiguous aliases' {
        $envs = @(
            [pscustomobject]@{
                Name = 'build/one'
                Aliases = @('shared')
            },
            [pscustomobject]@{
                Name = 'build/two'
                Aliases = @('shared')
            }
        )

        { Resolve-JaxEnvSelection -Environments $envs -Env 'shared' } | Should -Throw "*Environment alias 'shared' is ambiguous*"
    }
}
