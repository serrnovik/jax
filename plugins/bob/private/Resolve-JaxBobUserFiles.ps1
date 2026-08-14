<#
.SYNOPSIS
    Files for the per-developer config layer.

.DESCRIPTION
    A repository has three kinds of non-default configuration, and they are not
    the same thing:

      - the team's defaults, which everyone gets (repoCommon)
      - who you are, which follows you between your machines (this layer)
      - this machine, which follows nobody (localOverride)

    The middle one is the reason this exists. It is tracked, so it reaches your
    other desktop through git and a teammate can see why your runs differ; it is
    selected by identity, so having everyone's file checked in loads only yours.

    Patterns carry a {user} token. Identity is JAX_USER, else the OS user name,
    lowercased -- an explicit value first so a shared account or a CI box can
    say who it is standing in for.
#>
function Resolve-JaxBobUserFiles {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Layers,
        [string] $RepoRoot,
        [string] $UserName
    )

    if ($null -eq $Layers -or -not $Layers.ContainsKey('userPatterns')) {
        return @()
    }

    $patterns = @($Layers['userPatterns'] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($patterns.Count -eq 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = Get-JaxBobUserName
    }
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return @()
    }

    $resolvedPatterns = @($patterns | ForEach-Object {
        $_ -replace '\{user\}', $UserName -replace '\{USER\}', $UserName
    })

    return @(Resolve-JaxBobLayerFiles -Patterns $resolvedPatterns -RepoRoot $RepoRoot)
}
