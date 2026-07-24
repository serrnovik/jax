BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
    . (Join-Path $PSScriptRoot '../jax.auto-completion.ps1')
}

Describe 'Completion helpers' {
    It 'returns core flags and plugin flags' {
        InModuleScope Jax.Core {
            $script:JaxCliParameterRegistry = @()
            $script:JaxCliParameterDefaultsAdded = $false
        }

        $flags = Get-JaxCompletionFlags
        $flags | Should -Contain '-env'

        Register-JaxCliParameter -Name 'pluginFlag' -Aliases @('pf') -Type 'switch' -Scope 'plugin'
        $flags = Get-JaxCompletionFlags
        $flags | Should -Contain '-pluginflag'
        $flags | Should -Contain '-pf'
    }

    It 'returns base commands and help entries' {
        InModuleScope Jax.Core {
            $script:JaxHelpRegistry = @()
        }

        Register-JaxHelpEntry -Name 'demo' -Summary 'Demo command'
        $commands = Get-JaxCompletionCommands
        $commands | Should -Contain 'run'
        $commands | Should -Contain 'plan'
        $commands | Should -Contain 'skill'
        $commands | Should -Contain 'info'
        $commands | Should -Contain 'vault'
        $commands | Should -Contain 'demo'
    }

    It 'includes dummy env in env completion choices' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionEnvChoices -StartsWith ''
            @($choices | Select-Object -ExpandProperty Name) | Should -Contain 'none'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'keeps computed env names with slashes intact when no flow exists' {
        $envs = @(
            [pscustomobject]@{
                Name        = 'build/sample-module'
                FlowConfigs = @()
            }
        )
        $selection = Get-JaxEnvAndFlowSelectionForCompletion -EnvWithOptionalFlow 'build/sample-module' -Environments $envs
        $selection.Environment.Name | Should -Be 'build/sample-module'
        $selection.FlowOverride | Should -Be $null
    }

    It 'prefers short computed build env names in env completion when unique' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $moduleDir = Join-Path $tempRoot 'code/operations/backups'
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
        Set-Content -Path (Join-Path $moduleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: false
  conventionalEnvRoots:
    - code
  autocomplete:
    clientIcons:
      operations: 'OPS'
    flowIcons:
      backups: 'BAK'
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionEnvChoices -StartsWith ''
            $names = @($choices | Select-Object -ExpandProperty Name)
            $names | Should -Contain 'operations/backups'
            $names | Should -Not -Contain 'build/operations/backups'
            ($choices | Where-Object { $_.Name -eq 'operations/backups' } | Select-Object -First 1).DisplayText | Should -Be 'OPS BAK operations/backups'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'uses rooted computed build env names in env completion when short names collide' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $codeModuleDir = Join-Path $tempRoot 'code/operations/backups'
        $toolsModuleDir = Join-Path $tempRoot 'tools/operations/backups'
        New-Item -ItemType Directory -Path $codeModuleDir -Force | Out-Null
        New-Item -ItemType Directory -Path $toolsModuleDir -Force | Out-Null
        Set-Content -Path (Join-Path $codeModuleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii
        Set-Content -Path (Join-Path $toolsModuleDir 'psakefile.ps1') -Value "task default { }" -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: false
  buildEnvRoots:
    - code
    - tools
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionEnvChoices -StartsWith ''
            $names = @($choices | Select-Object -ExpandProperty Name)
            $names | Should -Contain 'code/operations/backups'
            $names | Should -Contain 'tools/operations/backups'
            $names | Should -Not -Contain 'operations/backups'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'uses displayed computed build env path segments for completion icons' {
        $displayText = Get-JaxCompletionComputedEnvDisplay -Value 'play/openai' -ClientIcons @{ play = 'PLAY' } -FlowIcons @{ openai = 'AI' } -FallbackIcon 'BUILD'

        $displayText | Should -Be 'PLAY AI play/openai'
    }

    It 'includes dummy env when env root exists' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $flowDir = Join-Path $tempRoot 'env/client1/flows'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        @'
suite:
  scenarios:
    default:
      - Example
'@ | Set-Content -Path (Join-Path $flowDir 'build.yml') -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: true
    name: none
    skipEnvRoot: true
  flowDirNames:
    - flows
  flowFilePatterns:
    - "*.yml"
    - "*.yaml"
  commonDirName: common
  scenarioLibDirName: scenarios-lib
  tasks:
    psakeFilePattern: psakefile*.ps1
    nonConventionalDirs: []
  scripts:
    dirNames:
      - scripts
    nonConventionalDirs: []
  modulePathInGit: {}
  taskIgnoreList: []
  aliases: {}
  plugins:
    enabled:
      - bob
    disabled: []
    paths: []
    config: {}
  cache:
    enabled: true
    dir: .jax/cache
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionEnvChoices -StartsWith ''
            @($choices | Select-Object -ExpandProperty Name) | Should -Contain 'none'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'completes tasks for dummy env using non-conventional discovery' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $extraDir = Join-Path $tempRoot 'tasks/extra'
        New-Item -ItemType Directory -Path $extraDir -Force | Out-Null
        @'
task Hello {
}
'@ | Set-Content -Path (Join-Path $extraDir 'psakefile-extra.ps1') -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: true
    name: none
    skipEnvRoot: true
  tasks:
    psakeFilePattern: psakefile*.ps1
    nonConventionalDirs:
      - tasks/extra
  scripts:
    dirNames:
      - scripts
    nonConventionalDirs: []
  flowDirNames:
    - flows
    - boss
  flowFilePatterns:
    - "*.yml"
    - "*.yaml"
  commonDirName: common
  scenarioLibDirName: scenarios-lib
  modulePathInGit: {}
  taskIgnoreList: []
  aliases: {}
  plugins:
    enabled:
      - bob
    disabled: []
    paths: []
    config: {}
  cache:
    enabled: true
    dir: .jax/cache
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionTaskKeys -EnvName 'none'
            @($choices | Select-Object -ExpandProperty Name) | Should -Contain 'Hello'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'includes tasks defined under suite.build entries in completion' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $flowDir = Join-Path $tempRoot 'env/acme/flows'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        @'
suite:
  build:
    sample-module:
      tasks:
        - BuildAiAgentsCommon
        - TestAiAgentsCommon
'@ | Set-Content -Path (Join-Path $flowDir 'build.yml') -Encoding ascii

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        New-Item -ItemType Directory -Path (Split-Path $repoConfigPath -Parent) -Force | Out-Null
        @'
jax:
  envRoot: env
  dummyEnv:
    enabled: true
    name: none
    skipEnvRoot: true
  flowDirNames:
    - flows
  flowFilePatterns:
    - "*.yml"
  commonDirName: common
  scenarioLibDirName: scenarios-lib
  tasks:
    psakeFilePattern: psakefile*.ps1
    nonConventionalDirs: []
  scripts:
    dirNames:
      - scripts
    nonConventionalDirs: []
  modulePathInGit: {}
  taskIgnoreList: []
  aliases: {}
  plugins:
    enabled:
      - bob
    disabled: []
    paths: []
    config: {}
  cache:
    enabled: true
    dir: .jax/cache
'@ | Set-Content -Path $repoConfigPath -Encoding ascii

        $previous = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $tempRoot
        try {
            $choices = Get-JaxCompletionTaskKeys -EnvName 'acme/build'
            $names = @($choices | Select-Object -ExpandProperty Name)
            $names | Should -Contain 'sample-module'
            $names | Should -Contain 'BuildAiAgentsCommon'
            $names | Should -Contain 'TestAiAgentsCommon'
        } finally {
            if ($null -ne $previous) {
                $env:JAX_REPO_ROOT = $previous
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'resolves subcommand even with leading flags' {
        $tokens = @('jax', '-e', 'none', 'run')
        (Get-JaxSubcommandFromTokens $tokens) | Should -Be 'run'
    }
}
