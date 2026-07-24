function Expand-JaxCliShortcut {
    <#
    .SYNOPSIS
        Load saved args for -Shortcut/-sc, merge with extra CommandArgs, return new Command + CommandArgs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [hashtable] $CommonParams,
        [string] $Command,
        [string[]] $CommandArgs,
        [string] $RepoRoot
    )

    $repoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Get-JaxRepoRoot @CommonParams } else { $RepoRoot }
    $shortcutConfig = Get-JaxConfig -RepoRoot $repoRoot @CommonParams
    $shortcuts = @{}
    if ($shortcutConfig.Contains('shortcuts') -and $shortcutConfig['shortcuts'] -is [System.Collections.IDictionary]) {
        $shortcuts = $shortcutConfig['shortcuts']
    }
    if (-not $shortcuts.Contains($Name)) {
        $available = ($shortcuts.Keys | Sort-Object) -join ', '
        throw "Shortcut '$Name' not found in .jax/jax.config.yml. Available: $available"
    }

    $savedArgs = @($shortcuts[$Name])
    Write-Host "▶ Expanding shortcut '$Name': $($savedArgs -join ' ')"

    $expandedArgs = $savedArgs + @($CommandArgs)
    $newCommand = $expandedArgs[0]
    $newCommandArgs = if ($expandedArgs.Count -gt 1) { $expandedArgs[1..($expandedArgs.Count - 1)] } else { @() }

    return [pscustomobject]@{
        Command     = $newCommand
        CommandArgs = $newCommandArgs
    }
}
