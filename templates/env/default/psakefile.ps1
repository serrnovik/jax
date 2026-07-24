# Psakefile for {{EnvName}} environment
# Defines PowerShell tasks available in this environment.

Include "../common/psakefile.ps1"

properties {
    $my_property = "default_value"
}

task default -depends EnvInfo

task EnvInfo -description "Prints environment info" {
    Write-Host "Environment: {{EnvName}}" -ForegroundColor Cyan
    Write-Host "This is a scaffolded Psakefile task." -ForegroundColor Gray
}
