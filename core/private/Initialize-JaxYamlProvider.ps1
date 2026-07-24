function Initialize-JaxYamlProvider {
    [CmdletBinding()]
    param ()

    # Prefer built-in YAML cmdlets (PowerShell 7.2+). In some developer shells,
    # module auto-loading can be disabled, so Get-Command may not "see" these until
    # Microsoft.PowerShell.Utility is explicitly imported.
    try {
        Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null
    } catch {
        # ignore; we'll fall back below
    }

    $convertCommand = Get-Command -Name ConvertFrom-Yaml -CommandType Cmdlet -ErrorAction SilentlyContinue
    $convertToCommand = Get-Command -Name ConvertTo-Yaml -CommandType Cmdlet -ErrorAction SilentlyContinue
    if ($null -ne $convertCommand -and $null -ne $convertToCommand) {
        return
    }

    # If cmdlets are not available, try the declared powershell-yaml dependency.
    $convertCommand = Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue
    $convertToCommand = Get-Command -Name ConvertTo-Yaml -ErrorAction SilentlyContinue
    if ($null -ne $convertCommand -and $null -ne $convertToCommand) {
        return
    }

    $requiredVersion = [version]'0.4.12'
    $installedModule = Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -eq $requiredVersion } |
        Select-Object -First 1
    if ($null -eq $installedModule) {
        throw @"
ConvertFrom-Yaml is not available, and required module 'powershell-yaml' $requiredVersion is not installed.

Install it from a trusted PowerShell repository:
  Install-Module -Name powershell-yaml -Scope CurrentUser -RequiredVersion $requiredVersion
"@
    }

    try {
        Import-Module $installedModule.Path -Force -ErrorAction Stop
    } catch {
        $message = $_.Exception.Message
        throw @"
Failed to import the 'powershell-yaml' module.

This often happens on some platforms when the module compiles helper C# via Add-Type and is missing references (e.g. netstandard).

Recommended fix:
  - Upgrade PowerShell to a version that includes ConvertFrom-Yaml / ConvertTo-Yaml (PowerShell 7.2+), so Jax doesn't need powershell-yaml.

Original error:
  $message
"@
    }

    $convertCommand = Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue
    $convertToCommand = Get-Command -Name ConvertTo-Yaml -ErrorAction SilentlyContinue
    if ($null -eq $convertCommand -or $null -eq $convertToCommand) {
        throw "ConvertFrom-Yaml / ConvertTo-Yaml are still not available after importing 'powershell-yaml'."
    }
}
