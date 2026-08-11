function Start-JaxUpdateCheck {
    <#
    .SYNOPSIS
        Refresh the Gallery version cache in a detached background process.
    .DESCRIPTION
        The foreground command never waits on the network. When the cache is
        stale this starts an independent pwsh that writes the cache and exits;
        the result is used by the next Jax run. A cooldown stamp keeps rapid
        successive commands from starting more than one refresh.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RuntimeRoot,
        [Parameter(Mandatory = $true)]
        [string] $CachePath,
        [Parameter(Mandatory = $true)]
        [string] $StatePath,
        [TimeSpan] $Cooldown = [TimeSpan]::FromMinutes(10)
    )

    try {
        $manifestPath = Join-Path $RuntimeRoot 'Jax.psd1'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            return
        }

        $pwshPath = [Environment]::ProcessPath
        if ([string]::IsNullOrWhiteSpace($pwshPath) -or -not (Test-Path -LiteralPath $pwshPath -PathType Leaf)) {
            return
        }

        $now = [DateTime]::UtcNow
        $state = Read-JaxJsonFile -Path $StatePath
        $lastSpawn = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $state -Name 'LastRefreshSpawnUtc')
        if ($null -ne $lastSpawn -and ($now - $lastSpawn) -lt $Cooldown) {
            return
        }

        Save-JaxUpdateNoticeState -Path $StatePath -State $state -LastRefreshSpawnUtc $now

        $escapedManifest = $manifestPath.Replace("'", "''")
        $escapedCache = $CachePath.Replace("'", "''")
        $command = "Import-Module '$escapedManifest' -DisableNameChecking; " +
            "Get-JaxUpdateStatus -Force -CachePath '$escapedCache' | Out-Null"

        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $pwshPath
        foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-Command', $command)) {
            $startInfo.ArgumentList.Add($argument)
        }
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        # The child prints nothing; capturing its streams keeps any unexpected
        # output off the user's terminal instead of interleaving with Jax.
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        [Diagnostics.Process]::Start($startInfo) | Out-Null
    } catch {
        # A background update check is optional; never surface its failures.
    }
}
