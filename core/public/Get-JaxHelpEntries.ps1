function Get-JaxHelpEntries {
    [CmdletBinding()]
    param ()

    Initialize-JaxHelpRegistry

    return @($script:JaxHelpRegistry)
}
