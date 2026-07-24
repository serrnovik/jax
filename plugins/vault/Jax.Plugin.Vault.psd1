@{
    RootModule = 'Jax.Plugin.Vault.psm1'
    ModuleVersion = '0.0.1'
    GUID = '1e2d3c4b-5a6f-7e8d-9c0b-1a2b3c4d5e6f'
    Author = 'Sergey Novikov'
    CompanyName = 'Jax'
    Copyright = 'Copyright 2026 Sergey Novikov'
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
