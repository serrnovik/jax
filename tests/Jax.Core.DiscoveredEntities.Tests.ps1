$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxDiscoveredRunEntities' {
    It 'discovers psake tasks with env precedence' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envCommon = Join-Path $tempRoot 'env/common'
        $envSpecific = Join-Path $tempRoot 'env/client-a/dev'
        New-Item -ItemType Directory -Path $envCommon -Force | Out-Null
        New-Item -ItemType Directory -Path $envSpecific -Force | Out-Null

        Set-Content -Path (Join-Path $envCommon 'psakefile.ps1') -Value @'
Task Info { }
Task Build { }
'@ -Encoding ascii

        Set-Content -Path (Join-Path $envSpecific 'psakefile.ps1') -Value @'
Task Info { }
Task Deploy { }
'@ -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $entities = Get-JaxDiscoveredRunEntities -RepoRoot $tempRoot -EnvDir $envSpecific -Config $config

        $info = @($entities | Where-Object { $_.Key -eq 'Info' })
        $info.Count | Should -Be 1
        $info[0].PsakeFile | Should -Be (Join-Path $envSpecific 'psakefile.ps1')

        @($entities | Where-Object { $_.Key -eq 'Build' }).Count | Should -Be 1
        @($entities | Where-Object { $_.Key -eq 'Deploy' }).Count | Should -Be 1

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'discovers scripts from env script directories' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envCommonScripts = Join-Path $tempRoot 'env/common/scripts'
        $envSpecificScripts = Join-Path $tempRoot 'env/client-b/prod/scripts'
        New-Item -ItemType Directory -Path $envCommonScripts -Force | Out-Null
        New-Item -ItemType Directory -Path $envSpecificScripts -Force | Out-Null

        Set-Content -Path (Join-Path $envCommonScripts 'clean.ps1') -Value 'Write-Host "clean"' -Encoding ascii
        Set-Content -Path (Join-Path $envSpecificScripts 'deploy.sh') -Value '#!/bin/bash' -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $envDir = Join-Path $tempRoot 'env/client-b/prod'
        $entities = Get-JaxDiscoveredRunEntities -RepoRoot $tempRoot -EnvDir $envDir -Config $config

        $clean = @($entities | Where-Object { $_.Key -eq 'clean' })
        $clean.Count | Should -Be 1
        $clean[0].Runner | Should -Be 'pwshscript'

        $deploy = @($entities | Where-Object { $_.Key -eq 'deploy' })
        $deploy.Count | Should -Be 1
        $deploy[0].Runner | Should -Be 'bashscript'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
