function Find-JaxTasks {
    <#
    .SYNOPSIS
    Search task keys across environments.

    .DESCRIPTION
    Returns one object per (task, environment) match, sorted by task then
    environment. EnvPattern limits which environments are searched, with the
    same matching rules as Pattern. An environment that fails to load is
    skipped with a warning, so one broken environment never hides the others.

    Discovering every environment takes a while, so in a git repository the
    task names of all environments are kept in .jax/cache/task-index.json and
    reused until a .ps1/.psm1/.yml/.yaml file changes (Get-JaxTaskIndexFingerprint).
    Refresh rebuilds it; NoCache neither reads nor writes it.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [Parameter(Mandatory = $true)]
        [string] $Pattern,
        [string] $EnvPattern,
        [switch] $Refresh,
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters

    $cacheDir = Join-Path $RepoRoot '.jax/cache'
    $cachePath = Join-Path $cacheDir 'task-index.json'
    $fingerprint = if ($NoCache) { $null } else { Get-JaxTaskIndexFingerprint -RepoRoot $RepoRoot @commonParams }

    $index = $null
    if ($null -ne $fingerprint -and -not $Refresh -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        try {
            $cached = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -AsHashtable
            if ($cached['fingerprint'] -eq $fingerprint) {
                $index = @($cached['environments'])
            }
        } catch {
            $index = $null
        }
    }

    if ($null -eq $index) {
        $envs = @(Get-JaxEnvironments -RepoRoot $RepoRoot -Config $Config @commonParams | Sort-Object -Property Name -Unique)
        # Without a reusable index, only the requested environments are worth discovering.
        if ($null -eq $fingerprint -and -not [string]::IsNullOrWhiteSpace($EnvPattern)) {
            $envs = @($envs | Where-Object { Test-JaxTaskPatternMatch -Name $_.Name -Pattern $EnvPattern })
        }
        Write-Host "Indexing tasks of $($envs.Count) environments..."
        $skipped = 0
        $index = @(foreach ($environment in $envs) {
                try {
                    $taskKeys = Get-JaxEnvironmentTaskKeys -RepoRoot $RepoRoot -Config $Config -Environment $environment @commonParams
                    @{ name = $environment.Name; tasks = @($taskKeys.Keys | Sort-Object -Unique) }
                } catch {
                    $skipped++
                    Write-Warning "Skipped environment '$($environment.Name)': $($_.Exception.Message)"
                }
            })
        # An incomplete index is not saved, so the next search retries the skipped environments.
        if ($null -ne $fingerprint -and $skipped -eq 0) {
            try {
                New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
                $ignoreFile = Join-Path $cacheDir '.gitignore'
                if (-not (Test-Path -LiteralPath $ignoreFile)) {
                    Set-Content -LiteralPath $ignoreFile -Value '*'
                }
                $temp = "$cachePath.$PID.tmp"
                @{ fingerprint = $fingerprint; environments = $index } | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $temp
                Move-Item -LiteralPath $temp -Destination $cachePath -Force
            } catch {
                Write-Warning "Could not save the task index: $($_.Exception.Message)"
            }
        }
    }

    $results = foreach ($entry in $index) {
        if (-not [string]::IsNullOrWhiteSpace($EnvPattern) -and -not (Test-JaxTaskPatternMatch -Name $entry['name'] -Pattern $EnvPattern)) {
            continue
        }
        foreach ($task in @($entry['tasks'])) {
            if (Test-JaxTaskPatternMatch -Name $task -Pattern $Pattern) {
                [pscustomobject]@{ Task = $task; Env = $entry['name'] }
            }
        }
    }

    return @($results | Sort-Object -Property Task, Env)
}
