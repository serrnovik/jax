function Get-JaxCommonParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $BoundParameters
    )

    $commonParams = @(
        'verbose', 'debug', 'erroraction', 'errorvariable',
        'warningaction', 'warningvariable', 'informationaction',
        'informationvariable', 'outvariable', 'outbuffer',
        'pipelinevariable', 'whatif', 'confirm', 'passthru'
    )

    $result = @{}
    foreach ($key in $BoundParameters.Keys) {
        if ($key.ToLowerInvariant() -in $commonParams) {
            $result[$key] = $BoundParameters[$key]
        }
    }

    return $result
}
