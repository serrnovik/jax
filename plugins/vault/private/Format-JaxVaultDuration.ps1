function Format-JaxVaultDuration {
    [CmdletBinding(DefaultParameterSetName = 'Duration')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Duration')]
        [string] $Duration,

        [Parameter(Mandatory, ParameterSetName = 'Seconds')]
        [double] $Seconds
    )

    $original = $Duration
    if ($PSCmdlet.ParameterSetName -eq 'Duration') {
        $trimmed = $Duration.Trim()
        if ($trimmed -match '^(?<hours>\d+)h$') {
            $Seconds = [double]$Matches['hours'] * 3600
        } elseif ($trimmed -match '^(?<minutes>\d+)m$') {
            $Seconds = [double]$Matches['minutes'] * 60
        } elseif ($trimmed -match '^(?<seconds>\d+)s$') {
            $Seconds = [double]$Matches['seconds']
        } else {
            return $trimmed
        }
    }

    if ($Seconds -lt 0) {
        return if ($PSCmdlet.ParameterSetName -eq 'Duration') { $original } else { "$Seconds`s" }
    }

    $totalSeconds = [long][Math]::Floor($Seconds)
    $years = [Math]::Floor($totalSeconds / (365 * 24 * 60 * 60))
    $totalSeconds %= (365 * 24 * 60 * 60)
    $days = [Math]::Floor($totalSeconds / (24 * 60 * 60))
    $totalSeconds %= (24 * 60 * 60)
    $hours = [Math]::Floor($totalSeconds / (60 * 60))
    $totalSeconds %= (60 * 60)
    $minutes = [Math]::Floor($totalSeconds / 60)
    $secondsRemaining = $totalSeconds % 60

    $parts = @()
    if ($years -gt 0) { $parts += "${years}y" }
    if ($days -gt 0) { $parts += "${days}d" }
    if ($hours -gt 0) { $parts += "${hours}h" }
    if ($minutes -gt 0) { $parts += "${minutes}m" }
    if ($secondsRemaining -gt 0 -or $parts.Count -eq 0) { $parts += "${secondsRemaining}s" }
    return ($parts -join ' ')
}
