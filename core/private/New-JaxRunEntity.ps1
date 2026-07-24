function New-JaxRunEntity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [string] $ScenarioName,
        [string] $ProvenancePath
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    return [ordered]@{
        Key        = $Key
        Runner     = 'psake'
        Tasks      = @()
        Script     = $null
        Args       = $null
        PsakeFile  = $null
        Container  = $null
        Scenario   = $ScenarioName
        Provenance = 'scenario'
        SourcePath = $ProvenancePath
    }
}
