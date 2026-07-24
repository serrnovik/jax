function Test-JaxRunEntityIsScript {
    [CmdletBinding()]
    param (
        $Entity
    )

    if ($null -eq $Entity) {
        return $false
    }

    $runner = $null
    $script = $null
    if ($Entity -is [System.Collections.IDictionary]) {
        if ($Entity.Contains('Runner')) { $runner = $Entity['Runner'] }
        if ($Entity.Contains('Script')) { $script = $Entity['Script'] }
    } else {
        $props = $Entity.PSObject.Properties
        if ($props.Match('Runner').Count -gt 0) { $runner = $Entity.Runner }
        if ($props.Match('Script').Count -gt 0) { $script = $Entity.Script }
    }

    if (-not [string]::IsNullOrWhiteSpace($script)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($runner)) {
        return $false
    }

    $normalized = Resolve-JaxRunnerName -Name $runner
    return $normalized -eq 'script' -or $normalized -eq 'pwshscript'
}
