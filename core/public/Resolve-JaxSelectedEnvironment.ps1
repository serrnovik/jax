function Resolve-JaxSelectedEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $Environments,
        [string] $Env,
        [string] $Client
    )

    if ($null -eq $Environments -or $Environments.Count -eq 0) {
        return $null
    }

    $target = $null
    if (-not [string]::IsNullOrWhiteSpace($Env) -and -not [string]::IsNullOrWhiteSpace($Client)) {
        if ($Env.Contains('/')) {
            $target = $Env
        } else {
            $target = "$Client/$Env"
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($Env)) {
        $target = $Env
    } elseif (-not [string]::IsNullOrWhiteSpace($Client)) {
        $target = "$Client/"
    }

    if ([string]::IsNullOrWhiteSpace($target)) {
        return $Environments[0]
    }

    $targetLower = $target.ToLowerInvariant()

    $exactMatch = $null
    $aliasMatches = @()
    $prefixMatches = @()

    foreach ($envEntry in $Environments) {
        $name = $envEntry.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $nameLower = $name.ToLowerInvariant()
        if ($nameLower -eq $targetLower) {
            $exactMatch = $envEntry
            break
        }
        if ($nameLower.StartsWith($targetLower)) {
            $prefixMatches += $envEntry
        }

        $envEntryHasAliases = ($null -ne $envEntry) -and ($envEntry.PSObject.Properties.Match('Aliases').Count -gt 0)
        if (-not $envEntryHasAliases) {
            continue
        }
        foreach ($alias in @($envEntry.Aliases)) {
            if ([string]::IsNullOrWhiteSpace([string]$alias)) {
                continue
            }
            $aliasLower = ([string]$alias).ToLowerInvariant()
            if ($aliasLower -eq $targetLower) {
                $aliasMatches += $envEntry
            }
        }
    }

    if ($null -ne $exactMatch) {
        return $exactMatch
    }

    if ($aliasMatches.Count -eq 1) {
        return $aliasMatches[0]
    }

    if ($aliasMatches.Count -gt 1) {
        $matchedNames = @($aliasMatches | ForEach-Object { $_.Name } | Sort-Object -Unique)
        $matchedNamesText = $matchedNames -join ', '
        throw "Environment alias '$target' is ambiguous. Use one of: $matchedNamesText."
    }

    if ($prefixMatches.Count -gt 0) {
        return $prefixMatches[0]
    }

    throw "Environment '$target' was not found."
}
