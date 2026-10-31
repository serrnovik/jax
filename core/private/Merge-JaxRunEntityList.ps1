function Merge-JaxRunEntityList {
    [CmdletBinding()]
    param (
        [object[]] $Base,
        [object[]] $Add
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    if ($DebugPreference -ne 'SilentlyContinue') { Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)" }

    $result = New-Object 'System.Collections.ArrayList'
    $index = @{}

    foreach ($item in @($Base)) {
        if ($null -eq $item) {
            continue
        }
        $key = Get-JaxRunEntityKey -Entity $item @commonParams
        $normalized = Convert-JaxRunEntityName -Name $key @commonParams
        if ([string]::IsNullOrWhiteSpace($normalized)) {
            $result.Add($item) | Out-Null
            continue
        }
        $index[$normalized] = $result.Count
        $result.Add($item) | Out-Null
    }

    foreach ($item in @($Add)) {
        if ($null -eq $item) {
            continue
        }
        $key = Get-JaxRunEntityKey -Entity $item @commonParams
        $normalized = Convert-JaxRunEntityName -Name $key @commonParams
        if ([string]::IsNullOrWhiteSpace($normalized)) {
            $result.Add($item) | Out-Null
            continue
        }
        if ($index.ContainsKey($normalized)) {
            $position = $index[$normalized]
            $existing = $result[$position]
            # A build module (psake -> module) is not replaced by a non-module entry of the
            # same short name (scripts/<name>/run/<name>.ps1 vs the <name> module).
            # Every other precedence (env over common, script over task) is unchanged.
            $existingIsModule = $existing -is [System.Collections.IDictionary] -and $existing.Contains('Provenance') -and [string]$existing['Provenance'] -eq 'psake -> module'
            $itemIsModule = $item -is [System.Collections.IDictionary] -and $item.Contains('Provenance') -and [string]$item['Provenance'] -eq 'psake -> module'
            if (-not $existingIsModule -or $itemIsModule) {
                $result[$position] = $item
            }
        } else {
            $index[$normalized] = $result.Count
            $result.Add($item) | Out-Null
        }
    }

    return @($result)
}
