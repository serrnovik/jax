function Get-JaxCliParameters {
    [CmdletBinding()]
    param ()

    Initialize-JaxCliParameterRegistry

    return @($script:JaxCliParameterRegistry)
}
