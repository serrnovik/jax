function Register-JaxPersistentSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Default,
        [string] $Scope = 'core'
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Key=$Key"

    if (-not (Get-Variable -Name JaxStateDefaults -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxStateDefaults = @{}
    }

    if (-not $script:JaxStateDefaults.ContainsKey($Scope)) {
        $script:JaxStateDefaults[$Scope] = @{}
    }

    $script:JaxStateDefaults[$Scope][$Key] = $Default
}
