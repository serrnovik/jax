function Write-JaxUpdateNotice {
    <#
    .SYNOPSIS
        Print a short "a newer Jax is available" hint, at most once per shell
        session.
    .DESCRIPTION
        Reads only the locally cached PowerShell Gallery result, so it never
        waits on the network. When that cache is stale it starts a detached
        background refresh and prints nothing on this run; the next run uses the
        fresh result. Every failure mode - no cache, no network, an unreadable
        state file, a read-only HOME - is silent.

        The hint is skipped when output is redirected (scripts, pipelines, and
        agent sessions), when CI is set, and when JAX_NO_UPDATE_NOTICE is set.
    .EXAMPLE
        Write-JaxUpdateNotice -RuntimeRoot $PSScriptRoot
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RuntimeRoot,
        [string] $CachePath = (Join-Path $HOME '.jax/update-check.json'),
        [string] $StatePath = (Join-Path $HOME '.jax/update-notice.json'),
        [TimeSpan] $CacheTtl = [TimeSpan]::FromHours(24),
        [switch] $Force
    )

    try {
        if (-not $Force) {
            $optOut = [string]$env:JAX_NO_UPDATE_NOTICE
            if (-not [string]::IsNullOrWhiteSpace($optOut) -and $optOut -notin @('0', 'false', 'no')) {
                return
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$env:CI)) {
                return
            }
            if ([Console]::IsOutputRedirected) {
                return
            }
        }

        $versionPath = Join-Path ([IO.Path]::GetFullPath($RuntimeRoot)) 'VERSION'
        if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
            return
        }
        $currentVersion = $null
        if (-not [version]::TryParse((Get-Content -LiteralPath $versionPath -Raw).Trim(), [ref] $currentVersion)) {
            return
        }

        $cacheFile = [IO.Path]::GetFullPath($CachePath)
        $stateFile = [IO.Path]::GetFullPath($StatePath)
        $cache = Read-JaxJsonFile -Path $cacheFile
        $checkedAt = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $cache -Name 'CheckedAtUtc')

        if ($null -eq $checkedAt -or ([DateTime]::UtcNow - $checkedAt) -ge $CacheTtl) {
            Start-JaxUpdateCheck -RuntimeRoot $RuntimeRoot -CachePath $cacheFile -StatePath $stateFile
            return
        }

        if ([string](Get-JaxJsonProperty -Object $cache -Name 'Status') -ne 'Available') {
            return
        }
        $latestVersion = $null
        $latestText = [string](Get-JaxJsonProperty -Object $cache -Name 'LatestVersion')
        if (-not [version]::TryParse($latestText, [ref] $latestVersion)) {
            return
        }
        if ($latestVersion -le $currentVersion) {
            return
        }

        $sessionKey = Get-JaxShellSessionKey
        $state = Read-JaxJsonFile -Path $stateFile
        foreach ($entry in @(Get-JaxJsonProperty -Object $state -Name 'NotifiedSessions')) {
            if ($null -eq $entry) { continue }
            if ([string](Get-JaxJsonProperty -Object $entry -Name 'Session') -ne $sessionKey) { continue }
            if ([string](Get-JaxJsonProperty -Object $entry -Name 'Version') -eq $latestVersion.ToString()) {
                return
            }
        }

        Save-JaxUpdateNoticeState -Path $stateFile -State $state `
            -NotifiedSession $sessionKey -NotifiedVersion $latestVersion.ToString()

        # The update command depends on how this copy was installed. Update-PSResource
        # only knows about copies PSResourceGet installed; aimed at ~/.jax/module it
        # either errors or updates a copy the `jx` shim never loads. Guarded, because
        # the notice is the point and the tailored command is the garnish - a failed
        # probe must not swallow "a new version exists". Gallery copies are not
        # enumerated here: PSModulePath is far too slow to walk on every run.
        $install = try { Get-JaxInstallInfo -RuntimeRoot $RuntimeRoot } catch { $null }

        Write-Host ''
        Write-Host ("  Jax {0} is available (you have {1})." -f $latestVersion, $currentVersion) -ForegroundColor Cyan
        if ($install -and $install.Flavour -eq 'Repo') {
            Write-Host ("  You are running from a checkout at {0}" -f $install.RuntimeRoot) -ForegroundColor DarkGray
            Write-Host '  Update: git pull, then ./Install-Jax.ps1' -ForegroundColor DarkGray
        } else {
            Write-Host '  Update: jax update' -ForegroundColor DarkGray
        }
    } catch {
        # An update hint must never slow down, interrupt, or fail a Jax run.
    }
}
