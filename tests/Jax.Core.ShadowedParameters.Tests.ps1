BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force

    # The names jax.ps1 keeps for itself when it builds CliArgs.
    $script:ReservedNames = @(
        'Command', 'CommandArgs', 'env', 'client', 'scenario', 'from', 'to', 'only', 'noBuild', 'buildChainOnly', 'noCache',
        'Detailed', 'Shortcut', 'SaveShortcut', 'RemoveShortcut', 'vault', 'novault', 'vaultToken', 'vaultTokenEnv', 'useEnvVaultToken',
        'coverage', 'nocoverage'
    )

    function New-PsakeEntity {
        param([string] $Key, [string[]] $ParameterNames)
        return @{
            Key        = $Key
            Runner     = 'psake'
            Definition = @{
                Name       = $Key
                Parameters = @($ParameterNames | ForEach-Object { @{ Name = $_; Type = 'System.String' } })
            }
        }
    }
}

Describe 'Get-JaxShadowedTaskParameters' {
    It 'reports a psake property that collides with a Jax flag' {
        $entity = New-PsakeEntity -Key 'RegisterOperatorMcp' -ParameterNames @('slug', 'client', 'mcpModernOnly')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{})

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'client'
        $result[0].Entities | Should -Be @('RegisterOperatorMcp')
        $result[0].Supplied | Should -BeFalse
    }

    It 'marks the collision as supplied when the flag was typed this run' {
        $entity = New-PsakeEntity -Key 'RegisterOperatorMcp' -ParameterNames @('client')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{ client = 'codex' })

        $result.Count | Should -Be 1
        $result[0].Supplied | Should -BeTrue
    }

    It 'matches the flag name case-insensitively' {
        $entity = New-PsakeEntity -Key 'Deploy' -ParameterNames @('NoCache')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{ nocache = $true })

        $result.Count | Should -Be 1
        $result[0].Supplied | Should -BeTrue
    }

    It 'does not treat a switch left at $false as supplied' {
        $entity = New-PsakeEntity -Key 'Deploy' -ParameterNames @('noCache')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{ noCache = $false })

        $result.Count | Should -Be 1
        $result[0].Supplied | Should -BeFalse
    }

    It 'stays silent when no parameter collides' {
        $entity = New-PsakeEntity -Key 'RegisterOperatorMcp' -ParameterNames @('mcpClient', 'slug', 'organization')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{ client = 'codex' })

        $result.Count | Should -Be 0
    }

    It 'ignores the positional Command/CommandArgs names' {
        $entity = New-PsakeEntity -Key 'Build' -ParameterNames @('Command', 'CommandArgs')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{})

        $result.Count | Should -Be 0
    }

    It 'collects every entity that declares the same colliding name' {
        $first = New-PsakeEntity -Key 'RegisterOperatorMcp' -ParameterNames @('client')
        $second = New-PsakeEntity -Key 'ShowOperatorMcpRegistration' -ParameterNames @('client')

        $result = @(Get-JaxShadowedTaskParameters -Entities @($first, $second) -ReservedNames $script:ReservedNames -SuppliedOptions @{})

        $result.Count | Should -Be 1
        @($result[0].Entities) | Should -Be @('RegisterOperatorMcp', 'ShowOperatorMcpRegistration')
    }

    It 'reports a colliding script param() as well' {
        $scriptDir = Join-Path ([IO.Path]::GetTempPath()) ("jax-shadow-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $scriptDir | Out-Null
        try {
            $scriptPath = Join-Path $scriptDir 'deploy.ps1'
            Set-Content -LiteralPath $scriptPath -Value 'param([string] $client, [string] $tag)' -Encoding UTF8

            $entity = @{ Key = 'Deploy'; Runner = 'script'; Script = $scriptPath }
            $result = @(Get-JaxShadowedTaskParameters -Entities @($entity) -ReservedNames $script:ReservedNames -SuppliedOptions @{ client = 'codex' } -Context @{ RepoRoot = $scriptDir; WorkingDir = $scriptDir })

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'client'
            $result[0].Supplied | Should -BeTrue
        } finally {
            Remove-Item -LiteralPath $scriptDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns nothing for an empty plan' {
        @(Get-JaxShadowedTaskParameters -Entities @() -ReservedNames $script:ReservedNames -SuppliedOptions @{ client = 'codex' }).Count | Should -Be 0
    }
}
