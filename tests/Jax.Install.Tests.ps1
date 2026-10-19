Describe 'Jax install provenance and update' {
    BeforeAll {
        $script:sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        # A copy loaded from ~/.jax/module (or a stale PSModulePath entry) makes
        # InModuleScope ambiguous, so start from exactly one Jax.Core.
        Get-Module Jax.Core | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:sourceRoot 'core/Jax.Core.psm1') -Global -Force

        $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ('jax-install-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null

        function New-JaxFakeRuntime {
            param(
                [string] $Path,
                [string] $Version = '1.2.3',
                [string] $Origin
            )
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $Path 'Jax.psm1') -Value '# fake' -Encoding utf8
            "@{ ModuleVersion = '$Version'; RootModule = 'Jax.psm1'; GUID = '$([guid]::NewGuid())'; Author = 'test' }" |
                Set-Content -LiteralPath (Join-Path $Path 'Jax.psd1') -Encoding utf8
            if ($Origin) {
                [ordered]@{
                    Origin = $Origin; Version = $Version; SourceCommit = 'abc'
                    InstalledAtUtc = ([DateTime]::UtcNow.ToString('O'))
                } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Path 'INSTALLATION.json') -Encoding utf8
            }
            return $Path
        }

        $script:checkoutRoot = New-JaxFakeRuntime -Path (Join-Path $script:testRoot 'checkout')
        $script:legacyRoot   = New-JaxFakeRuntime -Path (Join-Path $script:testRoot 'legacy-install')
        $script:galleryRoot  = New-JaxFakeRuntime -Path (Join-Path $script:testRoot 'gallery-install') -Origin 'Gallery'
        $script:nowhere      = Join-Path $script:testRoot 'nowhere'

        $script:moduleHome = Join-Path $script:testRoot 'psmodulepath'
        $script:onPathRoot = New-JaxFakeRuntime -Path (Join-Path $script:moduleHome 'Jax')

        $script:shadowHome = Join-Path $script:testRoot 'shadow-psmodulepath'
        New-JaxFakeRuntime -Path (Join-Path $script:shadowHome 'Jax/9.9.9') -Version '9.9.9' | Out-Null
        $script:shadowedRoot = New-JaxFakeRuntime -Path (Join-Path $script:testRoot 'shadowed-install') -Version '1.0.0'
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
    }

    Context 'Get-JaxInstallInfo' {
        It 'reports a checkout outside PSModulePath as Repo' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:checkoutRoot; Nowhere = $script:nowhere } {
                param($Root, $Nowhere)
                $info = Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Nowhere
                $info.Flavour | Should -Be 'Repo'
                $info.Version | Should -Be ([version]'1.2.3')
                $info.UpdateCommand | Should -Match 'git pull'
            }
        }

        It 'reports an install root with no recorded origin as Manual' {
            # Installs predating the Origin field are exactly that: built from a
            # checkout by Install-Jax.ps1.
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                $info = Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Root
                $info.Flavour | Should -Be 'Manual'
                $info.UpdateCommand | Should -Be 'jax update'
            }
        }

        It 'reads the origin recorded by the package' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:galleryRoot } {
                param($Root)
                $info = Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Root
                $info.Flavour | Should -Be 'Gallery'
                $info.SourceCommit | Should -Be 'abc'
                $info.InstalledAtUtc | Should -Not -BeNullOrEmpty
            }
        }

        It 'treats a runtime under PSModulePath as a Gallery install' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:onPathRoot; Home = $script:moduleHome; Nowhere = $script:nowhere } {
                param($Root, $Home, $Nowhere)
                $original = $env:PSModulePath
                try {
                    $env:PSModulePath = $Home + [IO.Path]::PathSeparator + $original
                    (Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Nowhere).Flavour | Should -Be 'Gallery'
                } finally {
                    $env:PSModulePath = $original
                }
            }
        }

        It 'flags a PSModulePath copy that shadows the running one' {
            # `Import-Module Jax` resolves through PSModulePath, so a stale
            # Install-Module copy answers for Jax everywhere except the jx shim,
            # which loads ~/.jax/module by path.
            InModuleScope Jax.Core -Parameters @{ Root = $script:shadowedRoot; Home = $script:shadowHome } {
                param($Root, $Home)
                $original = $env:PSModulePath
                try {
                    $env:PSModulePath = $Home + [IO.Path]::PathSeparator + $original
                    $info = Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Root -IncludeGalleryCopies
                } finally {
                    $env:PSModulePath = $original
                }
                $info.ShadowedBy | Should -Not -BeNullOrEmpty
                $info.ShadowedBy.Version | Should -Be ([version]'9.9.9')
            }
        }

        It 'does not enumerate PSModulePath unless asked' {
            # Write-JaxUpdateNotice calls this on every run; walking every module
            # root that often is not affordable.
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                $info = Get-JaxInstallInfo -RuntimeRoot $Root -InstallRoot $Root
                $info.GalleryCopies | Should -BeNullOrEmpty
                $info.ShadowedBy | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Package provenance' {
        It 'records Manual for an install taken from a checkout' {
            $installRoot = Join-Path $script:testRoot 'origin-manual'
            & pwsh -NoLogo -NoProfile -File (Join-Path $script:sourceRoot 'Install-Jax.ps1') `
                -InstallRoot $installRoot -SkipProfile | Out-Null
            $LASTEXITCODE | Should -Be 0

            $record = Get-Content -LiteralPath (Join-Path $installRoot 'INSTALLATION.json') -Raw | ConvertFrom-Json
            $record.Origin | Should -Be 'Manual'
        }

        It 'ships an installer that can install the package it came in' {
            # This is what `jax update` runs. The package needs both the installer
            # and the distribution manifest it copies from; shipping one without
            # the other fails on the installer's first line.
            $packageRoot = Join-Path $script:testRoot 'origin-package'
            & pwsh -NoLogo -NoProfile -File (Join-Path $script:sourceRoot 'Build-JaxPackage.ps1') `
                -OutputPath $packageRoot | Out-Null
            $LASTEXITCODE | Should -Be 0
            Test-Path -LiteralPath (Join-Path $packageRoot 'Install-Jax.ps1') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $packageRoot 'distribution-manifest.psd1') | Should -BeTrue

            $installRoot = Join-Path $script:testRoot 'origin-gallery'
            & pwsh -NoLogo -NoProfile -File (Join-Path $packageRoot 'Install-Jax.ps1') `
                -InstallRoot $installRoot -SkipProfile | Out-Null
            $LASTEXITCODE | Should -Be 0

            # Origin must survive the install, or `jax update` would keep claiming
            # it is replacing a hand-built copy.
            $record = Get-Content -LiteralPath (Join-Path $installRoot 'INSTALLATION.json') -Raw | ConvertFrom-Json
            $record.Origin | Should -Be 'Gallery'
        }
    }

    Context 'Update-Jax' {
        It 'reports up to date without downloading when the versions match' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                Mock Get-JaxInstallInfo { [pscustomobject]@{
                        Flavour = 'Manual'; RuntimeRoot = $Root; InstallRoot = $Root; Version = [version]'1.0.0'
                        SourceCommit = ''; InstalledAtUtc = $null
                        GalleryCopies = @(); ShadowedBy = $null; UpdateCommand = 'jax update'
                    } }
                Mock Get-JaxGalleryStatus { [pscustomobject]@{
                        CurrentVersion = [version]'1.0.0'; LatestVersion = [version]'1.0.0'
                        UpdateAvailable = $false; Status = 'Available'; CheckedAtUtc = [DateTime]::UtcNow; Source = 'cache'
                    } }
                Mock Save-JaxGalleryPackage { }
                Mock Read-Host { 'n' }

                $output = (Update-Jax -RuntimeRoot $Root -InstallRoot $Root 6>&1 | Out-String)

                $output | Should -Match 'Up to date'
                Should -Invoke Save-JaxGalleryPackage -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
                # An explicit update must not trust the 24h notice cache.
                Should -Invoke Get-JaxGalleryStatus -Times 1 -Exactly -ParameterFilter { $Force }
            }
        }

        It 'treats a local build ahead of the Gallery as current, not as a problem' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                Mock Get-JaxInstallInfo { [pscustomobject]@{
                        Flavour = 'Manual'; RuntimeRoot = $Root; InstallRoot = $Root; Version = [version]'2.0.0'
                        SourceCommit = ''; InstalledAtUtc = $null
                        GalleryCopies = @(); ShadowedBy = $null; UpdateCommand = 'jax update'
                    } }
                Mock Get-JaxGalleryStatus { [pscustomobject]@{
                        CurrentVersion = [version]'2.0.0'; LatestVersion = [version]'1.0.0'
                        UpdateAvailable = $false; Status = 'Available'; CheckedAtUtc = [DateTime]::UtcNow; Source = 'cache'
                    } }
                Mock Save-JaxGalleryPackage { }

                $output = (Update-Jax -RuntimeRoot $Root -InstallRoot $Root 6>&1 | Out-String)

                $output | Should -Match 'nothing to do'
                Should -Invoke Save-JaxGalleryPackage -Times 0 -Exactly
            }
        }

        It 'reports the pending update under -Check without downloading it' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                Mock Get-JaxInstallInfo { [pscustomobject]@{
                        Flavour = 'Manual'; RuntimeRoot = $Root; InstallRoot = $Root; Version = [version]'1.0.0'
                        SourceCommit = ''; InstalledAtUtc = $null
                        GalleryCopies = @(); ShadowedBy = $null; UpdateCommand = 'jax update'
                    } }
                Mock Get-JaxGalleryStatus { [pscustomobject]@{
                        CurrentVersion = [version]'1.0.0'; LatestVersion = [version]'9.9.9'
                        UpdateAvailable = $true; Status = 'Available'; CheckedAtUtc = [DateTime]::UtcNow; Source = 'cache'
                    } }
                Mock Save-JaxGalleryPackage { }
                Mock Read-Host { 'y' }

                $output = (Update-Jax -RuntimeRoot $Root -InstallRoot $Root -Check 6>&1 | Out-String)

                $output | Should -Match 'Update available: 1\.0\.0 -> 9\.9\.9'
                Should -Invoke Save-JaxGalleryPackage -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
            }
        }

        It 'says a checkout-built copy is being replaced, and stops when declined' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                Mock Get-JaxInstallInfo { [pscustomobject]@{
                        Flavour = 'Manual'; RuntimeRoot = $Root; InstallRoot = $Root; Version = [version]'1.0.0'
                        SourceCommit = ''; InstalledAtUtc = $null
                        GalleryCopies = @(); ShadowedBy = $null; UpdateCommand = 'jax update'
                    } }
                Mock Get-JaxGalleryStatus { [pscustomobject]@{
                        CurrentVersion = [version]'1.0.0'; LatestVersion = [version]'9.9.9'
                        UpdateAvailable = $true; Status = 'Available'; CheckedAtUtc = [DateTime]::UtcNow; Source = 'cache'
                    } }
                Mock Save-JaxGalleryPackage { }
                Mock Read-Host { 'n' }

                $output = (Update-Jax -RuntimeRoot $Root -InstallRoot $Root 6>&1 | Out-String)

                $output | Should -Match 'built from a checkout'
                $output | Should -Match 'Cancelled'
                Should -Invoke Save-JaxGalleryPackage -Times 0 -Exactly
            }
        }

        It 'stays quiet about the Gallery when it cannot be reached' {
            InModuleScope Jax.Core -Parameters @{ Root = $script:legacyRoot } {
                param($Root)
                Mock Get-JaxInstallInfo { [pscustomobject]@{
                        Flavour = 'Manual'; RuntimeRoot = $Root; InstallRoot = $Root; Version = [version]'1.0.0'
                        SourceCommit = ''; InstalledAtUtc = $null
                        GalleryCopies = @(); ShadowedBy = $null; UpdateCommand = 'jax update'
                    } }
                Mock Get-JaxGalleryStatus { [pscustomobject]@{
                        CurrentVersion = [version]'1.0.0'; LatestVersion = $null
                        UpdateAvailable = $false; Status = 'Unavailable'; CheckedAtUtc = [DateTime]::UtcNow; Source = 'cache'
                    } }
                Mock Save-JaxGalleryPackage { }

                (Update-Jax -RuntimeRoot $Root -InstallRoot $Root 6>&1 | Out-String) | Should -Match 'unreachable'
                Should -Invoke Save-JaxGalleryPackage -Times 0 -Exactly
            }
        }
    }

    Context 'CLI wiring' {
        It 'treats `update` as a Jax command rather than a task selector' {
            # Unknown tokens become `run -only <token>`; without registering it,
            # `jax update` would look for a task called update instead.
            InModuleScope Jax.Core {
                (Resolve-JaxCliCommand -Command 'update' -CommandArgs @()).Command | Should -Be 'update'
            }
        }

        It 'still reaches a task named update through run -only' {
            InModuleScope Jax.Core {
                $resolved = Resolve-JaxCliCommand -Command 'run' -CommandArgs @('-only', 'update')
                $resolved.Command | Should -Be 'run'
                $resolved.Args | Should -Contain 'update'
            }
        }
    }
}
