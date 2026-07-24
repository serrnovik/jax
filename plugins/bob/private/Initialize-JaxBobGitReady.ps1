function Initialize-JaxBobGitReady {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [System.Collections.IDictionary] $PluginConfig,
        [System.Collections.Queue] $InputQueue
    )

    $gitCommand = Get-Command -Name git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        $installHint = if ($IsWindows) {
            'Install Git: winget install --id Git.Git -e'
        } elseif ($IsMacOS) {
            'Install Git: brew install git'
        } else {
            'Install Git: sudo apt-get install git'
        }
        throw "Git is required for Jax bob integration. $installHint"
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Get-Location).Path
    }

    $gitMarker = Join-Path $RepoRoot '.git'
    if (Test-Path -Path $gitMarker) {
        return (Resolve-Path $RepoRoot).Path
    }

    $promptInit = $true
    $allowInit = $true
    if ($null -ne $PluginConfig -and $PluginConfig.ContainsKey('git')) {
        $gitConfig = $PluginConfig['git']
        if ($gitConfig -is [System.Collections.IDictionary]) {
            if ($gitConfig.ContainsKey('prompt')) {
                $promptInit = [bool]$gitConfig['prompt']
            }
            if ($gitConfig.ContainsKey('allowInit')) {
                $allowInit = [bool]$gitConfig['allowInit']
            }
        }
    }

    if (-not $promptInit -or -not $allowInit) {
        throw "Git repo not initialized at '$RepoRoot'. Run 'git init' or set JAX_REPO_ROOT."
    }

    $shouldInit = Read-JaxBobPromptBool -Prompt "Git repo not found at '$RepoRoot'. Initialize here?" -Default $false -InputQueue $InputQueue
    if (-not $shouldInit) {
        $pathHint = "Choose a repo root or set JAX_REPO_ROOT."
        throw "Git repo is required. $pathHint"
    }

    $targetPath = Read-JaxBobPromptString -Prompt 'Git repo root path (current or parent)' -Default $RepoRoot -InputQueue $InputQueue
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $targetPath = $RepoRoot
    }

    if (-not (Test-Path -Path $targetPath -PathType Container)) {
        throw "Git repo root '$targetPath' does not exist."
    }

    & git -C $targetPath init | Out-Null
    return (Resolve-Path $targetPath).Path
}
