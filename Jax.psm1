Set-StrictMode -Version Latest

$script:JaxLauncher = Join-Path $PSScriptRoot 'jax.ps1'
$script:JaxShortcutLauncher = Join-Path $PSScriptRoot 'jxs.ps1'

function Resolve-JaxModuleManifestPath {
    <#
    .SYNOPSIS
        Return the Jax.psd1 that belongs to a module path.
    .DESCRIPTION
        Get-Module Jax.Path is the RootModule script (Jax.psm1) even after a
        manifest import. Session scripts used to persist that path, and
        Import-Module of a .psm1 reports Version 0.0. Always pin and load the
        sibling manifest when it exists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolved = try { [IO.Path]::GetFullPath($Path) } catch { $Path }
    if (Test-Path -LiteralPath $resolved -PathType Container) {
        $manifest = Join-Path $resolved 'Jax.psd1'
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            return [IO.Path]::GetFullPath($manifest)
        }
        throw "Jax module manifest is missing: $manifest"
    }

    $directory = [IO.Path]::GetDirectoryName($resolved)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        $sibling = Join-Path $directory 'Jax.psd1'
        if (Test-Path -LiteralPath $sibling -PathType Leaf) {
            return [IO.Path]::GetFullPath($sibling)
        }
    }

    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        return $resolved
    }

    throw "Jax module manifest is missing: $resolved"
}

function Get-JaxRuntimeVersion {
    <#
    .SYNOPSIS
        Read this runtime's version from Jax.psd1, not from Get-Module.
    .DESCRIPTION
        Import-Module Jax.psm1 creates a script module whose Version is 0.0.
        The published number lives on the manifest (and the VERSION file).
    #>
    [CmdletBinding()]
    param()

    $version = $null
    $manifestPath = Join-Path $PSScriptRoot 'Jax.psd1'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $parsed = $null
            $text = [string](Import-PowerShellDataFile -LiteralPath $manifestPath).ModuleVersion
            if ([version]::TryParse($text, [ref] $parsed)) {
                $version = $parsed
            }
        } catch {
            # Fall through to VERSION, then to an unknown current version.
        }
    }

    if ($null -eq $version) {
        $versionPath = Join-Path $PSScriptRoot 'VERSION'
        if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
            $parsed = $null
            if ([version]::TryParse((Get-Content -LiteralPath $versionPath -Raw).Trim(), [ref] $parsed)) {
                $version = $parsed
            }
        }
    }

    return $version
}

function Get-JaxUpdateStatus {
    [CmdletBinding()]
    param(
        [TimeSpan] $CacheTtl = [TimeSpan]::FromHours(24),
        [ValidateRange(1, 30)]
        [int] $TimeoutSec = 2,
        [string] $CachePath = (Join-Path $HOME '.jax/update-check.json'),
        [switch] $Force
    )

    $currentVersion = Get-JaxRuntimeVersion

    $cachePath = [IO.Path]::GetFullPath($CachePath)
    $cache = $null
    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
        try {
            $cache = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $cache = $null
        }
    }

    $now = [DateTime]::UtcNow
    $checkedAt = [DateTime]::MinValue
    if ($null -ne $cache -and $cache.PSObject.Properties.Match('CheckedAtUtc').Count -gt 0) {
        [DateTime]::TryParse(
            [string]$cache.CheckedAtUtc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AdjustToUniversal,
            [ref]$checkedAt
        ) | Out-Null
    }
    $cacheIsFresh = -not $Force -and $checkedAt -ne [DateTime]::MinValue -and
        ($now - $checkedAt.ToUniversalTime()) -lt $CacheTtl

    $latestVersionText = if ($null -ne $cache -and $cache.PSObject.Properties.Match('LatestVersion').Count -gt 0) {
        [string]$cache.LatestVersion
    } else {
        $null
    }
    $status = if ($null -ne $cache -and $cache.PSObject.Properties.Match('Status').Count -gt 0) {
        [string]$cache.Status
    } else {
        'Unknown'
    }
    $source = 'cache'

    if (-not $cacheIsFresh) {
        $source = 'gallery'
        $status = 'Unavailable'
        try {
            $uri = "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='Jax'&%24filter=IsLatestVersion"
            $response = Invoke-WebRequest -Uri $uri -TimeoutSec $TimeoutSec -ErrorAction Stop
            $match = [regex]::Match(
                [string]$response.Content,
                '<d:Version>(?<version>[^<]+)</d:Version>',
                [Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
            if (-not $match.Success) {
                throw 'The PowerShell Gallery response did not contain a Jax version.'
            }
            $latestVersionText = $match.Groups['version'].Value
            [version]$latestVersionText | Out-Null
            $status = 'Available'
        } catch {
            # An offline workstation is normal. Cache the failed attempt so
            # repository startup does not retry or pause on every shell.
        }

        $cacheRecord = [ordered]@{
            CheckedAtUtc = $now.ToString('O')
            LatestVersion = $latestVersionText
            Status = $status
        }
        try {
            $cacheDirectory = Split-Path -Parent $cachePath
            New-Item -ItemType Directory -Path $cacheDirectory -Force -ErrorAction Stop | Out-Null
            $cacheRecord | ConvertTo-Json |
                Set-Content -LiteralPath $cachePath -Encoding utf8 -ErrorAction Stop
        } catch {
            # Update checks must never prevent Jax or repository startup.
        }
        $checkedAt = $now
    }

    $latestVersion = $null
    if (-not [string]::IsNullOrWhiteSpace($latestVersionText)) {
        try {
            $latestVersion = [version]$latestVersionText
        } catch {
            $latestVersion = $null
        }
    }

    [pscustomobject]@{
        CurrentVersion = $currentVersion
        LatestVersion = $latestVersion
        UpdateAvailable = $null -ne $latestVersion -and $null -ne $currentVersion -and $latestVersion -gt $currentVersion
        Status = $status
        CheckedAtUtc = if ($checkedAt -eq [DateTime]::MinValue) { $null } else { $checkedAt.ToUniversalTime() }
        Source = $source
    }
}

function Install-JaxShellIntegration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]] $Shell,
        # Source installs pass their exact manifest so every shell uses the
        # checkout build instead of a possibly newer Gallery installation.
        # A directory or Jax.psm1 path is rewritten to the sibling Jax.psd1:
        # Get-Module.Path is the RootModule script even after a manifest import,
        # and Import-Module of that script reports Version 0.0.
        [string] $ModulePath,
        [string] $InstallRoot = (Join-Path $HOME '.jax/shell'),
        # CurrentUserCurrentHost loads after the all-hosts profile, so later
        # profile commands cannot silently replace the jax/jx aliases.
        [string] $PowerShellProfilePath = $PROFILE.CurrentUserCurrentHost,
        [string] $ZshProfilePath = (Join-Path $HOME '.zshrc'),
        [string] $BashProfilePath = (Join-Path $HOME '.bashrc'),
        [string] $BashLoginProfilePath
    )

    $validShells = @('powershell', 'zsh', 'bash')
    $normalizedShells = @(
        foreach ($shellValue in @($Shell)) {
            foreach ($shellName in @([string]$shellValue -split ',')) {
                $normalizedShell = $shellName.Trim().ToLowerInvariant()
                if ([string]::IsNullOrWhiteSpace($normalizedShell)) {
                    continue
                }
                if ($normalizedShell -notin $validShells) {
                    throw "Unsupported Jax shell '$normalizedShell'. Expected one of: $($validShells -join ', ')."
                }
                $normalizedShell
            }
        }
    )
    $Shell = @($normalizedShells | Select-Object -Unique)

    $resolvedModulePath = $null
    if (-not [string]::IsNullOrWhiteSpace($ModulePath)) {
        $resolvedModulePath = Resolve-JaxModuleManifestPath -Path $ModulePath
    }

    if ($null -eq $Shell -or $Shell.Count -eq 0) {
        $Shell = @('powershell')
        $detectedShell = [IO.Path]::GetFileName([string]$env:SHELL)
        if (-not $IsWindows -and $detectedShell -in @('zsh', 'bash')) {
            $Shell += $detectedShell
        } elseif ($IsMacOS) {
            # Non-interactive installers may not inherit SHELL. zsh is the
            # macOS default and should still work on the next terminal launch.
            $Shell += 'zsh'
        } elseif ($IsLinux) {
            $Shell += 'bash'
        }
    }

    $unixShells = @($Shell | Where-Object { $_ -in @('zsh', 'bash') })
    if ($IsWindows -and $unixShells.Count -gt 0) {
        throw 'Jax zsh/bash integration is supported on macOS and Linux. Use -Shell powershell on Windows.'
    }

    $sourceRoot = Join-Path $PSScriptRoot 'shell'
    $requiredFiles = @('Jax.ShellLauncher.ps1', 'Jax.ShellCompletion.ps1', 'jax.zsh', 'jax.bash')
    # Executable shims keep jax/jx/jxs available wherever PATH is inherited but
    # sourced shell functions are not: scripts, CI steps, and agent shells.
    $requiredShims = @('jax', 'jx', 'jxs')
    if ($unixShells.Count -gt 0) {
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $file) -PathType Leaf)) {
                throw "Jax shell integration file is missing: $file"
            }
        }
        foreach ($shim in $requiredShims) {
            if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "bin/$shim") -PathType Leaf)) {
                throw "Jax shell integration file is missing: bin/$shim"
            }
        }

        $resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot)
        if ($resolvedInstallRoot -in @(
                [IO.Path]::GetFullPath([IO.Path]::GetPathRoot($resolvedInstallRoot)),
                [IO.Path]::GetFullPath($HOME)
            )) {
            throw "Refusing unsafe shell integration root: $resolvedInstallRoot"
        }

        if ($PSCmdlet.ShouldProcess($resolvedInstallRoot, 'Install Jax zsh/bash integration')) {
            New-Item -ItemType Directory -Path $resolvedInstallRoot -Force | Out-Null
            foreach ($file in $requiredFiles) {
                Copy-Item -LiteralPath (Join-Path $sourceRoot $file) `
                    -Destination (Join-Path $resolvedInstallRoot $file) -Force
            }

            $shimRoot = Join-Path $resolvedInstallRoot 'bin'
            New-Item -ItemType Directory -Path $shimRoot -Force | Out-Null
            foreach ($shim in $requiredShims) {
                $shimDestination = Join-Path $shimRoot $shim
                Copy-Item -LiteralPath (Join-Path $sourceRoot "bin/$shim") `
                    -Destination $shimDestination -Force
                # Copy-Item does not guarantee the Unix execute bit survives.
                & /bin/chmod 'a+x' $shimDestination
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to make the Jax shim executable: $shimDestination"
                }
            }
        }
    }

    $bashProfiles = @([IO.Path]::GetFullPath($BashProfilePath))
    if (-not [string]::IsNullOrWhiteSpace($BashLoginProfilePath)) {
        $bashProfiles += [IO.Path]::GetFullPath($BashLoginProfilePath)
    } elseif (-not $PSBoundParameters.ContainsKey('BashProfilePath')) {
        # Login Bash reads ~/.bash_profile instead of ~/.bashrc on macOS and
        # on many Linux setups. Register both default entrypoints.
        $bashProfiles += [IO.Path]::GetFullPath((Join-Path $HOME '.bash_profile'))
    }

    $profiles = @{
        powershell = @([IO.Path]::GetFullPath($PowerShellProfilePath))
        zsh = @([IO.Path]::GetFullPath($ZshProfilePath))
        bash = @($bashProfiles | Select-Object -Unique)
    }
    foreach ($shellName in @($Shell | Sort-Object -Unique)) {
        $beginMarker = '# >>> jax CLI >>>'
        $endMarker = '# <<< jax CLI <<<'
        $block = if ($shellName -eq 'powershell') {
            if ($null -ne $resolvedModulePath) {
                $escapedModulePath = $resolvedModulePath.Replace("'", "''")
@"
# >>> jax CLI >>>
`$jaxProfileModulePath = '$escapedModulePath'
if (Test-Path -LiteralPath `$jaxProfileModulePath -PathType Leaf) {
    Get-Module Jax |
        Where-Object Path -NE `$jaxProfileModulePath |
        Remove-Module -Force
    Import-Module `$jaxProfileModulePath -Global -Force -DisableNameChecking
}
# <<< jax CLI <<<
"@
            } else {
@'
# >>> jax CLI >>>
$jaxProfileModulePath = Get-Module -ListAvailable Jax |
    Sort-Object Version -Descending |
    Select-Object -First 1 -ExpandProperty Path
if ([string]::IsNullOrWhiteSpace($jaxProfileModulePath)) {
    $jaxSourceInstall = Join-Path $HOME '.jax/module/Jax.psd1'
    if (Test-Path -LiteralPath $jaxSourceInstall -PathType Leaf) {
        $jaxProfileModulePath = $jaxSourceInstall
    }
}
if (-not [string]::IsNullOrWhiteSpace($jaxProfileModulePath)) {
    Get-Module Jax |
        Where-Object Path -NE $jaxProfileModulePath |
        Remove-Module -Force
    Import-Module $jaxProfileModulePath -Global -Force -DisableNameChecking
}
# <<< jax CLI <<<
'@
            }
        } else {
            $integrationPath = Join-Path $resolvedInstallRoot "jax.$shellName"
            $quotedIntegrationPath = "'" + $integrationPath.Replace("'", "'`"`"'") + "'"
            $modulePathLine = ''
            if ($null -ne $resolvedModulePath) {
                $quotedModulePath = "'" + $resolvedModulePath.Replace("'", "'`"`"'") + "'"
                $modulePathLine = "export JAX_MODULE_PATH=$quotedModulePath`n"
            }
@"
$beginMarker
${modulePathLine}[ -f $quotedIntegrationPath ] && source $quotedIntegrationPath
$endMarker
"@
        }
        foreach ($profilePath in @($profiles[$shellName])) {
            $existing = if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
                Get-Content -LiteralPath $profilePath -Raw
            } else {
                ''
            }
            $pattern = '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' +
                [regex]::Escape($endMarker) + '\r?\n?'
            $withoutOldBlock = [regex]::Replace($existing, $pattern, '').TrimEnd()
            $profileContent = if ([string]::IsNullOrWhiteSpace($withoutOldBlock)) {
                $block
            } else {
                "$withoutOldBlock`n`n$block"
            }

            if ($PSCmdlet.ShouldProcess($profilePath, "Register Jax $shellName integration")) {
                $profileDirectory = Split-Path -Parent $profilePath
                New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
                Set-Content -LiteralPath $profilePath -Value $profileContent -Encoding utf8
                Write-Host "Jax $shellName integration registered in $profilePath" -ForegroundColor Green
            }
        }
    }

    Write-Host 'Open a new shell, or dot-source the updated profile now.' -ForegroundColor DarkGray
    if ($unixShells.Count -gt 0) {
        Write-Host ("jax, jx, and jxs are installed as executables in {0}/bin and added to PATH." -f $resolvedInstallRoot) -ForegroundColor DarkGray
    }
}

function Invoke-Jax {
    & $script:JaxLauncher @args
}

function Invoke-JaxShortcut {
    & $script:JaxLauncher -Shortcut @args
}

function Register-JaxCompletion {
    $completionModule = Join-Path $PSScriptRoot 'Jax.Autocomplete.psm1'
    # Completion registrations must live in the caller's global session state.
    # Importing as a nested module works only accidentally in sessions where
    # Jax completion was already registered.
    Import-Module $completionModule -Global -Force -DisableNameChecking -ErrorAction Stop
}

# Point the interactive aliases at the scripts so PowerShell can see their
# static and dynamic parameters. A function wrapper hides parameters such as
# -env/-e from TabExpansion2 and makes it fall back to filesystem completion.
Set-Alias -Name jax -Value $script:JaxLauncher
# Point the short alias at `jax` instead of directly at the script. PowerShell
# then resolves completion through the canonical command name as well as
# forwarding execution to the same launcher.
Set-Alias -Name jx -Value jax
Set-Alias -Name jxs -Value $script:JaxShortcutLauncher

Export-ModuleMember -Function Get-JaxUpdateStatus, Install-JaxShellIntegration, Invoke-Jax, Invoke-JaxShortcut, Register-JaxCompletion -Alias jax, jx, jxs

# A Gallery installation should be ready after PowerShell auto-loads the
# module; it must not require a profile-only registration step.
Register-JaxCompletion
