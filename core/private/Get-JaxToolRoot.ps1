function Get-JaxToolRoot {
    [CmdletBinding()]
    param ()

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path
}
