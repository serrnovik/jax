$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Resolve-JaxPsakeProperties declared [bool] properties' {
    # A [bool] property overridden as text used to reach psake as the string
    # 'False': binding it to a [bool] parameter threw "Cannot convert value
    # System.String to type System.Boolean", and `if ($flag)` was true.
    It 'converts <Text> to <Expected>' -TestCases @(
        @{ Text = 'False'; Expected = $false }
        @{ Text = '$false'; Expected = $false }
        @{ Text = '0'; Expected = $false }
        @{ Text = 'no'; Expected = $false }
        @{ Text = 'True'; Expected = $true }
        @{ Text = '$true'; Expected = $true }
        @{ Text = '1'; Expected = $true }
    ) {
        param($Text, $Expected)
        InModuleScope Jax.Core -Parameters @{ Text = $Text; Expected = $Expected } {
            param($Text, $Expected)
            $entity = @{
                Definition = @{
                    Parameters = @(
                        @{ Name = 'releaseDryRun'; Type = 'bool'; DefaultValue = $true }
                        @{ Name = 'channel'; Type = 'string'; DefaultValue = 'stable' }
                    )
                }
            }
            $context = @{ CliArgs = @{ releaseDryRun = $Text; channel = '0' } }
            $props = Resolve-JaxPsakeProperties -Entity $entity -Context $context
            $props['releaseDryRun'] | Should -BeOfType [bool]
            $props['releaseDryRun'] | Should -Be $Expected
            # Only declared [bool] properties are touched.
            $props['channel'] | Should -BeExactly '0'
        }
    }

    It 'leaves real booleans and undeclared keys alone' {
        InModuleScope Jax.Core {
            $entity = @{ Definition = @{ Parameters = @(@{ Name = 'mainBranch'; Type = '[bool]' }) } }
            $context = @{ CliArgs = @{ mainBranch = $true; other = 'False' } }
            $props = Resolve-JaxPsakeProperties -Entity $entity -Context $context
            $props['mainBranch'] | Should -BeExactly $true
            $props['other'] | Should -BeExactly 'False'
        }
    }

    It 'converts run-config and flow args strings for declared [bool] too' {
        InModuleScope Jax.Core {
            $entity = @{
                Definition = @{ Parameters = @(@{ Name = 'storeNoCommit'; Type = 'Boolean' }) }
                Args = @{ storeNoCommit = 'false' }
            }
            $props = Resolve-JaxPsakeProperties -Entity $entity -Context @{}
            $props['storeNoCommit'] | Should -BeExactly $false
        }
    }
}
