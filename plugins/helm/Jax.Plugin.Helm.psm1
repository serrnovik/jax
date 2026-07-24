function Register-JaxHelmPlugin {
    Register-JaxPlugin -Name 'helm' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxHelmPlugin
