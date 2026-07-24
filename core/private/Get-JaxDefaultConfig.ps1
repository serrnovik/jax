function Get-JaxDefaultConfig {
    [CmdletBinding()]
    param ()

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    return @{
        envRoot            = 'env'
        dummyEnv           = @{
            enabled      = $true
            name         = 'none'
            skipEnvRoot  = $true
        }
        flowDirNames       = @('flows')
        flowFilePatterns   = @('*.yml', '*.yaml')
        buildSectionNames  = @('build', 'modules')
        conventionalEnvRoots = @('code')
        commonDirName      = 'common'
        scenarioLibDirName = 'scenarios-lib'
        tasks              = @{
            psakeFilePattern    = 'psakefile*.ps1'
            nonConventionalDirs = @()
        }
        scripts            = @{
            dirNames            = @('scripts')
            nonConventionalDirs = @()
        }
        modulePathInGit    = @{}
        taskIgnoreList     = @()
        aliases            = @{}
        shortcuts          = @{}
        autocomplete       = @{
            # Friendly CLI defaults. Users can override in .jax/jax.config.yml.
            clientIcons = @{
                demo    = '🧪'
                generic = '🌐'
                none    = '🚫'
                build   = '👷'
                sample  = '📁'
            }
            flowIcons   = @{
                build = '🔨'
                pack  = '📦'
                play  = '🧪'
            }
        }
        plugins            = @{
            enabled  = @('machine', 'bob', 'vault', 'docker')
            disabled = @('cleaning', 'dotenv', 'hi', 'nav', 'terminal', 'autocomplete', 'dotnet', 'node', 'packaging', 'tests', 'helm', 'publish')
            paths    = @()
            config   = @{
                bob                   = @{
                    fileBaseNames          = @('jaxfile')
                    fileExtensions         = @('yml', 'yaml')
                    defaults               = @{}
                    expandVariables        = $true
                    ignoreMissingPlaceholders = $false
                    git                    = @{
                        require   = $true
                        allowInit = $true
                        prompt    = $true
                    }
                    layers                 = @{
                        repoCommonPatterns    = @('configs/jax/common/*.yml', 'configs/jax/common/*.yaml')
                        localOverridePatterns = @('configs/jax/local-override*.yml', 'configs/jax/local-override*.yaml')
                        ciOverridePatterns    = @('configs/jax/ci-*.yml', 'configs/jax/ci-*.yaml')
                        flavourDir            = 'configs/jax-flavours'
                        flavourPatterns       = @('*.yml', '*.yaml')
                        ciEnvVars             = @('CI')
                        overrides             = @{}
                    }
                }
                cleaning              = @{
                    enabled = $false
                }
                machine               = @{}
                vault                 = @{
                    enabled   = $false
                    authMount = 'github'
                }
                dotenv                = @{
                    enabled = $false
                    files   = @('.env')
                }
                dotnet                = @{}
                node                  = @{}
                docker                = @{}
                packaging             = @{}
                tests                 = @{}
                helm                  = @{}
                publish               = @{}
            }
        }
        cache              = @{
            enabled = $true
            dir     = '.jax/cache'
        }
        moduleReload       = @{
            # Patterns (relative to RepoRoot) of module paths to exclude from force reload.
            # Use this to exclude problematic modules (e.g., those with Add-Type compilation issues).
            excludePathPatterns = @()
        }
    }
}
