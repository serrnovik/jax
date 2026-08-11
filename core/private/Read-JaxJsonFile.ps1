function Read-JaxJsonFile {
    <#
    .SYNOPSIS
        Read a JSON file, returning $null instead of throwing.
    .DESCRIPTION
        Used by best-effort local caches, where a missing, truncated, or
        concurrently rewritten file must behave exactly like "no data yet".
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}
