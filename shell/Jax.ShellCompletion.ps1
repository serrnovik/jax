Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($args.Count -lt 2) {
    exit 0
}

try {
    $manifestPath = $null
    if (-not [string]::IsNullOrWhiteSpace($env:JAX_MODULE_PATH)) {
        $candidate = $env:JAX_MODULE_PATH
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $candidate = Join-Path $candidate 'Jax.psd1'
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $manifestPath = (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    if ([string]::IsNullOrWhiteSpace($manifestPath)) {
        $available = Get-Module -ListAvailable -Name Jax |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($null -ne $available) {
            $manifestPath = $available.Path
        }
    }
    if ([string]::IsNullOrWhiteSpace($manifestPath)) {
        $sourceInstall = Join-Path $HOME '.jax/module/Jax.psd1'
        if (Test-Path -LiteralPath $sourceInstall -PathType Leaf) {
            $manifestPath = $sourceInstall
        }
    }
    if ([string]::IsNullOrWhiteSpace($manifestPath)) {
        exit 0
    }

    $inputLine = [string]$args[0]
    $cursor = [Math]::Min([int]$args[1], $inputLine.Length)
    $moduleRoot = Split-Path -Parent $manifestPath
    . (Join-Path $moduleRoot 'jax.auto-completion.ps1')

    $inputPrefix = $inputLine.Substring(0, $cursor)
    $parseTokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput(
        $inputPrefix,
        [ref]$parseTokens,
        [ref]$parseErrors
    )
    $commandAst = $ast.Find(
        { param($node) $node -is [Management.Automation.Language.CommandAst] },
        $true
    )
    if ($null -eq $commandAst) {
        exit 0
    }

    $wordToComplete = ''
    if ($inputPrefix.Length -gt 0 -and $inputPrefix[-1] -notmatch '\s') {
        $lastElement = @($commandAst.CommandElements)[-1]
        if ($null -ne $lastElement -and $lastElement.Extent.EndOffset -eq $inputPrefix.Length) {
            $wordToComplete = $lastElement.ToString()
        }
    }

    $commandElements = @($commandAst.CommandElements | ForEach-Object ToString)
    $previousToken = $null
    if ($commandElements.Count -ge 2) {
        $previousToken = if ([string]::IsNullOrEmpty($wordToComplete)) {
            $commandElements[-1]
        } elseif ($commandElements.Count -ge 3) {
            $commandElements[-2]
        }
    }

    $completionResults = if ($previousToken -in @('-e', '-env')) {
        Get-JaxCompletionEnvChoices -StartsWith $wordToComplete | ForEach-Object {
            New-JaxCompletionResult -Value $_.Name -Display $_.DisplayText -ToolTip $_.ToolTip
        }
    } elseif ($wordToComplete -like '-*') {
        Get-JaxCompletionFlags |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object {
                [Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
            }
    } else {
        & $jaxCompleter 'jax' 'CommandArgs' $wordToComplete $commandAst @{}
    }

    foreach ($candidate in @($completionResults | ForEach-Object CompletionText | Sort-Object -Unique)) {
        [Console]::Out.WriteLine($candidate)
    }
} catch {
    # Completion is best-effort and must never make the interactive shell noisy.
    exit 0
}
