function Convert-JaxArgsToCommandLine {
    [CmdletBinding()]
    param (
        [hashtable] $Args
    )

    if ($null -eq $Args -or $Args.Count -eq 0) {
        return ''
    }

    $parts = @()
    foreach ($key in $Args.Keys) {
        $value = $Args[$key]
        if ($value -is [bool]) {
            if ($value) {
                $parts += "-$key"
            }
            continue
        }

        $escaped = ($value.ToString() -replace "'", "''")
        $parts += "-$key '$escaped'"
    }

    return ($parts -join ' ')
}
