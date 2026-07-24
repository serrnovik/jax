function Register-JaxDotnetPlugin {
    Register-JaxPlugin -Name 'dotnet' -Hooks @{} -SourcePath $MyInvocation.MyCommand.Path
}

Register-JaxDotnetPlugin
