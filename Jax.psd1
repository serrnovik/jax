@{
    RootModule = 'Jax.psm1'
    ModuleVersion = '0.1.19'
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
            ReleaseNotes = '0.1.19: A [bool] task property overridden as text now reaches psake as a real Boolean. When DynamicParam could not bind a flag, `-flag:$false`, `-flag:False` or `-flag:0` arrived as the string ''False'': binding it to any [bool] parameter threw "Cannot convert value System.String to type System.Boolean", and `if ($flag)` treated it as true. Resolve-JaxPsakeProperties now converts every property the entity declares as [bool] (from the CLI, a flow `args:` value or run-config) with Convert-JaxCliSwitchValue, which also reads a literal `$false`/`$true` from a POSIX shell.'
        }
    }
}
