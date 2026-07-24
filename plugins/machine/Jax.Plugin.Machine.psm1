function Get-JaxMachineInfo {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [string] $EnvRoot
    )

    $os = 'unknown'
    if ($IsWindows) { $os = 'windows' }
    elseif ($IsMacOS) { $os = 'macos' }
    elseif ($IsLinux) { $os = 'linux' }

    $gitAvailable = $false
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        $gitAvailable = $true
    }

    $cwd = (Get-Location).Path
    $home = $HOME

    return @{
        os           = $os
        pwshVersion  = $PSVersionTable.PSVersion.ToString()
        gitAvailable = $gitAvailable
        shell        = $env:SHELL
        hostname     = $env:COMPUTERNAME
        user         = $env:USER
        repoRoot     = $RepoRoot
        envRoot      = $EnvRoot
        cwd          = $cwd
        home         = $home
    }
}

function Register-JaxMachinePlugin {
    $hooks = @{
        BeforeSequenceResolve = {
            param($hook)
            if (-not $hook.Context.ContainsKey('Machine')) {
                $repoRoot = $hook.Context['RepoRoot']
                if ([string]::IsNullOrWhiteSpace($repoRoot)) {
                    $repoRoot = Get-JaxRepoRoot
                }
                $envRoot = $repoRoot
                if ($hook.Config -and $hook.Config.ContainsKey('envRoot')) {
                    $envRoot = Join-Path $repoRoot $hook.Config['envRoot']
                }
                $hook.Context['Machine'] = Get-JaxMachineInfo -RepoRoot $repoRoot -EnvRoot $envRoot
            }
        }
    }

    Register-JaxPlugin -Name 'machine' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxMachinePlugin
