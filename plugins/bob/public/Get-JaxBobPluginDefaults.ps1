function Get-JaxBobPluginDefaults {
    [CmdletBinding()]
    param ()

    return @{
        fileBaseNames          = @('jaxfile')
        fileExtensions         = @('yml', 'yaml')
        defaults               = @{}
        expandVariables        = $true
        ignoreMissingPlaceholders = $false
        git                    = @{
            require  = $true
            allowInit = $true
            prompt   = $true
        }
        layers                 = @{
            repoCommonPatterns   = @('configs/jax/common/*.yml', 'configs/jax/common/*.yaml')
            localOverridePatterns = @('configs/jax/local-override*.yml', 'configs/jax/local-override*.yaml')
            ciOverridePatterns    = @('configs/jax/ci-*.yml', 'configs/jax/ci-*.yaml')
            flavourDir            = 'configs/jax-flavours'
            flavourPatterns       = @('*.yml', '*.yaml')
            ciEnvVars             = @('CI')
            overrides             = @{}
        }
    }
}
