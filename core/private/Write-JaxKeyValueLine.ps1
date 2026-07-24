function Write-JaxKeyValueLine {
    [CmdletBinding()]
    param (
        [string] $Label,
        [string] $Value,
        [string] $LabelColor = 'DarkGray',
        [string] $ValueColor = 'White',
        [string] $Indent = ''
    )

    if ([string]::IsNullOrWhiteSpace($Label)) {
        $text = if ([string]::IsNullOrWhiteSpace($Value)) { '' } else { $Value }
        Write-JaxConsoleLine -Text ("{0}{1}" -f $Indent, $text)
        return
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-JaxConsoleLine -Text ("{0}{1}" -f $Indent, $Label) -Color $LabelColor
        return
    }

    Write-JaxConsoleLine -Text ("{0}{1}: " -f $Indent, $Label) -Color $LabelColor -NoNewline
    Write-JaxConsoleLine -Text $Value -Color $ValueColor
}
