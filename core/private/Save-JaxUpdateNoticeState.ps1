function Save-JaxUpdateNoticeState {
    <#
    .SYNOPSIS
        Persist the local update-notice bookkeeping file.
    .DESCRIPTION
        Holds the last background-refresh timestamp and the shell sessions that
        have already seen a notice. Sessions older than the retention window are
        dropped so the file cannot grow without bound. Writing is best effort:
        a read-only or full HOME must not break a Jax run.

        The state is shared by every concurrent shell, so the on-disk file is
        RE-READ here and merged with the caller's snapshot: the caller may have
        loaded it seconds ago, and writing that stale view back would erase
        another shell's notice record and make the notice repeat there. The
        re-read and the write are serialized by a sibling lock file so two
        shells cannot interleave and lose one another's entry, and the write
        itself goes to a temp file that is then moved into place, so a reader
        never observes a half-written file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        $State,
        [DateTime] $LastRefreshSpawnUtc = [DateTime]::MinValue,
        [string] $NotifiedSession,
        [string] $NotifiedVersion,
        [TimeSpan] $SessionRetention = [TimeSpan]::FromDays(7),
        [int] $MaxSessions = 100
    )

    $lock = $null
    try {
        $now = [DateTime]::UtcNow

        $directory = Split-Path -Parent $Path
        if (-not [string]::IsNullOrWhiteSpace($directory)) {
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
        }

        # Advisory cross-process lock over the whole read-modify-write. Bounded
        # on purpose: a shell must never stall on bookkeeping, so a lock that
        # cannot be taken in time is skipped and we fall back to the merge below.
        $lockPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$Path.lock")
        $deadline = [DateTime]::UtcNow.AddMilliseconds(750)
        do {
            try {
                $lock = [System.IO.File]::Open(
                    $lockPath,
                    [System.IO.FileMode]::OpenOrCreate,
                    [System.IO.FileAccess]::ReadWrite,
                    [System.IO.FileShare]::None)
            } catch {
                Start-Sleep -Milliseconds 25
            }
        } while ($null -eq $lock -and [DateTime]::UtcNow -lt $deadline)

        # Merge the caller's snapshot with whatever is on disk RIGHT NOW: a
        # concurrent shell may have recorded its own notice since the caller
        # read the file, and a plain overwrite would drop it.
        $onDisk = Read-JaxJsonFile -Path $Path

        $lastSpawn = if ($LastRefreshSpawnUtc -ne [DateTime]::MinValue) {
            $LastRefreshSpawnUtc
        } else {
            $callerSpawn = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $State -Name 'LastRefreshSpawnUtc')
            $diskSpawn = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $onDisk -Name 'LastRefreshSpawnUtc')
            # The newest refresh wins — an older snapshot must not re-open the
            # refresh window for every other shell.
            if ($null -eq $callerSpawn) { $diskSpawn }
            elseif ($null -eq $diskSpawn) { $callerSpawn }
            elseif ($diskSpawn -gt $callerSpawn) { $diskSpawn }
            else { $callerSpawn }
        }

        $sessions = [System.Collections.Generic.List[object]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $merged = @(Get-JaxJsonProperty -Object $onDisk -Name 'NotifiedSessions') +
                  @(Get-JaxJsonProperty -Object $State -Name 'NotifiedSessions')
        foreach ($entry in $merged) {
            if ($null -eq $entry) { continue }
            $session = [string](Get-JaxJsonProperty -Object $entry -Name 'Session')
            if ([string]::IsNullOrWhiteSpace($session)) { continue }
            if (-not [string]::IsNullOrWhiteSpace($NotifiedSession) -and $session -eq $NotifiedSession) { continue }
            if (-not $seen.Add($session)) { continue }
            $at = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $entry -Name 'AtUtc')
            if ($null -eq $at -or ($now - $at) -ge $SessionRetention) { continue }
            $sessions.Add([ordered]@{
                Session = $session
                Version = [string](Get-JaxJsonProperty -Object $entry -Name 'Version')
                AtUtc   = $at.ToString('O')
            })
        }

        if (-not [string]::IsNullOrWhiteSpace($NotifiedSession)) {
            $sessions.Add([ordered]@{
                Session = $NotifiedSession
                Version = $NotifiedVersion
                AtUtc   = $now.ToString('O')
            })
        }

        if ($sessions.Count -gt $MaxSessions) {
            $sessions = [System.Collections.Generic.List[object]](
                @($sessions | Select-Object -Last $MaxSessions)
            )
        }

        $record = [ordered]@{
            LastRefreshSpawnUtc = if ($null -ne $lastSpawn) { $lastSpawn.ToString('O') } else { $null }
            NotifiedSessions    = @($sessions)
        }

        # Write-then-move: a concurrent reader sees either the old file or the
        # new one, never a truncated one mid-write. The temp name carries a
        # unique suffix so two writers in the same process cannot share it.
        $temp = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temp -Encoding utf8 -ErrorAction Stop
            # .NET Move overwrites in one syscall; it needs native paths, which
            # can differ from the PowerShell location a relative -Path resolves against.
            [System.IO.File]::Move(
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($temp),
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path),
                $true)
        } finally {
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        # Bookkeeping is optional; at worst the notice repeats.
    } finally {
        if ($null -ne $lock) { $lock.Dispose() }
    }
}
