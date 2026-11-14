function Test-JaxVaultInputRedirected {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    return [Console]::IsInputRedirected
}
