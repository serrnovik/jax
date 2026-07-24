function Initialize-JaxHelpRegistry {
    [CmdletBinding()]
    param ()

    if (-not (Get-Variable -Name JaxHelpRegistry -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxHelpRegistry = @()
    }
}
