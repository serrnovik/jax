function Invoke-JaxCreateFlavour {
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $Description,
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [switch] $Force,
        [System.Collections.Queue] $InputQueue
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Read-JaxPromptString -Prompt 'flavour name' -Default '' -InputQueue $InputQueue
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Flavour name is required."
    }

    if ([string]::IsNullOrWhiteSpace($Description)) {
        $Description = Read-JaxPromptString -Prompt 'flavour description' -Default '' -InputQueue $InputQueue
    }

    $config = Get-JaxConfig -RepoRoot $RepoRoot -SkipUserConfig
    $flavourDir = 'configs/jax-flavours'
    if ($config.plugins -and $config.plugins.config -and $config.plugins.config.bob -and $config.plugins.config.bob.layers -and $config.plugins.config.bob.layers.flavourDir) {
        $flavourDir = $config.plugins.config.bob.layers.flavourDir
    }

    $flavourDir = Resolve-JaxRepoRootedPath -Path $flavourDir -RepoRoot $RepoRoot
    if (-not (Test-Path -Path $flavourDir -PathType Container)) {
        New-Item -ItemType Directory -Path $flavourDir -Force | Out-Null
    }

    $fileName = $Name.Trim()
    if (-not ($fileName -match '\.(yml|yaml)$')) {
        $fileName = ($fileName -replace '\s+', '-') -replace '[^\w\.-]', '-'
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = 'flavour'
        }
        $fileName = $fileName.ToLowerInvariant() + '.yml'
    }

    $filePath = Join-Path $flavourDir $fileName
    if ((Test-Path -Path $filePath -PathType Leaf) -and -not $Force) {
        throw "Flavour file already exists: $filePath"
    }

    $safeName = $Name.Replace('"', "'")
    $safeDescription = $Description.Replace('"', "'")
    @"
name: "$safeName"
description: "$safeDescription"
# override example:
# module:
#   build:
#     configuration: "Release"
"@ | Set-Content -Path $filePath -Encoding ascii

    return $filePath
}
