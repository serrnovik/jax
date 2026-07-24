function Get-JaxRepoConfigTemplate {
    [CmdletBinding()]
    param ()

    # Keep this repository contract concise and ordered. Internal defaults may
    # contain additional implementation details, but new consumers should see
    # the settings that define layout, discovery, UX, and enabled capabilities.
    return [ordered]@{
        envRoot             = 'env'
        commonDirName       = 'common'
        flowDirNames        = @('flows')
        flowFilePatterns    = @('*.yml', '*.yaml')
        scenarioLibDirName  = 'scenarios-lib'
        buildSectionNames   = @('build', 'modules')
        conventionalEnvRoots = @('code')
        dummyEnv            = [ordered]@{
            enabled     = $true
            name        = 'none'
            skipEnvRoot = $true
        }
        tasks               = [ordered]@{
            psakeFilePattern = 'psakefile*.ps1'
        }
        scripts             = [ordered]@{
            dirNames = @('scripts')
        }
        autocomplete        = [ordered]@{
            clientIcons = [ordered]@{
                none    = '🚫'
                build   = '👷'
                generic = '🌐'
                demo    = '🧪'
                sample  = '📁'
            }
            flowIcons   = [ordered]@{
                play  = '🧪'
                build = '🔨'
                pack  = '📦'
            }
        }
        plugins             = [ordered]@{
            enabled = @('machine', 'bob', 'vault', 'docker')
            config  = [ordered]@{
                vault = [ordered]@{
                    enabled   = $false
                    authMount = 'github'
                }
            }
        }
        cache               = [ordered]@{
            enabled = $true
            dir     = '.jax/cache'
        }
    }
}
