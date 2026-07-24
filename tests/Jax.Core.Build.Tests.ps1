$modulePath = (Resolve-Path (Join-Path $PSScriptRoot '../core/Jax.Core.psm1')).Path
Import-Module $modulePath -Force

Describe 'Get-JaxBuildRunEntities' {
    It 'binds build items to discovered psake files' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envCommon = Join-Path $tempRoot 'env/common'
        $envSpecific = Join-Path $tempRoot 'env/client-a/dev'
        New-Item -ItemType Directory -Path $envCommon -Force | Out-Null
        New-Item -ItemType Directory -Path $envSpecific -Force | Out-Null

        Set-Content -Path (Join-Path $envCommon 'psakefile.ps1') -Value @'
Task Build { }
Task Pack { }
'@ -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $discovered = Get-JaxDiscoveredRunEntities -RepoRoot $tempRoot -EnvDir $envSpecific -Config $config
        $index = New-JaxRunEntityIndex -Entities $discovered
        $context = @{
            DiscoveredEntities    = $discovered
            DiscoveredEntityIndex = $index
        }

        $flow = @{
            suite = @{
                build = @('Build', 'Pack')
            }
        }

        $entities = Get-JaxBuildRunEntities -FlowConfig $flow -Context $context -ProvenancePath (Join-Path $envSpecific 'flows/build.yml')
        $entities.Count | Should -Be 2
        $entities[0].Runner | Should -Be 'psake'
        $entities[0].PsakeFile | Should -Be (Join-Path $envCommon 'psakefile.ps1')

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
