function Get-JaxFlowConfig {
    [CmdletBinding(DefaultParameterSetName = 'Single')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Single')]
        [string] $Path,
        [Parameter(Mandatory = $true, ParameterSetName = 'Multiple')]
        [string[]] $Paths,
        [hashtable] $VariablesOverride,
        [bool] $ExpandVariables = $true,
        [switch] $DontThrowInVariablesExpansion
    )

    $pathsToRead = @()
    if ($PSCmdlet.ParameterSetName -eq 'Multiple') {
        $pathsToRead = @($Paths)
    } else {
        $pathsToRead = @($Path)
    }

    $config = @{}
    foreach ($path in $pathsToRead) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $part = Read-JaxYaml -Path $path
        if ($null -eq $part) {
            continue
        }
        $config = Merge-JaxHashtable -Base $config -Overlay $part
    }

    if ($ExpandVariables) {
        $config = Expand-JaxPlaceholders -Config $config -Override $VariablesOverride -DontThrow:$DontThrowInVariablesExpansion
    }

    return $config
}
