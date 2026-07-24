function Initialize-JaxPsakeProvider {
    [CmdletBinding()]
    param (
        [string] $RepoRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $bundled = Join-Path (Get-JaxToolRoot) 'psake/src/psake.psm1'
    if (Test-Path -LiteralPath $bundled -PathType Leaf) {
        Import-Module $bundled -Force -DisableNameChecking -ErrorAction SilentlyContinue
        $command = Get-Command -Name Invoke-psake -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            if ($command.Module -and $command.Module.Path -and ($command.Module.Path -eq $bundled)) {
                return
            }
            return
        }
    }

    $command = Get-Command -Name Invoke-psake -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return
    }

    $installedModule = Get-Module -ListAvailable -Name psake -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $installedModule) {
        try {
            Install-Module -Name psake -RequiredVersion 4.9.1 -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        } catch {
            throw "Failed to auto-install psake. Error: $($_.Exception.Message)"
        }
    }

    Import-Module psake -Force -ErrorAction SilentlyContinue

    $command = Get-Command -Name Invoke-psake -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw 'Invoke-psake is not available. Ensure psake is installed.'
    }
}
