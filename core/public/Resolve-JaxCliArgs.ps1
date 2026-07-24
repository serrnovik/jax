function Resolve-JaxCliArgs {
    [CmdletBinding()]
    param (
        [string[]] $Args,
        [System.Collections.IDictionary] $Defaults
    )

    Initialize-JaxCliParameterRegistry

    $definitions = Get-JaxCliParameters
    $lookup = @{}
    foreach ($definition in $definitions) {
        $lookup[$definition.Name] = $definition
        foreach ($alias in $definition.Aliases) {
            $lookup[$alias] = $definition
        }
    }

    $values = @{}
    if ($null -ne $Defaults) {
        foreach ($key in $Defaults.Keys) {
            $values[$key] = $Defaults[$key]
        }
    }

    $unknown = @()
    $remaining = @()

    if ($null -eq $Args) {
        $Args = @()
    }

    for ($index = 0; $index -lt $Args.Count; $index++) {
        $arg = $Args[$index]
        if (-not $arg.StartsWith('-')) {
            $remaining += $arg
            continue
        }

        $token = $arg.TrimStart('-')
        if ([string]::IsNullOrWhiteSpace($token)) {
            $remaining += $arg
            continue
        }

        $name = $token
        $value = $null
        if ($token.Contains('=')) {
            $parts = $token.Split('=', 2)
            $name = $parts[0]
            $value = $parts[1]
        }

        $normalized = $name.ToLowerInvariant()
        if (-not $lookup.ContainsKey($normalized)) {
            $unknown += $arg
            if ($null -eq $value -and ($index + 1) -lt $Args.Count) {
                $next = $Args[$index + 1]
                if (-not $next.StartsWith('-')) {
                    $unknown += $next
                    $index++
                }
            }
            continue
        }

        $definition = $lookup[$normalized]
        if ($definition.Type -eq 'switch') {
            $values[$definition.Name] = Convert-JaxCliSwitchValue -Value $value
            continue
        }

        if ($null -eq $value -and ($index + 1) -lt $Args.Count) {
            $next = $Args[$index + 1]
            if (-not $next.StartsWith('-')) {
                $value = $next
                $index++
            }
        }

        $values[$definition.Name] = $value
    }

    return @{
        Values    = $values
        Unknown   = $unknown
        Remaining = $remaining
    }
}
