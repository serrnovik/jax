$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxRunEntityKeys' {
    It 'includes aliases when requested' {
        $entities = @(
            @{
                Key     = 'build'
                Aliases = @('b', 'compile')
            },
            @{
                Key = 'test'
            }
        )

        $keys = Get-JaxRunEntityKeys -Entities $entities -IncludeAliases
        $keys | Should -Contain 'build'
        $keys | Should -Contain 'b'
        $keys | Should -Contain 'compile'
        $keys | Should -Contain 'test'
    }
}
