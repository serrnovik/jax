function ConvertTo-JaxUtcDate {
    <#
    .SYNOPSIS
        Parse a round-trip ("O") timestamp into UTC, returning $null when the
        value is missing or malformed.
    #>
    [CmdletBinding()]
    param (
        $Value
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $parsed = [DateTime]::MinValue
    $parsedOk = [DateTime]::TryParse(
        $text,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AdjustToUniversal,
        [ref] $parsed
    )
    if (-not $parsedOk -or $parsed -eq [DateTime]::MinValue) {
        return $null
    }

    return $parsed.ToUniversalTime()
}
