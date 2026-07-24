function Register-JaxTeamcityPlugin {
    $hooks = @{
        BeforeSequenceResolve = {
            param($hook)

            $context = $hook.Context

            $pluginConfig = $hook.PluginConfig
            if ($pluginConfig -and $pluginConfig.Contains('enabled') -and (-not [bool]$pluginConfig['enabled'])) {
                return
            }

            $buildCounter = 100
            if ($pluginConfig -and $pluginConfig.Contains('defaultBuildCounter')) {
                $configuredDefault = $pluginConfig['defaultBuildCounter']
                $parsedDefault = 0
                if ($configuredDefault -is [int] -and $configuredDefault -gt 0) {
                    $buildCounter = $configuredDefault
                } elseif ([int]::TryParse([string]$configuredDefault, [ref]$parsedDefault) -and $parsedDefault -gt 0) {
                    $buildCounter = $parsedDefault
                }
            }

            if (Test-Path Env:BUILD_NUMBER) {
                $raw = (Get-Item Env:BUILD_NUMBER).Value
                $parsed = 0
                if ([int]::TryParse($raw, [ref]$parsed) -and $parsed -gt 0) {
                    $buildCounter = $parsed
                }
            }

            $defaults = @{
                env = @{
                    tc = @{
                        source = @{
                            chain = @{
                                build = @{
                                    counter = $buildCounter
                                }
                            }
                        }
                        build  = @{
                            counter = $buildCounter
                        }
                    }
                }
            }

            $baseOverride = @{}
            if ($context.ContainsKey('VariablesOverride') -and $context['VariablesOverride'] -is [System.Collections.IDictionary]) {
                $baseOverride = $context['VariablesOverride']
            }
            $context['VariablesOverride'] = Merge-JaxHashtable -Base $defaults -Overlay $baseOverride
            Write-Debug ("[teamcity] VariablesOverride set env.tc.*.build.counter='{0}'" -f $buildCounter)
        }
    }

    $sourcePath = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        $sourcePath = $MyInvocation.MyCommand.ScriptBlock.File
    }

    Register-JaxPlugin -Name 'teamcity' -Hooks $hooks -SourcePath $sourcePath
}
