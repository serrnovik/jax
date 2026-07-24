function Register-JaxPackagingPlugin {
    Register-JaxPlugin -Name 'packaging' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxPackagingPlugin
