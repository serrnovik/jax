function Invoke-JaxCustomizationWizard {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.Queue] $InputQueue
    )

    $baseConfig = Get-JaxConfig -RepoRoot $RepoRoot -SkipUserConfig

    $shouldCustomize = Read-JaxPromptBool -Prompt 'Create/update Jax repo config?' -Default $false -InputQueue $InputQueue
    if (-not $shouldCustomize) {
        return
    }

    $baseConfig.envRoot = Read-JaxPromptString -Prompt 'envRoot' -Default $baseConfig.envRoot -InputQueue $InputQueue
    $baseConfig.dummyEnv.enabled = Read-JaxPromptBool -Prompt 'dummyEnv.enabled' -Default $baseConfig.dummyEnv.enabled -InputQueue $InputQueue
    $baseConfig.dummyEnv.name = Read-JaxPromptString -Prompt 'dummyEnv.name' -Default $baseConfig.dummyEnv.name -InputQueue $InputQueue
    $baseConfig.dummyEnv.skipEnvRoot = Read-JaxPromptBool -Prompt 'dummyEnv.skipEnvRoot' -Default $baseConfig.dummyEnv.skipEnvRoot -InputQueue $InputQueue
    $baseConfig.flowDirNames = Read-JaxPromptList -Prompt 'flowDirNames (comma-separated)' -Default $baseConfig.flowDirNames -InputQueue $InputQueue
    $baseConfig.flowFilePatterns = Read-JaxPromptList -Prompt 'flowFilePatterns (comma-separated)' -Default $baseConfig.flowFilePatterns -InputQueue $InputQueue
    $baseConfig.buildSectionNames = Read-JaxPromptList -Prompt 'buildSectionNames (comma-separated)' -Default $baseConfig.buildSectionNames -InputQueue $InputQueue
    $baseConfig.conventionalEnvRoots = Read-JaxPromptList -Prompt 'conventionalEnvRoots (comma-separated)' -Default $baseConfig.conventionalEnvRoots -InputQueue $InputQueue

    $baseConfig.tasks.psakeFilePattern = Read-JaxPromptString -Prompt 'tasks.psakeFilePattern' -Default $baseConfig.tasks.psakeFilePattern -InputQueue $InputQueue
    $baseConfig.tasks.nonConventionalDirs = Read-JaxPromptList -Prompt 'tasks.nonConventionalDirs (comma-separated)' -Default $baseConfig.tasks.nonConventionalDirs -InputQueue $InputQueue

    $baseConfig.scripts.dirNames = Read-JaxPromptList -Prompt 'scripts.dirNames (comma-separated)' -Default $baseConfig.scripts.dirNames -InputQueue $InputQueue
    $baseConfig.scripts.nonConventionalDirs = Read-JaxPromptList -Prompt 'scripts.nonConventionalDirs (comma-separated)' -Default $baseConfig.scripts.nonConventionalDirs -InputQueue $InputQueue

    $baseConfig.modulePathInGit = Read-JaxPromptMap -Prompt 'modulePathInGit (key=value, comma-separated)' -Default $baseConfig.modulePathInGit -InputQueue $InputQueue
    $baseConfig.taskIgnoreList = Read-JaxPromptList -Prompt 'taskIgnoreList (comma-separated)' -Default $baseConfig.taskIgnoreList -InputQueue $InputQueue
    $baseConfig.aliases = Read-JaxPromptMap -Prompt 'aliases (key=value, comma-separated)' -Default $baseConfig.aliases -InputQueue $InputQueue

    $baseConfig.cache.enabled = Read-JaxPromptBool -Prompt 'cache.enabled' -Default $baseConfig.cache.enabled -InputQueue $InputQueue
    $baseConfig.cache.dir = Read-JaxPromptString -Prompt 'cache.dir' -Default $baseConfig.cache.dir -InputQueue $InputQueue

    $repoConfigPath = Get-JaxRepoConfigPath -RepoRoot $RepoRoot
    $repoConfigDir = Split-Path -Path $repoConfigPath -Parent
    if (-not (Test-Path -Path $repoConfigDir -PathType Container)) {
        New-Item -ItemType Directory -Path $repoConfigDir -Force | Out-Null
    }

    $payload = @{ jax = (Convert-JaxConfigForSave -Config $baseConfig) }
    Write-JaxYaml -Path $repoConfigPath -InputObject $payload
}
