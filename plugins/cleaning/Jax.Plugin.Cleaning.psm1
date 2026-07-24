function Register-JaxCleaningPlugin {
    $hooks = @{
        BeforeSequenceResolve = {
            param($hook)
            $config = $hook.PluginConfig
            if ($null -eq $config -or -not ($config.ContainsKey('enabled')) -or -not $config['enabled']) {
                return
            }
            $hook.Context['CleaningInvoked'] = $true
        }
    }

    Register-JaxPlugin -Name 'cleaning' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxCleaningPlugin
