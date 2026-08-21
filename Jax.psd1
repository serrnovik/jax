@{
    RootModule = 'Jax.psm1'
    ModuleVersion = '0.1.17'
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
            ReleaseNotes = '`jax update` replaces the managed install at ~/.jax/module with the latest PowerShell Gallery release. That path is the only copy the jax, jx and jxs shims load, so an `Update-PSResource Jax` landing anywhere on PSModulePath updates something none of them run; if such a copy exists the command reports it and offers to remove it, because a bare `Import-Module Jax` resolves to that one instead. The downloaded package installs itself by running its own Install-Jax.ps1, which now ships in the package along with the distribution manifest it copies from, so staging, backup, manifest validation and shell integration all come from the release being installed. Build-JaxPackage stamps Origin = Gallery into INSTALLATION.json and the installer carries it forward, so Jax can tell a published copy from one built out of a checkout, and the once-per-session update notice offers the command that updates the copy you are actually running instead of a hard-coded Update-PSResource line. A local build newer than the published release, or the same version, is reported as current rather than as a problem.'
        }
    }
}
