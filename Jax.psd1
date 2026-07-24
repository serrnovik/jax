@{
    RootModule = 'Jax.psm1'
    ModuleVersion = '0.1.5'
    GUID = '1ea40670-b2f8-4daa-bc38-724f570ee4d9'
    Author = 'Sergey Novikov <sergey@novik.fr>'
    Copyright = 'Copyright 2026 Sergey Novikov'
    Description = 'Repository-independent PowerShell task and environment runner.'
    PowerShellVersion = '7.2'
    RequiredModules = @(
        @{
            ModuleName = 'powershell-yaml'
            RequiredVersion = '0.4.12'
        }
    )
    FunctionsToExport = @(
        'Get-JaxUpdateStatus'
        'Install-JaxShellIntegration'
        'Invoke-Jax'
        'Invoke-JaxShortcut'
        'Register-JaxCompletion'
    )
    AliasesToExport = @('jax', 'jx', 'jxs')
    CmdletsToExport = @()
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('automation', 'cli', 'powershell', 'psake', 'tasks')
            ProjectUri = 'https://github.com/serrnovik/jax'
            LicenseUri = 'https://github.com/serrnovik/jax/blob/main/LICENSE'
            ReleaseNotes = 'Activates source installs immediately and configures PowerShell, zsh, and bash integration automatically.'
        }
    }
}
