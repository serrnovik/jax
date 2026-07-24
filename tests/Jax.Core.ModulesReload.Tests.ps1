$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Invoke-JaxModulesReload' {
    It 'reloads repo modules and respects exclusions' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempRoot | Out-Null

            $inRoot = Join-Path $tempRoot 'alpha.psm1'
            $excluded = Join-Path $tempRoot 'skip.psm1'
            $alphaSource = @'
$script:Marker = [guid]::NewGuid().ToString()
function Get-AlphaMarker { $script:Marker }
Export-ModuleMember -Function Get-AlphaMarker
'@
            $skipSource = @'
$script:Marker = [guid]::NewGuid().ToString()
function Get-SkipMarker { $script:Marker }
Export-ModuleMember -Function Get-SkipMarker
'@
            Set-Content -Path $inRoot -Value $alphaSource -Encoding ascii
            Set-Content -Path $excluded -Value $skipSource -Encoding ascii

            Import-Module $inRoot -Force
            Import-Module $excluded -Force

            $alphaBefore = Get-AlphaMarker
            $skipBefore = Get-SkipMarker

            Invoke-JaxModulesReload -RepoRoot $tempRoot -ExcludeModuleNames @('skip.psm1')

            $alphaAfter = Get-AlphaMarker
            $skipAfter = Get-SkipMarker

            $alphaAfter | Should -Not -Be $alphaBefore
            $skipAfter | Should -Be $skipBefore

            Remove-Module -Name 'alpha' -Force
            Remove-Module -Name 'skip' -Force
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'excludes modules by path pattern from config' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempRoot | Out-Null

            # Create .build subdirectory
            $buildDir = Join-Path $tempRoot '.build/ps'
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

            $normalModule = Join-Path $tempRoot 'normal.psm1'
            $buildModule = Join-Path $buildDir 'excluded.psm1'

            $normalSource = @'
$script:Marker = [guid]::NewGuid().ToString()
function Get-NormalMarker { $script:Marker }
Export-ModuleMember -Function Get-NormalMarker
'@
            $buildSource = @'
$script:Marker = [guid]::NewGuid().ToString()
function Get-BuildMarker { $script:Marker }
Export-ModuleMember -Function Get-BuildMarker
'@
            Set-Content -Path $normalModule -Value $normalSource -Encoding ascii
            Set-Content -Path $buildModule -Value $buildSource -Encoding ascii

            Import-Module $normalModule -Force
            Import-Module $buildModule -Force

            $normalBefore = Get-NormalMarker
            $buildBefore = Get-BuildMarker

            # Config with path exclusion pattern
            $config = @{
                moduleReload = @{
                    excludePathPatterns = @('.build/**/*.psm1')
                }
            }

            Invoke-JaxModulesReload -RepoRoot $tempRoot -Config $config

            $normalAfter = Get-NormalMarker
            $buildAfter = Get-BuildMarker

            # Normal module should be reloaded (different marker)
            $normalAfter | Should -Not -Be $normalBefore
            # Build module should NOT be reloaded (same marker)
            $buildAfter | Should -Be $buildBefore

            Remove-Module -Name 'normal' -Force
            Remove-Module -Name 'excluded' -Force
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }
}
