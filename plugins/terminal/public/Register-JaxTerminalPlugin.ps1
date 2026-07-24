function Register-JaxTerminalPlugin {
    Initialize-JaxTerminalColorMap

    $writer = {
        param(
            [string] $Text,
            [string] $Color,
            [string] $BackgroundColor,
            [switch] $NoNewline
        )
        Write-JaxTerminalHostColor -Text $Text -Color $Color -BackgroundColor $BackgroundColor -NoNewline:$NoNewline
    }

    Set-JaxConsoleWriter -Writer $writer

    $sourcePath = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        $sourcePath = $MyInvocation.MyCommand.ScriptBlock.File
    }
    Register-JaxPlugin -Name 'terminal' -Hooks @{} -SourcePath $sourcePath
}
