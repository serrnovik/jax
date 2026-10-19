Describe 'Sync-JaxSessionModule' {
    BeforeAll {
        $script:sourceRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $script:sourceRoot 'core/Jax.Core.psm1') -Global -Force
        $script:previousJax = Get-Module Jax | Select-Object -First 1 -ExpandProperty Path

        function script:Set-FakeJaxVersion([string] $Root, [string] $Version) {
            Set-Content -LiteralPath (Join-Path $Root 'Jax.psd1') -Value @"
@{
    RootModule = 'Jax.psm1'
    ModuleVersion = '$Version'
    GUID = '00000000-0000-0000-0000-000000000001'
}
"@
        }
    }

    BeforeEach {
        $script:fakeRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:fakeRoot = Join-Path $script:fakeRoot 'Jax'
        New-Item -ItemType Directory -Path $script:fakeRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:fakeRoot 'Jax.psm1') -Value 'function Get-FakeJax { 1 }'
        Set-FakeJaxVersion -Root $script:fakeRoot -Version '0.1.0'
        Get-Module Jax | Remove-Module -Force
        Import-Module (Join-Path $script:fakeRoot 'Jax.psd1') -Global -Force
        $script:savedEntrypoint = $env:JAX_SHELL_ENTRYPOINT
        $env:JAX_SHELL_ENTRYPOINT = $null
    }

    AfterEach {
        $env:JAX_SHELL_ENTRYPOINT = $script:savedEntrypoint
        Get-Module Jax | Remove-Module -Force
    }

    AfterAll {
        if ($script:previousJax) {
            Import-Module $script:previousJax -Global -Force -DisableNameChecking
        }
    }

    It 'reloads the module when the copy on disk is newer' {
        Set-FakeJaxVersion -Root $script:fakeRoot -Version '0.2.0'

        Sync-JaxSessionModule 6>$null

        (Get-Module Jax).Version | Should -Be ([version]'0.2.0')
    }

    It 'leaves the module alone when the versions match' {
        $before = Get-Module Jax

        Sync-JaxSessionModule 6>$null

        (Get-Module Jax) | Should -Be $before
    }

    It 'does nothing under the shell shims' {
        Set-FakeJaxVersion -Root $script:fakeRoot -Version '0.2.0'
        $env:JAX_SHELL_ENTRYPOINT = 'jx'

        Sync-JaxSessionModule 6>$null

        (Get-Module Jax).Version | Should -Be ([version]'0.1.0')
    }
}
