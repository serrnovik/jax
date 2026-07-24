@{
    RootModule = 'Jax.Plugin.Vault.psm1'
    ModuleVersion = '0.0.1'
    GUID = '1e2d3c4b-5a6f-7e8d-9c0b-1a2b3c4d5e6f'
    Author = 'Jax contributors'
    CompanyName = 'Jax'
    Copyright = '(c) 2026 Jax contributors'
    Description = 'HashiCorp Vault integration plugin for JAX.'
    FunctionsToExport = @(
        'Register-JaxVaultPlugin',
        'Connect-JaxVault',
        'Get-JaxVaultStatus',
        'Reset-JaxVault',
        'Set-JaxVaultToken'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('Set-VaultToken')
}
