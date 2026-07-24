function Merge-JaxHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Base,
        [Parameter()]
        [System.Collections.IDictionary] $Overlay
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    # Preserve ordering where possible (e.g. YAML maps from ConvertFrom-Yaml -Ordered).
    $result = [ordered]@{}
    foreach ($key in $Base.Keys) {
        $baseValue = $Base[$key]
        if ($null -ne $Overlay -and $Overlay.Keys -contains $key) {
            $overlayValue = $Overlay[$key]
            if ((Test-JaxIsDictionary -Value $baseValue) -and (Test-JaxIsDictionary -Value $overlayValue)) {
                $result[$key] = Merge-JaxHashtable -Base $baseValue -Overlay $overlayValue @commonParams
            } else {
                $result[$key] = $overlayValue
            }
        } else {
            $result[$key] = $baseValue
        }
    }

    if ($null -ne $Overlay) {
        foreach ($key in $Overlay.Keys) {
            if ($result.Keys -notcontains $key) {
                $result[$key] = $Overlay[$key]
            }
        }
    }

    return $result
}
