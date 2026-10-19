function Get-JaxTaskPatternSpan {
    <#
    .SYNOPSIS
    Where a search pattern matches inside a task name, for highlighting.
    .DESCRIPTION
    Mirrors Test-JaxTaskPatternMatch: case-insensitive, * and ? are wildcards.
    Returns @{ Index; Length } of the first match, or $null when the pattern does
    not match or matches nothing visible (e.g. a bare '*').
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $Pattern
    )

    $regex = -join @(
        foreach ($ch in $Pattern.Trim().ToCharArray()) {
            switch ($ch) {
                '*' { '.*?' }
                '?' { '.' }
                default { [regex]::Escape([string]$ch) }
            }
        }
    )
    # Leading/trailing * add nothing to the highlighted span.
    $regex = $regex -replace '^(\.\*\?)+', '' -replace '(\.\*\?)+$', ''
    if ([string]::IsNullOrEmpty($regex)) { return $null }

    $match = [regex]::Match($Name, $regex, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success -or $match.Length -eq 0) { return $null }
    return @{ Index = $match.Index; Length = $match.Length }
}
