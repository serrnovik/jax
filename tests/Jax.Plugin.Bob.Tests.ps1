BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    $pluginPath = Join-Path $PSScriptRoot '../plugins/bob/Jax.Plugin.Bob.psm1'
    Import-Module $coreModulePath -Force
    Import-Module $pluginPath -Force -DisableNameChecking
}

Describe 'Merge-JaxRunConfigLayers' {
    It 'merges layers in precedence order' {
        $defaults = @{
            value  = 'default'
            nested = @{
                key = 'default'
            }
        }
        $runConfig = @{
            value  = 'run'
            nested = @{
                key   = 'run'
                extra = 'run'
            }
        }
        $envConfig = @{ value = 'env' }
        $repoConfig = @{ value = 'repo' }
        $userConfig = @{ value = 'user' }
        $cliOverrides = @{ value = 'cli' }

        $result = Merge-JaxRunConfigLayers `
            -Defaults $defaults `
            -RunConfig $runConfig `
            -EnvConfig $envConfig `
            -RepoConfig $repoConfig `
            -UserConfig $userConfig `
            -CliOverrides $cliOverrides

        $result.value | Should -Be 'cli'
        $result.nested.key | Should -Be 'run'
        $result.nested.extra | Should -Be 'run'
    }
}

Describe 'Resolve-JaxRunConfigFile' {
    It 'uses jaxfile by default and supports explicit legacy bobfile opt-in' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        $jaxfile = Join-Path $tempRoot 'jaxfile.yml'
        $bobfile = Join-Path $tempRoot 'bobfile.yml'
        New-Item -ItemType File -Path $jaxfile | Out-Null
        New-Item -ItemType File -Path $bobfile | Out-Null

        $resolved = Resolve-JaxRunConfigFile -EnvDir $tempRoot -Config @{} -PluginConfig @{}
        $resolved | Should -Be (Resolve-Path $jaxfile).Path

        Remove-Item -Path $jaxfile -Force
        $resolvedLegacy = Resolve-JaxRunConfigFile -EnvDir $tempRoot -Config @{} `
            -PluginConfig @{ fileBaseNames = @('bobfile') }
        $resolvedLegacy | Should -Be (Resolve-Path $bobfile).Path

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Resolve-JaxRunConfigImports' {
    It 'applies imports with local values overriding' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        $importPath = Join-Path $tempRoot 'import.yml'
        $rootPath = Join-Path $tempRoot 'bobfile.yml'
        New-Item -ItemType File -Path $importPath | Out-Null
        New-Item -ItemType File -Path $rootPath | Out-Null

        $data = @{
            $importPath = @{
                nested = @{
                    key  = 'import'
                    keep = 'import'
                }
            }
            $rootPath   = @{
                import = @('import.yml')
                nested = @{
                    key = 'root'
                }
            }
        }

        $reader = {
            param($path)
            return $data[$path]
        }

        $resolved = Resolve-JaxRunConfigImports -Config $data[$rootPath] -ConfigPath $rootPath -RepoRoot $tempRoot -YamlReader $reader
        $resolved.nested.key | Should -Be 'root'
        $resolved.nested.keep | Should -Be 'import'
        $resolved.Keys | Should -Not -Contain 'import'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'allows duplicate shared imports (not a cycle)' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $cPath = Join-Path $tempRoot 'c.yml'
        $aPath = Join-Path $tempRoot 'a.yml'
        $bPath = Join-Path $tempRoot 'b.yml'
        $rootPath = Join-Path $tempRoot 'bobfile.yml'
        New-Item -ItemType File -Path $cPath | Out-Null
        New-Item -ItemType File -Path $aPath | Out-Null
        New-Item -ItemType File -Path $bPath | Out-Null
        New-Item -ItemType File -Path $rootPath | Out-Null

        $data = @{
            $cPath    = @{ c = 'c' }
            $aPath    = @{ import = @('c.yml'); a = 'a' }
            $bPath    = @{ import = @('c.yml'); b = 'b' }
            $rootPath = @{ import = @('a.yml', 'b.yml'); root = 'root' }
        }
        $reader = { param($path) $data[$path] }

        $resolved = Resolve-JaxRunConfigImports -Config $data[$rootPath] -ConfigPath $rootPath -RepoRoot $tempRoot -YamlReader $reader
        $resolved.root | Should -Be 'root'
        $resolved.a | Should -Be 'a'
        $resolved.b | Should -Be 'b'
        $resolved.c | Should -Be 'c'
        $resolved.Keys | Should -Not -Contain 'import'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'throws on true import cycles' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $aPath = Join-Path $tempRoot 'a.yml'
        $bPath = Join-Path $tempRoot 'b.yml'
        $rootPath = Join-Path $tempRoot 'bobfile.yml'
        New-Item -ItemType File -Path $aPath | Out-Null
        New-Item -ItemType File -Path $bPath | Out-Null
        New-Item -ItemType File -Path $rootPath | Out-Null

        $data = @{
            $aPath    = @{ import = @('b.yml'); a = 'a' }
            $bPath    = @{ import = @('a.yml'); b = 'b' }
            $rootPath = @{ import = @('a.yml'); root = 'root' }
        }
        $reader = { param($path) $data[$path] }

        { Resolve-JaxRunConfigImports -Config $data[$rootPath] -ConfigPath $rootPath -RepoRoot $tempRoot -YamlReader $reader } |
            Should -Throw -ExpectedMessage '*import cycle detected*'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Bob hook VariablesOverride' {
    It 'injects env.git.root into VariablesOverride' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $context = @{
            RepoRoot = $tempRoot
            Config   = $config
            EnvDir   = $null
        }

        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $false
        }
        Register-JaxBobPlugin

        Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $context -Data @{
            FlowConfig     = @{}
            Scenario       = $null
            FlowConfigPath = $null
        }

        $context.VariablesOverride.env.git.root | Should -Be (Resolve-Path $tempRoot).Path
        $context.VariablesOverride.env.build.counter | Should -Be 0
        $context.VariablesOverride.boss.suite.version.number | Should -Be '0.0.0'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'keeps fallback suite env when flow config omits env' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

        $config = Get-JaxConfig -RepoRoot $tempRoot -UserConfigPath (Join-Path $tempRoot 'no-user.yml')
        $context = @{
            RepoRoot    = $tempRoot
            Config      = $config
            EnvDir      = $null
            SelectedEnv = [pscustomobject]@{ Name = 'none' }
        }

        InModuleScope Jax.Core {
            $script:JaxPluginRegistry = @()
            $script:JaxPluginsLoaded = $false
        }
        Register-JaxBobPlugin

        Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $context -Data @{
            FlowConfig     = @{ suite = @{ version = @{ base = '1.0.0'; number = '1.0.0' } } }
            Scenario       = $null
            FlowConfigPath = $null
        }

        $context.VariablesOverride.boss.suite.env | Should -Be 'none'
        $context.VariablesOverride.flow.suite.env | Should -Be 'none'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Get-JaxBobEnvRunConfig' {
    It 'merges env hierarchy with lower levels overriding' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $envRoot = Join-Path $tempRoot 'env'
        $commonDir = Join-Path $envRoot 'common'
        $clientCommonDir = Join-Path $envRoot 'acme/common'
        $envDir = Join-Path $envRoot 'acme/dev'
        New-Item -ItemType Directory -Path $commonDir -Force | Out-Null
        New-Item -ItemType Directory -Path $clientCommonDir -Force | Out-Null
        New-Item -ItemType Directory -Path $envDir -Force | Out-Null

        $commonFile = Join-Path $commonDir 'jaxfile.yml'
        $clientCommonFile = Join-Path $clientCommonDir 'jaxfile.yml'
        $envFile = Join-Path $envDir 'jaxfile.yml'
        New-Item -ItemType File -Path $commonFile | Out-Null
        New-Item -ItemType File -Path $clientCommonFile | Out-Null
        New-Item -ItemType File -Path $envFile | Out-Null

        $data = @{
            $commonFile       = @{ value = 'common' }
            $clientCommonFile = @{ value = 'client' }
            $envFile          = @{ value = 'env' }
        }
        $reader = { param($path) $data[$path] }

        $config = @{
            envRoot       = 'env'
            commonDirName = 'common'
        }

        $result = Get-JaxBobEnvRunConfig -RepoRoot $tempRoot -EnvDir $envDir -Config $config -PluginConfig @{} -YamlReader $reader
        $result.Config.value | Should -Be 'env'
        $result.Paths | Should -Contain $envFile

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Get-JaxBobLayerConfig' {
    It 'merges repo layers in order' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $commonDir = Join-Path $tempRoot 'configs/jax/common'
        $localDir = Join-Path $tempRoot 'configs/jax'
        $flavourDir = Join-Path $tempRoot 'configs/jax-flavours'
        New-Item -ItemType Directory -Path $commonDir -Force | Out-Null
        New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        New-Item -ItemType Directory -Path $flavourDir -Force | Out-Null

        $commonFile = Join-Path $commonDir 'base.yml'
        $localFile = Join-Path $localDir 'local-override-dev.yml'
        $ciFile = Join-Path $localDir 'tc-dev.yml'
        $overrideFile = Join-Path $localDir 'ci-teamcity-override.yml'
        $flavourFile = Join-Path $flavourDir 'mint.yml'
        New-Item -ItemType File -Path $commonFile | Out-Null
        New-Item -ItemType File -Path $localFile | Out-Null
        New-Item -ItemType File -Path $ciFile | Out-Null
        New-Item -ItemType File -Path $overrideFile | Out-Null
        New-Item -ItemType File -Path $flavourFile | Out-Null

        $data = @{
            $commonFile   = @{ value = 'common' }
            $localFile    = @{ value = 'local' }
            $ciFile       = @{ value = 'ci' }
            $overrideFile = @{ value = 'override' }
            $flavourFile  = @{ value = 'flavour' }
        }
        $reader = { param($path) $data[$path] }

        $context = @{
            Ci       = $true
            Flavour  = 'mint'
            Override = 'teamcity'
        }

        $pluginConfig = @{
            layers = @{
                repoCommonPatterns    = @('configs/jax/common/*.yml')
                localOverridePatterns = @('configs/jax/local-override*.yml')
                ciOverridePatterns    = @('configs/jax/tc-*.yml')
                flavourDir            = 'configs/jax-flavours'
                flavourPatterns       = @('*.yml')
                overrides             = @{
                    teamcity = 'configs/jax/ci-teamcity-override.yml'
                }
            }
        }

        $result = Get-JaxBobLayerConfig -RepoRoot $tempRoot -PluginConfig $pluginConfig -Context $context -YamlReader $reader
        $result.Config.value | Should -Be 'flavour'
        $result.Paths.repoCommon | Should -Contain $commonFile
        $result.Paths.ciOverride | Should -Contain $ciFile
        $result.Paths.namedOverride | Should -Contain $overrideFile

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Bob build modules as run entities' {
    It 'treats suite.modules entries as module psake entities (null value means default task), not library refs' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $codeDir = Join-Path $tempRoot 'code'
        $m1Dir = Join-Path $codeDir 'build-simulation-1'
        $m2Dir = Join-Path $codeDir 'build-simulation-2'
        New-Item -ItemType Directory -Path $m1Dir -Force | Out-Null
        New-Item -ItemType Directory -Path $m2Dir -Force | Out-Null

        $m1Psake = Join-Path $m1Dir 'psakefile.ps1'
        $m2Psake = Join-Path $m2Dir 'psakefile.ps1'
        Set-Content -Path $m1Psake -Value "task default -depends Sink`n task Sink { }" -Encoding utf8
        Set-Content -Path $m2Psake -Value "task default -depends Sink`n task Sink { }" -Encoding utf8

        $m1Jaxfile = Join-Path $m1Dir 'jaxfile.yml'
        $m2Jaxfile = Join-Path $m2Dir 'jaxfile.yml'
        Set-Content -Path $m1Jaxfile -Value "---`nmodule:`n  public_name: 'build-simulation-1'`n" -Encoding utf8
        Set-Content -Path $m2Jaxfile -Value "---`nmodule:`n  public_name: 'build-simulation-2'`n" -Encoding utf8

        $flowConfig = @{
            suite = @{
                modules = @{
                    'build-simulation-1' = @{ tasks = @('Sink') }
                    'build-simulation-2' = $null
                }
            }
        }

        $context = @{
            RepoRoot          = $tempRoot
            VariablesOverride = @{
                env = @{
                    git = @{ root = $tempRoot }
                }
            }
        }

        $entities = Get-JaxBuildRunEntities -FlowConfig $flowConfig -Context $context -ProvenancePath (Join-Path $tempRoot 'env/test/boss/build.yml')
        $entities.Count | Should -Be 2

        $e1 = $entities | Where-Object { $_.Key -eq 'build-simulation-1' } | Select-Object -First 1
        $e2 = $entities | Where-Object { $_.Key -eq 'build-simulation-2' } | Select-Object -First 1

        $e1.Runner | Should -Be 'psake'
        $e1.PsakeFile | Should -Be (Resolve-Path $m1Psake).Path
        @($e1.Tasks).Count | Should -Be 1
        $e1.Args.module.public_name | Should -Be 'build-simulation-1'

        $e2.Runner | Should -Be 'psake'
        $e2.PsakeFile | Should -Be (Resolve-Path $m2Psake).Path
        @($e2.Tasks).Count | Should -Be 0
        $e2.Args.module.public_name | Should -Be 'build-simulation-2'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Bob run-config for computed envs' {
    It 'ignores repo common layers when SelectedEnv.IsComputed' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $envRoot = Join-Path $tempRoot 'env'
        New-Item -ItemType Directory -Path $envRoot -Force | Out-Null

        $moduleDir = Join-Path $tempRoot 'code/sample-ui'
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
        $moduleRunConfig = Join-Path $moduleDir 'jaxfile.yml'
        $moduleRootForYaml = $moduleDir.Replace('\', '/')
        @"
module:
  root: '$moduleRootForYaml'
"@ | Set-Content -Path $moduleRunConfig -Encoding ascii

        $repoCommonDir = Join-Path $tempRoot 'code/docker'
        New-Item -ItemType Directory -Path $repoCommonDir -Force | Out-Null
        $repoCommonRunConfig = Join-Path $repoCommonDir 'jaxfile.yml'
        $repoCommonRootForYaml = $repoCommonDir.Replace('\', '/')
        @"
module:
  root: '$repoCommonRootForYaml'
"@ | Set-Content -Path $repoCommonRunConfig -Encoding ascii

        $config = Get-JaxConfig -RepoRoot $tempRoot -SkipUserConfig
        $pluginConfig = @{
            layers = @{
                repoCommonPatterns = @('devops/docker/jaxfile*.yml')
            }
        }
        $context = @{
            SelectedEnv = [pscustomobject]@{
                IsComputed = $true
            }
        }

        $result = Get-JaxBobRunConfig `
            -RepoRoot $tempRoot `
            -EnvDir $moduleDir `
            -Config $config `
            -PluginConfig $pluginConfig `
            -Context $context

        $result.Config.module.root | Should -Be $moduleRootForYaml

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Bob scenarios-lib discovery and precedence' {
    It 'loads scenarios-lib from env/common then the selected environment and allows env overrides to win' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $envCommon = Join-Path $tempRoot 'env/common/scenarios-lib'
        $envSpecific = Join-Path $tempRoot 'env/sample-app/scenarios-lib'
        New-Item -ItemType Directory -Path $envCommon -Force | Out-Null
        New-Item -ItemType Directory -Path $envSpecific -Force | Out-Null

        $commonFile = Join-Path $envCommon 'common.yml'
        $specificFile = Join-Path $envSpecific 'dev.yml'
        Set-Content -Path $commonFile -Value "lib_override:`n  runner: psake`n  tasks:`n    - Info`n" -Encoding utf8
        Set-Content -Path $specificFile -Value "lib_override:`n  runner: psake`n  tasks:`n    - Test1`n" -Encoding utf8

        $flowConfig = @{ suite = @{} }
        $config = @{
            envRoot            = 'env'
            commonDirName      = 'common'
            scenarioLibDirName = 'scenarios-lib'
        }
        $context = @{
            VariablesOverride = @{
                env = @{
                    git = @{ root = $tempRoot }
                }
            }
        }

        $result = Get-JaxBobScenarioLibrary -RepoRoot $tempRoot -EnvDir (Join-Path $tempRoot 'env/sample-app') -Config $config -FlowConfig $flowConfig -PluginConfig @{} -Context $context
        $result.Library.lib_override.tasks[0] | Should -Be 'Test1'

        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Describe 'Bob sceny wrapper entity' {
    It 'wraps dict-with-steps scenarios as runner scenario entity so it can be targeted by -to/-from' {
        $flowConfig = @{
            suite = @{
                scenarios = @{
                    default = @{
                        sceny = @{
                            runner = 'scenario'
                            steps  = @{
                                lib_override = $null
                            }
                        }
                    }
                }
            }
        }

        $context = @{
            ScenarioLibrary = @{
                lib_override = @{
                    runner = 'psake'
                    tasks  = @('Info')
                }
            }
        }

        $entities = Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -Context $context -ProvenancePath '/tmp/build.yml'
        $sceny = $entities | Where-Object { $_.Key -eq 'sceny' } | Select-Object -First 1
        $sceny.Runner | Should -Be 'scenario'
        @($sceny.Entities).Count | Should -Be 1
    }
}
