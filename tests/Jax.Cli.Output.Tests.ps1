BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
}

Describe 'Write-JaxPlanLog' {
    It 'writes a plan log file' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') | Out-Null

        $entities = @(
            @{ Key = 'build'; Runner = 'psake'; Tasks = @('Build') },
            @{ Key = 'deploy'; Runner = 'psake'; Tasks = @('Deploy') }
        )

        $path = Write-JaxPlanLog -Entities $entities -RepoRoot $tempRoot
        (Test-Path -Path $path -PathType Leaf) | Should -Be $true

        $content = Get-Content -Path $path -Raw
        $content | Should -Match 'Jax Run Plan'
        $content | Should -Match 'Key: build'
        $content | Should -Match 'Key: deploy'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Write-JaxRunConfigLog' {
    It 'writes a run config log file' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') | Out-Null

        $config = @{
            module = @{
                name = 'demo'
                docker = @{
                    image = 'demo-image'
                }
            }
        }

        $path = Write-JaxRunConfigLog -RunConfig $config -RepoRoot $tempRoot
        (Test-Path -Path $path -PathType Leaf) | Should -Be $true

        $content = Get-Content -Path $path -Raw
        $content | Should -Match 'demo'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
