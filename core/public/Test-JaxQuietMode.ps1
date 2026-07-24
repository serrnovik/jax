function Test-JaxQuietMode {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Resolved,
        [hashtable] $Context
    )

    # -Verbose / -Debug always wins (full output for diagnostics).
    if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
        return $false
    }
    if ($null -ne $Context -and ($Context['Verbose'] -or $Context['Debug'])) {
        return $false
    }

    # Per-run override (-NoQuiet / -nq) wins over saved or current quiet.
    if ($null -ne $Resolved -and $Resolved.Contains('noQuiet') -and [bool]$Resolved['noQuiet']) {
        return $false
    }
    if ($null -ne $Context -and $Context.Contains('NoQuiet') -and [bool]$Context['NoQuiet']) {
        return $false
    }

    if ($null -ne $Resolved -and $Resolved.Contains('quiet') -and [bool]$Resolved['quiet']) {
        return $true
    }
    if ($null -ne $Context -and $Context.Contains('Quiet') -and [bool]$Context['Quiet']) {
        return $true
    }
    return $false
}
