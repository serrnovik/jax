$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# Load core modules
$jaxRoot = Resolve-Path (Join-Path $here '..')
Import-Module (Join-Path $jaxRoot 'core/Jax.Core.psm1') -Global -Force

# Load Docker Plugin
$pluginRoot = Join-Path $jaxRoot 'plugins/docker'
$pluginPath = Join-Path $pluginRoot 'Jax.Plugin.Docker.psm1'
Write-Host "Loading Docker Plugin from: $pluginPath"
Import-Module $pluginPath -Global -Force

Describe "Jax.Plugin.Docker" {
    Context "CLI parameter registration" {
        It "Registers compatibility Docker flags" {
            # Another test clears the CLI parameter registry; ensure docker re-registers its params here.
            Register-JaxDockerPlugin
            $defs = @(Get-JaxCliParameters)
            (@($defs | Where-Object { $_.Name -eq 'pushToDockerRegistry' }).Count) | Should -Be 1
            (@($defs | Where-Object { $_.Name -eq 'onlyLocalArch' }).Count) | Should -Be 1
            (@($defs | Where-Object { $_.Name -eq 'allArch' }).Count) | Should -Be 1
            (@($defs | Where-Object { $_.Name -eq 'pushLocal' }).Count) | Should -Be 1
            (@($defs | Where-Object { $_.Name -eq 'remoteBuildxK8s' }).Count) | Should -Be 1
        }
    }

    Context "Hook behavior" {
        It "Injects module.docker.push and module.docker.onlyLocalArch into Context.CliArgs" {
            InModuleScope Jax.Core {
                # Isolate plugin state (other tests may have loaded plugins already)
                $script:JaxPluginRegistry = @()
                $script:JaxPluginsLoaded = $false
                Register-JaxDockerPlugin

                $config = @{
                    plugins = @{
                        enabled  = @('docker')
                        disabled = @()
                        paths    = @()
                        config   = @{
                            docker = @{
                                defaults = @{
                                    local = @{ push = $false; onlyLocalArch = $false }
                                    ci    = @{ push = $true; onlyLocalArch = $false }
                                }
                            }
                        }
                    }
                }
                $ctx = @{
                    RepoRoot        = (Get-JaxRepoRoot)
                    Config          = $config
                    NoSavedSettings = $true
                    ResolvedOptions = @{}
                }

                Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $ctx -Data @{
                    Resolved = @{ pushToDockerRegistry = $true }
                }
                Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $ctx -Data @{
                    Entities = @()
                }

                $ctx.ContainsKey('CliArgs') | Should -BeTrue
                $ctx.CliArgs.module.docker.push | Should -BeTrue
                $ctx.CliArgs.module.docker.onlyLocalArch | Should -BeFalse
            }
        }

        It "Forces onlyLocalArch when push is false" {
            InModuleScope Jax.Core {
                # Isolate plugin state (other tests may have loaded plugins already)
                $script:JaxPluginRegistry = @()
                $script:JaxPluginsLoaded = $false
                Register-JaxDockerPlugin

                $config = @{
                    plugins = @{
                        enabled  = @('docker')
                        disabled = @()
                        config   = @{
                            docker = @{
                                defaults = @{
                                    local = @{ push = $false; onlyLocalArch = $false }
                                    ci    = @{ push = $true; onlyLocalArch = $false }
                                }
                            }
                        }
                    }
                }
                $ctx = @{
                    RepoRoot        = (Get-JaxRepoRoot)
                    Config          = $config
                    NoSavedSettings = $true
                    ResolvedOptions = @{}
                }

                Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $ctx -Data @{ Resolved = @{} }
                Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $ctx -Data @{ Entities = @() }

                $ctx.CliArgs.module.docker.push | Should -BeFalse
                $ctx.CliArgs.module.docker.onlyLocalArch | Should -BeTrue
            }
        }

        It "Allows overriding onlyLocalArch defaults via -allArch when pushing" {
            InModuleScope Jax.Core {
                # Isolate plugin state (other tests may have loaded plugins already)
                $script:JaxPluginRegistry = @()
                $script:JaxPluginsLoaded = $false
                Register-JaxDockerPlugin

                # Simulate local defaults with onlyLocalArch=true (your repo config)
                $config = @{
                    plugins = @{
                        enabled  = @('docker')
                        disabled = @()
                        config   = @{
                            docker = @{
                                defaults = @{
                                    local = @{ push = $false; onlyLocalArch = $true }
                                    ci    = @{ push = $true; onlyLocalArch = $false }
                                }
                            }
                        }
                    }
                }
                $ctx = @{
                    RepoRoot        = (Get-JaxRepoRoot)
                    Config          = $config
                    NoSavedSettings = $true
                    ResolvedOptions = @{}
                }

                Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $ctx -Data @{
                    Resolved = @{ pushToDockerRegistry = $true; allArch = $true }
                }
                Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $ctx -Data @{ Entities = @() }

                $ctx.CliArgs.module.docker.push | Should -BeTrue
                $ctx.CliArgs.module.docker.onlyLocalArch | Should -BeFalse
            }
        }

        It "Does not force onlyLocalArch when user explicitly sets -allArch without pushing" {
            InModuleScope Jax.Core {
                $script:JaxPluginRegistry = @()
                $script:JaxPluginsLoaded = $false
                Register-JaxDockerPlugin

                $config = @{
                    plugins = @{
                        enabled  = @('docker')
                        disabled = @()
                        config   = @{
                            docker = @{
                                defaults = @{
                                    local = @{ push = $false; onlyLocalArch = $false }
                                    ci    = @{ push = $true; onlyLocalArch = $false }
                                }
                            }
                        }
                    }
                }
                $ctx = @{
                    RepoRoot        = (Get-JaxRepoRoot)
                    Config          = $config
                    NoSavedSettings = $true
                    ResolvedOptions = @{}
                }

                Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $ctx -Data @{
                    Resolved = @{ allArch = $true }
                }
                Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $ctx -Data @{ Entities = @() }

                $ctx.CliArgs.module.docker.push | Should -BeFalse
                $ctx.CliArgs.module.docker.onlyLocalArch | Should -BeFalse
            }
        }

        It "Injects remote buildx kubernetes settings when -remoteBuildxK8s is set" {
            InModuleScope Jax.Core {
                $script:JaxPluginRegistry = @()
                $script:JaxPluginsLoaded = $false
                Register-JaxDockerPlugin

                $config = @{
                    plugins = @{
                        enabled  = @('docker')
                        disabled = @()
                        config   = @{
                            docker = @{
                                defaults = @{
                                    local = @{ push = $false; onlyLocalArch = $false }
                                    ci    = @{ push = $true; onlyLocalArch = $false }
                                }
                                remoteBuildxK8s = @{
                                    builderName         = "k8s-multiarch-builder"
                                    kubernetesNamespace = "ci-buildkit"
                                    kubeContext         = "admin@example-hetzner-1"
                                }
                            }
                        }
                    }
                }
                $ctx = @{
                    RepoRoot        = (Get-JaxRepoRoot)
                    Config          = $config
                    NoSavedSettings = $true
                    ResolvedOptions = @{}
                }

                Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $ctx -Data @{
                    Resolved = @{ pushToDockerRegistry = $true; remoteBuildxK8s = $true }
                }
                Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $ctx -Data @{ Entities = @() }

                $ctx.CliArgs.module.docker.buildx.remoteKubernetes | Should -BeTrue
                $ctx.CliArgs.module.docker.buildx.builderName | Should -Be "k8s-multiarch-builder"
                $ctx.CliArgs.module.docker.buildx.kubernetesNamespace | Should -Be "ci-buildkit"
                $ctx.CliArgs.module.docker.buildx.kubeContext | Should -Be "admin@example-hetzner-1"
            }
        }
    }
}
