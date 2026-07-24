function Convert-JaxToJsonSafeValue {
    [CmdletBinding()]
    param (
        $Value,
        [int] $MaxDepth = 30,
        [int] $Depth = 0,
        [string] $KeyName = ''
    )

    if ($Depth -ge $MaxDepth) {
        return "[maxDepth:$MaxDepth]"
    }

    if ($null -eq $Value) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($KeyName)) {
        $normalizedKey = $KeyName -replace '[-_]', ''
        $sensitiveKeyPattern = '^(token|password|passwd|secret|apikey|accesskey|secretkey|clientsecret|privatekey)$'
        if ($normalizedKey -match $sensitiveKeyPattern) {
            return '[redacted]'
        }
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($k in $Value.Keys) {
            $keyText = if ($null -eq $k) { '' } else { [string]$k }
            $result[$keyText] = Convert-JaxToJsonSafeValue -Value $Value[$k] -MaxDepth $MaxDepth -Depth ($Depth + 1) -KeyName $keyText
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += Convert-JaxToJsonSafeValue -Value $item -MaxDepth $MaxDepth -Depth ($Depth + 1)
        }
        return $items
    }

    return $Value
}
