function Convert-ToJaxAnsiColorSequence {
    [CmdletBinding()]
    param(
        [string] $Color,
        [switch] $IsBackground
    )

    if ([string]::IsNullOrWhiteSpace($Color)) {
        return $null
    }

    if ($Color.StartsWith('#')) {
        return Get-JaxAnsiColor -HexColor $Color -IsBackground:$IsBackground
    }

    return $null
}
