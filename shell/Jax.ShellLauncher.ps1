Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-JaxShellModuleManifest {
    if (-not [string]::IsNullOrWhiteSpace($env:JAX_MODULE_PATH)) {
        $candidate = $env:JAX_MODULE_PATH
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $candidate = Join-Path $candidate 'Jax.psd1'
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    # A source install is an explicit local override. Prefer it to a Gallery
    # module even when a zsh/bash wrapper was sourced without its generated
    # profile block.
    $sourceInstall = Join-Path $HOME '.jax/module/Jax.psd1'
    if (Test-Path -LiteralPath $sourceInstall -PathType Leaf) {
        return $sourceInstall
    }

    $available = Get-Module -ListAvailable -Name Jax |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($null -ne $available) {
        return $available.Path
    }

    throw 'Jax is not installed. Run: Install-PSResource Jax -Scope CurrentUser -TrustRepository'
}

try {
    $manifestPath = Resolve-JaxShellModuleManifest
    $moduleRoot = Split-Path -Parent $manifestPath
    $entryPoint = if ($env:JAX_SHELL_ENTRYPOINT -eq 'jxs') { 'jxs.ps1' } else { 'jax.ps1' }
    & (Join-Path $moduleRoot $entryPoint) @args
    if ($null -ne $LASTEXITCODE) {
        exit $LASTEXITCODE
    }
} catch {
    [Console]::Error.WriteLine("jax: $($_.Exception.Message)")
    exit 1
}
