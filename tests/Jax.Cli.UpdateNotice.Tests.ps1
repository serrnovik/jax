Describe 'Write-JaxUpdateNotice' {
    BeforeAll {
        $script:sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        Import-Module (Join-Path $script:sourceRoot 'core/Jax.Core.psm1') -Global -Force
        $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ('jax-update-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        $script:currentVersion = [version](Get-Content -LiteralPath (Join-Path $script:sourceRoot 'VERSION') -Raw).Trim()

        function New-JaxTestCache {
            param(
                [string] $LatestVersion = '99.0.0',
                [string] $Status = 'Available',
                [TimeSpan] $Age = [TimeSpan]::Zero
            )
            $path = Join-Path $script:testRoot ('cache-' + [guid]::NewGuid().ToString('N') + '.json')
            [ordered]@{
                CheckedAtUtc  = ([DateTime]::UtcNow - $Age).ToString('O')
                LatestVersion = $LatestVersion
                Status        = $Status
            } | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
            return $path
        }

        function Get-JaxTestNotice {
            param([string] $CachePath, [string] $StatePath)
            return (& {
                Write-JaxUpdateNotice -RuntimeRoot $script:sourceRoot `
                    -CachePath $CachePath -StatePath $StatePath -Force
            } 6>&1 | Out-String)
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
        Remove-Item Env:JAX_SHELL_SESSION -ErrorAction SilentlyContinue
    }

    It 'announces a newer published version once per shell session' {
        $env:JAX_SHELL_SESSION = 'test-once'
        $cache = New-JaxTestCache
        $state = Join-Path $script:testRoot 'state-once.json'

        $first = Get-JaxTestNotice -CachePath $cache -StatePath $state
        $second = Get-JaxTestNotice -CachePath $cache -StatePath $state

        $first | Should -Match 'Jax 99\.0\.0 is available'
        $first | Should -Match 'Update-PSResource Jax'
        $first | Should -Match ([regex]::Escape($script:currentVersion.ToString()))
        $second | Should -BeNullOrEmpty
    }

    It 'announces again in a different shell session' {
        $cache = New-JaxTestCache
        $state = Join-Path $script:testRoot 'state-sessions.json'

        $env:JAX_SHELL_SESSION = 'session-a'
        Get-JaxTestNotice -CachePath $cache -StatePath $state | Should -Match 'is available'
        $env:JAX_SHELL_SESSION = 'session-b'
        Get-JaxTestNotice -CachePath $cache -StatePath $state | Should -Match 'is available'
    }

    It 'stays silent when the published version is not newer' {
        $env:JAX_SHELL_SESSION = 'test-older'
        $cache = New-JaxTestCache -LatestVersion '0.0.1'
        $state = Join-Path $script:testRoot 'state-older.json'

        Get-JaxTestNotice -CachePath $cache -StatePath $state | Should -BeNullOrEmpty
    }

    It 'stays silent when the last Gallery lookup failed' {
        $env:JAX_SHELL_SESSION = 'test-unavailable'
        $cache = New-JaxTestCache -Status 'Unavailable'
        $state = Join-Path $script:testRoot 'state-unavailable.json'

        Get-JaxTestNotice -CachePath $cache -StatePath $state | Should -BeNullOrEmpty
    }

    It 'stays silent - and does not throw - on a corrupt cache' {
        $env:JAX_SHELL_SESSION = 'test-corrupt'
        $cache = Join-Path $script:testRoot 'corrupt.json'
        Set-Content -LiteralPath $cache -Value 'not json {{' -Encoding utf8
        $state = Join-Path $script:testRoot 'state-corrupt.json'

        {
            Write-JaxUpdateNotice -RuntimeRoot $script:sourceRoot -CachePath $cache -StatePath $state -Force
        } | Should -Not -Throw
        Get-JaxTestNotice -CachePath $cache -StatePath $state | Should -BeNullOrEmpty
    }

    It 'never waits on the network: a stale cache prints nothing and returns fast' {
        $env:JAX_SHELL_SESSION = 'test-stale'
        $cache = New-JaxTestCache -Age ([TimeSpan]::FromDays(30))
        $state = Join-Path $script:testRoot 'state-stale.json'

        $elapsed = Measure-Command {
            $script:staleOutput = Get-JaxTestNotice -CachePath $cache -StatePath $state
        }

        $script:staleOutput | Should -BeNullOrEmpty
        $elapsed.TotalSeconds | Should -BeLessThan 2
        # The refresh cooldown stamp proves the check was handed to a detached
        # process instead of being awaited here.
        (Get-Content -LiteralPath $state -Raw | ConvertFrom-Json).LastRefreshSpawnUtc |
            Should -Not -BeNullOrEmpty
    }

    It 'honors the JAX_NO_UPDATE_NOTICE opt-out' {
        $env:JAX_SHELL_SESSION = 'test-optout'
        $cache = New-JaxTestCache
        $state = Join-Path $script:testRoot 'state-optout.json'
        $env:JAX_NO_UPDATE_NOTICE = '1'
        try {
            $output = (& {
                Write-JaxUpdateNotice -RuntimeRoot $script:sourceRoot -CachePath $cache -StatePath $state
            } 6>&1 | Out-String)
        } finally {
            Remove-Item Env:JAX_NO_UPDATE_NOTICE -ErrorAction SilentlyContinue
        }

        $output | Should -BeNullOrEmpty
    }

    It 'is called by jax.ps1 after a run completes' {
        $markerPath = Join-Path $script:testRoot 'end-block-marker.txt'
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $script:sourceRoot '..')).Path
        # An alias outranks a function in command resolution, so this stub
        # survives the -Global -Force core import jax.ps1 does in its begin block.
        $probe = @"
function global:Test-JaxNoticeMarker { param([string] `$RuntimeRoot) `$RuntimeRoot | Set-Content '$markerPath' }
Set-Alias -Name Write-JaxUpdateNotice -Value Test-JaxNoticeMarker -Scope Global -Force
& '$(Join-Path $script:sourceRoot 'jax.ps1')' -C '$repoRoot' info -q | Out-Null
"@
        & pwsh -NoLogo -NoProfile -Command $probe *>&1 | Out-Null

        Test-Path -LiteralPath $markerPath -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $markerPath -Raw).Trim() | Should -Be $script:sourceRoot
    }

    It 'keeps the shell shims exporting a stable session id' {
        foreach ($shim in @('jax', 'jx', 'jxs')) {
            $content = Get-Content -LiteralPath (Join-Path $script:sourceRoot "shell/bin/$shim") -Raw
            $content | Should -Match 'JAX_SHELL_SESSION=\$PPID'
            $content | Should -Match 'export JAX_SHELL_ENTRYPOINT JAX_SHELL_SESSION'
        }
    }
}

Describe 'Save-JaxUpdateNoticeState' {
    BeforeAll {
        $script:sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $script:modulePath = Join-Path $script:sourceRoot 'core/Jax.Core.psm1'
        Import-Module $script:modulePath -Global -Force
        $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ('jax-state-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
    }

    It 'keeps every concurrent writer''s session and never leaves partial JSON' {
        $state = Join-Path $script:testRoot 'state-concurrent.json'
        $sessions = @(1..4 | ForEach-Object { "concurrent-$_" })

        $jobs = foreach ($session in $sessions) {
            Start-Job -ArgumentList $script:modulePath, $state, $session -ScriptBlock {
                param([string] $ModulePath, [string] $StatePath, [string] $Session)
                Import-Module $ModulePath -Force
                & (Get-Module Jax.Core) {
                    param([string] $Path, [string] $Session)
                    foreach ($i in 1..5) {
                        Save-JaxUpdateNoticeState -Path $Path `
                            -State (Read-JaxJsonFile -Path $Path) `
                            -NotifiedSession $Session -NotifiedVersion '9.9.9'
                    }
                } $StatePath $Session
            }
        }

        $jobs | Wait-Job -Timeout 180 | Out-Null
        $jobs | Receive-Job -ErrorAction SilentlyContinue | Out-Null
        $jobs | Remove-Job -Force

        $record = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
        foreach ($session in $sessions) {
            @($record.NotifiedSessions.Session) | Should -Contain $session
        }
        @(Get-ChildItem -LiteralPath $script:testRoot -Filter '*.tmp') | Should -BeNullOrEmpty
    }
}
