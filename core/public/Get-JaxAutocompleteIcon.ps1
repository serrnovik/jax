function Get-JaxAutocompleteIcon {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [Parameter(Mandatory = $true)]
        [ValidateSet('client', 'flow')]
        [string] $Type,
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [string] $DefaultIcon
    )

    $autoCfg = @{}
    if ($Config.Contains('autocomplete') -and $Config['autocomplete'] -is [System.Collections.IDictionary]) {
        $autoCfg = $Config['autocomplete']
    }

    $iconMapKey = if ($Type -eq 'client') { 'clientIcons' } else { 'flowIcons' }
    if ([string]::IsNullOrWhiteSpace($DefaultIcon)) {
        $DefaultIcon = if ($Type -eq 'client') { '📁' } else { '⚙️' }
    }

    if ($autoCfg.Contains($iconMapKey) -and $autoCfg[$iconMapKey] -is [System.Collections.IDictionary]) {
        $map = $autoCfg[$iconMapKey]
        if ($map.Contains($Key)) {
            $v = $map[$Key]
            if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) {
                return $v
            }
        }
    }

    return $DefaultIcon
}
