function Get-JaxVaultInjectorTokenPath {
    <#
    .SYNOPSIS
        Path of the token file written by the Vault Agent Injector init container.

    .DESCRIPTION
        Standard path used by `vault.hashicorp.com/agent-inject-token=true`
        annotations. Wrapped as a function so tests can `Mock` it to redirect
        to a temp file (or to a non-existent path so the precedence tests can
        exercise the env/saved-file fallbacks).
    #>
    [CmdletBinding()]
    param()
    return '/vault/secrets/token'
}
