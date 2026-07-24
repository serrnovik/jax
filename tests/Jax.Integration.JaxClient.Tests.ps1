$coreModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../core/Jax.Core.psm1')).Path
Import-Module $coreModulePath -Force

Describe 'Jax integration (jax-client fixture)' {
    BeforeAll {
        $pluginPath = Join-Path $PSScriptRoot '../plugins/bob/Jax.Plugin.Bob.psm1'
        Import-Module $pluginPath -Force -DisableNameChecking -ErrorAction Stop

        $sourceFixture = Join-Path $PSScriptRoot 'fixtures/jax-client'
        $script:fixtureRoot = Join-Path $TestDrive 'jax-client'
        Copy-Item -LiteralPath $sourceFixture -Destination $script:fixtureRoot -Recurse
        & git -C $script:fixtureRoot init --quiet
        $script:config = Get-JaxConfig -RepoRoot $script:fixtureRoot -SkipUserConfig
    }

    AfterAll {
        Remove-Item -Path $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'discovers environments and flows' {
        $envs = Get-JaxEnvironments -RepoRoot $script:fixtureRoot -Config $script:config
        $names = @($envs | Select-Object -ExpandProperty Name | Sort-Object)
        $names | Should -Be @('jax_client/dev', 'jax_client/prod', 'none')

        $dev = $envs | Where-Object { $_.Name -eq 'jax_client/dev' } | Select-Object -First 1
        $dev.FlowConfigs.Count | Should -Be 1
        $dev.FlowConfigs[0].Configuration | Should -Be 'build'
    }

    It 'discovers env-level tasks and scripts with precedence' {
        $envDir = Join-Path $script:fixtureRoot 'env/jax_client/dev'
        $entities = Get-JaxDiscoveredRunEntities -RepoRoot $script:fixtureRoot -EnvDir $envDir -Config $script:config

        $info = $entities | Where-Object { $_.Key -eq 'Info' } | Select-Object -First 1
        $info.PsakeFile | Should -Be (Join-Path $envDir 'psakefile.ps1')

        $script = $entities | Where-Object { $_.Key -eq 'dev-script' } | Select-Object -First 1
        $script.Runner | Should -Be 'bashscript'

        @($entities | Where-Object { $_.Key -eq 'common-script' }).Count | Should -Be 1
    }

    It 'merges run config imports for env jaxfile' {
        $envDir = Join-Path $script:fixtureRoot 'env/jax_client/dev'
        $runConfig = Get-JaxBobRunConfig -RepoRoot $script:fixtureRoot -EnvDir $envDir -Config $script:config -PluginConfig @{} -Context @{}
        $runConfig.Config.module.name | Should -Be 'jax_client_dev'
        $runConfig.Config.container.image | Should -Be 'jax/client:base'
    }

    It 'expands scenario library with overrides and build chain resolution' {
        $envs = Get-JaxEnvironments -RepoRoot $script:fixtureRoot -Config $script:config
        $dev = $envs | Where-Object { $_.Name -eq 'jax_client/dev' } | Select-Object -First 1
        $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $dev -PreferredConfig 'build'
        $flowConfig = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths

        $discovered = Get-JaxDiscoveredRunEntities -RepoRoot $script:fixtureRoot -EnvDir $flowConfigEntry.EnvDirPath -Config $script:config
        $index = New-JaxRunEntityIndex -Entities $discovered
        $context = @{
            RepoRoot              = $script:fixtureRoot
            EnvDir                = $flowConfigEntry.EnvDirPath
            Config                = $script:config
            DiscoveredEntities    = $discovered
            DiscoveredEntityIndex = $index
        }

        $entities = Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -ProvenancePath $flowConfigEntry.ConfigPath -Context $context
        ($entities | Where-Object { $_.Key -eq 'lib_common' }).Tasks | Should -Be @('CommonBuild')
        ($entities | Where-Object { $_.Key -eq 'lib_override' }).Tasks | Should -Be @('Info')
        ($entities | Where-Object { $_.Key -eq 'dev_script' }).Runner | Should -Be 'bashscript'

        $buildEntities = Get-JaxBuildRunEntities -FlowConfig $flowConfig -Context $context -ProvenancePath $flowConfigEntry.ConfigPath
        ($buildEntities | Where-Object { $_.Tasks -contains 'CommonBuild' }).PsakeFile | Should -Be (Join-Path $script:fixtureRoot 'env/common/psakefile.ps1')
        ($buildEntities | Where-Object { $_.Tasks -contains 'DevOnly' }).PsakeFile | Should -Be (Join-Path $script:fixtureRoot 'env/jax_client/dev/psakefile.ps1')
    }
}
