function Write-JaxRunConfigLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $RunConfig,
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    function ConvertTo-JaxJsonSafeObject {
        param(
            $Value,
            [string] $KeyName = ''
        )

        if ($null -eq $Value) { return $null }

        if (-not [string]::IsNullOrWhiteSpace($KeyName)) {
            $normalizedKey = $KeyName -replace '[-_]', ''
            $sensitiveKeyPattern = '^(token|password|passwd|secret|apikey|accesskey|secretkey|clientsecret|privatekey)$'
            if ($normalizedKey -match $sensitiveKeyPattern) {
                return '[redacted]'
            }
        }

        if ($Value -is [System.Collections.IDictionary]) {
            $ht = @{}
            foreach ($k in $Value.Keys) {
                $keyText = [string]$k
                $ht[$keyText] = ConvertTo-JaxJsonSafeObject -Value $Value[$k] -KeyName $keyText
            }
            return $ht
        }

        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
            $arr = @()
            foreach ($item in $Value) {
                $arr += (ConvertTo-JaxJsonSafeObject -Value $item)
            }
            return $arr
        }

        # PSCustomObject / other objects: preserve as-is unless it has properties.
        if ($Value -is [pscustomobject]) {
            $ht = @{}
            foreach ($p in $Value.PSObject.Properties) {
                $ht[$p.Name] = ConvertTo-JaxJsonSafeObject -Value $p.Value -KeyName $p.Name
            }
            return $ht
        }

        return $Value
    }

    $jsonSafe = ConvertTo-JaxJsonSafeObject -Value $RunConfig
    $content = $jsonSafe | ConvertTo-Json -Depth 12
    return Write-JaxLogFile -Content $content -Category 'run-config' -Extension 'json' -RepoRoot $RepoRoot
}
