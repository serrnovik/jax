function Write-JaxConsoleLine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [string] $Color,
        [string] $BackgroundColor,
        [switch] $NoNewline
    )

    $writerVar = Get-Variable -Name 'JaxConsoleWriter' -Scope Script -ErrorAction SilentlyContinue
    if ($writerVar -and $writerVar.Value -is [scriptblock]) {
        try {
            & $writerVar.Value -Text $Text -Color $Color -BackgroundColor $BackgroundColor -NoNewline:$NoNewline
            return
        } catch {
        }
    }

    $params = @{
        Object    = $Text
        NoNewline = $NoNewline
    }

    if (-not [string]::IsNullOrWhiteSpace($Color)) {
        try {
            $consoleColor = [System.Enum]::Parse([System.ConsoleColor], $Color, $true)
            $params['ForegroundColor'] = $consoleColor
        } catch {
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($BackgroundColor)) {
        try {
            $consoleColor = [System.Enum]::Parse([System.ConsoleColor], $BackgroundColor, $true)
            $params['BackgroundColor'] = $consoleColor
        } catch {
        }
    }

    Write-Host @params
}
