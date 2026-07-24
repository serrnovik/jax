function Register-JaxTestsPlugin {
    Register-JaxPlugin -Name 'tests' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxTestsPlugin
