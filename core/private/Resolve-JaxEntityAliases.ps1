function Resolve-JaxEntityAliases {
    [CmdletBinding()]
    param (
        [string] $Key,
        [System.Collections.IDictionary] $AliasesMap,
        [object] $AdditionalAliases
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $aliases = @()
    if ($AliasesMap -is [System.Collections.IDictionary] -and -not [string]::IsNullOrWhiteSpace($Key)) {
        $normalizedKey = Convert-JaxRunEntityName -Name $Key @commonParams
        foreach ($mapKey in $AliasesMap.Keys) {
            if ([string]::IsNullOrWhiteSpace($mapKey)) {
                continue
            }
            if (Convert-JaxRunEntityName -Name $mapKey @commonParams -eq $normalizedKey) {
                $value = $AliasesMap[$mapKey]
                if ($value -is [string]) {
                    $aliases += $value
                } elseif ($value -is [System.Collections.IEnumerable]) {
                    $aliases += @($value)
                }
            }
        }
    }

    if ($null -ne $AdditionalAliases) {
        if ($AdditionalAliases -is [string]) {
            $aliases += $AdditionalAliases
        } elseif ($AdditionalAliases -is [System.Collections.IEnumerable]) {
            $aliases += @($AdditionalAliases)
        }
    }

    $aliases = @($aliases | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' } | Select-Object -Unique)
    return $aliases
}
