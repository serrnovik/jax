function Register-JaxPublishPlugin {
    Register-JaxPlugin -Name 'publish' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxPublishPlugin
