$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Psake parsing' {
    It 'discovers tasks without executing top-level imports' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempRoot | Out-Null

            $psakeDir = Join-Path $tempRoot 'env/common'
            New-Item -ItemType Directory -Path $psakeDir -Force | Out-Null

            $includePath = Join-Path $psakeDir 'psakefile-include.ps1'
            Set-Content -Path $includePath -Value @'
Import-Module (Join-Path $properties.env.git.root "missing.psm1")
Task Deploy { }
'@ -Encoding ascii

            $mainPath = Join-Path $psakeDir 'psakefile.ps1'
            Set-Content -Path $mainPath -Value @"
Include "$includePath"
Task Build { }
"@ -Encoding ascii

            $entities = Get-JaxPsakeTaskEntities -DirPaths @($psakeDir) -FilePattern 'psakefile*.ps1' -TaskIgnoreList @()

            @($entities | Where-Object { $_.Key -eq 'Build' }).Count | Should -Be 1
            @($entities | Where-Object { $_.Key -eq 'Deploy' }).Count | Should -Be 1

            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }
}
