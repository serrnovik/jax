function Get-CommonParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $BoundParameters
    )

    if ($null -eq $BoundParameters) {
        throw 'BoundParameters is null'
    }

    $commonParams = $PowershellReservedCommonParams
    $commonParamsHT = @{}

    foreach ($key in $BoundParameters.Keys) {
        if ($key.ToLower() -in $commonParams) {
            $commonParamsHT[$key] = $BoundParameters[$key]
        }
    }

    if ($VerbosePreference -eq 'Continue') {
        $commonParamsHT['Verbose'] = $true
    }

    if ($DebugPreference -eq 'Continue') {
        $commonParamsHT['Debug'] = $true
    }

    return $commonParamsHT
}
