function Read-JaxDotEnvFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $result = @{}
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $result
    }

    foreach ($line in Get-Content -Path $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            continue
        }
        $parts = $trimmed.Split('=', 2)
        if ($parts.Count -lt 2) {
            continue
        }
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }
        $result[$key] = $value
    }

    return $result
}

function Register-JaxDotenvPlugin {
    $hooks = @{
        BeforeSequenceResolve = {
            param($hook)
            $config = $hook.PluginConfig
            if ($null -eq $config -or -not ($config.ContainsKey('enabled')) -or -not $config['enabled']) {
                return
            }

            $repoRoot = $hook.Context['RepoRoot']
            if ([string]::IsNullOrWhiteSpace($repoRoot)) {
                $repoRoot = Get-JaxRepoRoot
            }

            $files = @('.env')
            if ($config.ContainsKey('files')) {
                $files = @($config['files'])
            }

            $loaded = @{}
            $resolvedFiles = @()
            foreach ($file in $files) {
                if ([string]::IsNullOrWhiteSpace($file)) {
                    continue
                }
                $path = Resolve-JaxRepoRootedPath -Path $file -RepoRoot $repoRoot
                $resolvedFiles += $path
                $vars = Read-JaxDotEnvFile -Path $path
                foreach ($key in $vars.Keys) {
                    $value = $vars[$key]
                    $loaded[$key] = $value
                    Set-Item -Path "Env:$key" -Value $value
                }
            }

            $hook.Context['DotEnv'] = @{
                Files = $resolvedFiles
                Vars  = $loaded
            }
        }
    }

    Register-JaxPlugin -Name 'dotenv' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxDotenvPlugin
