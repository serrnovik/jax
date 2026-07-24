function Merge-JaxRunEntityList {
    [CmdletBinding()]
    param (
        [object[]] $Base,
        [object[]] $Add
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

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
            $result[$position] = $item
        } else {
            $index[$normalized] = $result.Count
            $result.Add($item) | Out-Null
        }
    }

    return @($result)
}
