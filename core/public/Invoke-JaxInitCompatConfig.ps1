function Invoke-JaxInitCompatConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $Path,
        [switch] $Force
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Path=$Path"

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Get-JaxRepoConfigPath -RepoRoot $RepoRoot @commonParams
    }

    if ((Test-Path -Path $Path -PathType Leaf) -and -not $Force) {
        throw "Config already exists: $Path (use -Force to overwrite)."
    }

    $config = Get-JaxDefaultConfig @commonParams
    $config.flowDirNames = @('boss', 'flows')

    if (-not ($config.plugins -and $config.plugins.config -and $config.plugins.config.bob -and $config.plugins.config.bob.layers)) {
        $config.plugins = @{
            enabled  = @('machine', 'bob')
            disabled = @()
            config   = @{ bob = @{ layers = @{} } }
        }
    }

    $layers = $config.plugins.config.bob.layers
    $layers.repoCommonPatterns = @('code/bob-*-common.yml', 'code/bob-*-common.yaml')
    $layers.localOverridePatterns = @('code/bob-local-override*.yml', 'code/bob-local-override*.yaml')
    $layers.ciOverridePatterns = @('code/bob-tc-*.yml', 'code/bob-tc-*.yaml')
    $layers.flavourDir = 'configs/jax-flavours'
    $layers.flavourPatterns = @('*.yml', '*.yaml')

    $payload = @{ jax = $config }
    $configDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $configDir -PathType Container)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    Write-JaxYaml -Path $Path -InputObject $payload @commonParams
    return $Path
}
