function Invoke-JaxInit {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $Client = 'sample',
        [string] $Env = 'dev',
        [Alias('BossConfig')]
        [string] $FlowConfig = 'build',
        [switch] $IncludeBobfile,
        [switch] $IncludeJaxfile,
        [switch] $Customize,
        [System.Collections.Queue] $InputQueue
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $configPath = Get-JaxRepoConfigPath -RepoRoot $RepoRoot @commonParams
    if (-not (Test-Path -Path $configPath -PathType Leaf)) {
        $configDir = Split-Path -Path $configPath -Parent
        if (-not (Test-Path -Path $configDir -PathType Container)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        # Write the concise repository contract, not every internal default.
        # This keeps layout and enabled capabilities visible to humans and
        # agents without pinning compatibility-only implementation details.
        $payload = [ordered]@{ jax = (Get-JaxRepoConfigTemplate @commonParams) }
        Write-JaxYaml -Path $configPath -InputObject $payload @commonParams
    }

    $jaxDir = Join-Path $RepoRoot '.jax'
    if (-not (Test-Path -Path $jaxDir -PathType Container)) {
        New-Item -ItemType Directory -Path $jaxDir -Force | Out-Null
    }
    $jaxGitIgnore = Join-Path $jaxDir '.gitignore'
    if (-not (Test-Path -Path $jaxGitIgnore -PathType Leaf)) {
        @'
state.yml
logs/
'@ | Set-Content -Path $jaxGitIgnore -Encoding ascii
    }

    $config = Get-JaxConfig -RepoRoot $RepoRoot -SkipUserConfig @commonParams
    $flowDirName = $config.flowDirNames | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($flowDirName)) {
        $flowDirName = 'flows'
    }

    Invoke-JaxEnvInit -RepoRoot $RepoRoot -Client $Client -Env $Env -DefaultFlow $FlowConfig `
        -AdditionalFlows @() -IncludeBobfile:$IncludeBobfile -IncludeJaxfile:$IncludeJaxfile `
        -EnableVault:$false -EnableDotenv:$false -IncludeState:$false @commonParams | Out-Null

    if ($Customize -or $null -ne $InputQueue) {
        Invoke-JaxCustomizationWizard -RepoRoot $RepoRoot -InputQueue $InputQueue @commonParams
    }
}
