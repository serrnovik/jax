@{
    RootModule = 'Jax.psm1'
    ModuleVersion = '0.1.20'
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
            ReleaseNotes = '0.1.20: `jax search <pattern>` finds tasks across every environment and prints the command that runs each one (`jx -e <env> run -o <task>`). The match is a case-insensitive substring; `*` and `?` are wildcards anywhere in the pattern, and `-e <env-pattern>` limits the environments. Tasks shared by many environments list three and a count. Discovering every environment takes a while, so in a git repository the task names are indexed in .jax/cache/task-index.json (git-ignored by its own .gitignore) and reused until a .ps1, .psm1, .yml or .yaml file changes, or Jax itself does; `--refresh` rebuilds it. Discovery is faster for every command: the eager `Write-Debug` argument dump no longer serialises arguments with ConvertTo-Json when debug output is off, the bundled psake module is no longer force-reimported for each discovered directory, and each psake file is parsed once per process instead of once per environment that includes it. list-tasks and search share Get-JaxEnvironmentTaskKeys.'
        }
    }
}
