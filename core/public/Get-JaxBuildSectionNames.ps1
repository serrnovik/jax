function Get-JaxBuildSectionNames {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Config
    )

    $defaults = @('build', 'modules')
    if ($null -eq $Config) {
        return $defaults
    }

    $names = $null
    if ($Config.Keys -contains 'buildSectionName') {
        $names = @($Config['buildSectionName'])
    } elseif ($Config.Keys -contains 'buildSectionNames') {
        $names = $Config['buildSectionNames']
    }

    if ($names -is [string]) {
        $names = @($names)
    }
    if ($null -ne $names) {
        $filteredNames = New-Object 'System.Collections.Generic.List[string]'
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($name in @($names)) {
            if ([string]::IsNullOrWhiteSpace([string]$name)) {
                continue
            }
            $value = [string]$name
            if ($seen.Add($value)) {
                $filteredNames.Add($value) | Out-Null
            }
        }
        $names = @($filteredNames)
    }

    if ($null -eq $names -or $names.Count -eq 0) {
        return $defaults
    }

    return $names
}
