function Get-JaxBuiltinPluginPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $normalized = $Name.ToLower()
    $map = @{
        bob      = 'Jax.Plugin.Bob.psm1'
        cleaning = 'Jax.Plugin.Cleaning.psm1'
        coverage = 'Jax.Plugin.Coverage.psm1'
        machine  = 'Jax.Plugin.Machine.psm1'
        teamcity = 'Jax.Plugin.Teamcity.psm1'
        vault    = 'Jax.Plugin.Vault.psm1'
        dotenv   = 'Jax.Plugin.Dotenv.psm1'
        dotnet   = 'Jax.Plugin.Dotnet.psm1'
        node     = 'Jax.Plugin.Node.psm1'
        docker   = 'Jax.Plugin.Docker.psm1'
        packaging = 'Jax.Plugin.Packaging.psm1'
        tests    = 'Jax.Plugin.Tests.psm1'
        helm     = 'Jax.Plugin.Helm.psm1'
        publish  = 'Jax.Plugin.Publish.psm1'
    }

    if (-not $map.ContainsKey($normalized)) {
        return $null
    }

    $pluginsRoot = Join-Path $PSScriptRoot '..' '..' 'plugins' $normalized
    return (Join-Path $pluginsRoot $map[$normalized])
}
