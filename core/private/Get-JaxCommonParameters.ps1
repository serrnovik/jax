function Get-JaxCommonParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]
        $BoundParameters
    )

    $common = @{}
    $commonParams = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')

    foreach ($key in $BoundParameters.Keys) {
        if ($commonParams -contains $key) {
            $common[$key] = $BoundParameters[$key]
        }
    }

    return $common
}
