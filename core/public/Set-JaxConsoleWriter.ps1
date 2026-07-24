function Set-JaxConsoleWriter {
    [CmdletBinding()]
    param (
        [scriptblock] $Writer
    )

    $script:JaxConsoleWriter = $Writer
}
