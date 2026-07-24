$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Jax state' {
    It 'writes and reads state updates' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $updates = @{
            core = @{
                env = 'dev'
                scenario = 'default'
            }
        }

        Update-JaxState -RepoRoot $tempRoot -Updates $updates | Out-Null
        $state = Get-JaxState -RepoRoot $tempRoot

        $state.core.env | Should -Be 'dev'
        $state.core.scenario | Should -Be 'default'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'respects NoSavedSettings' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $updates = @{
            core = @{
                env = 'dev'
            }
        }

        Update-JaxState -RepoRoot $tempRoot -Updates $updates -NoSavedSettings | Out-Null

        $statePath = Join-Path $tempRoot '.jax/state.yml'
        (Test-Path -Path $statePath) | Should -Be $false

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
