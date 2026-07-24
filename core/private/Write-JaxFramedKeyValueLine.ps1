function Write-JaxFramedKeyValueLine {
    [CmdletBinding()]
    param (
        [string] $Label,
        [string] $Value,
        [int] $MaxLen,
        [string] $FrameColor = 'DarkGray',
        [string] $LabelColor = 'DarkGray',
        [string] $ValueColor = 'White',
        [string] $Separator = ': ',
        [int] $ValueVisibleLength
    )

    $text = $Label
    $visibleLen = $Label.Length
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $text = "{0}{1}{2}" -f $Label, $Separator, $Value
        $vLen = if ($PSBoundParameters.ContainsKey('ValueVisibleLength')) { $ValueVisibleLength } else { $Value.Length }
        $visibleLen += $Separator.Length + $vLen
    }
    $padding = ''
    if ($MaxLen -gt $visibleLen) {
        $padding = ' ' * ($MaxLen - $visibleLen)
    }

    Write-JaxConsoleLine -Text '┃ ' -Color $FrameColor -NoNewline
    if (-not [string]::IsNullOrWhiteSpace($Label)) {
        $labelText = if ([string]::IsNullOrWhiteSpace($Value)) { $Label } else { "{0}{1}" -f $Label, $Separator }
        Write-JaxConsoleLine -Text $labelText -Color $LabelColor -NoNewline
    }
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        Write-JaxConsoleLine -Text $Value -Color $ValueColor -NoNewline
    }
    if (-not [string]::IsNullOrEmpty($padding)) {
        Write-JaxConsoleLine -Text $padding -Color $ValueColor -NoNewline
    }
    Write-JaxConsoleLine -Text ' ┃' -Color $FrameColor
}
