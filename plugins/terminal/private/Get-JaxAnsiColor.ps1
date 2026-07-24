function Get-JaxAnsiColor {
    [CmdletBinding()]
    param(
        [string] $HexColor,
        [switch] $IsBackground
    )

    if ([string]::IsNullOrWhiteSpace($HexColor)) {
        return $null
    }
    $hex = $HexColor.Trim()
    if ($hex.StartsWith('#')) {
        $hex = $hex.Substring(1)
    }
    if ($hex.Length -ne 6) {
        return $null
    }

    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)

    $prefix = if ($IsBackground) { '48' } else { '38' }
    return "`e[$prefix;2;$r;$g;$b" + 'm'
}
