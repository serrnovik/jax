function Register-JaxNodePlugin {
    Register-JaxPlugin -Name 'node' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxNodePlugin
