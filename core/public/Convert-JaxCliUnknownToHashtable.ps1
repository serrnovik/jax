function Convert-JaxCliUnknownToHashtable {
    [CmdletBinding()]
    param (
        [string[]] $Unknown = @()
    )

    $result = @{}
    if ($null -eq $Unknown -or $Unknown.Count -eq 0) {
        return $result
    }

    for ($i = 0; $i -lt $Unknown.Count; $i++) {
        $token = [string]$Unknown[$i]
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }
        if (-not $token.StartsWith('-')) {
            continue
        }

        $trimmed = $token.TrimStart('-')
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        $name = $trimmed
        $value = $true

        if ($trimmed.Contains('=')) {
            $parts = $trimmed.Split('=', 2)
            $name = [string]$parts[0]
            $value = $parts[1]
        } elseif (($i + 1) -lt $Unknown.Count) {
            $next = [string]$Unknown[$i + 1]
            if (-not [string]::IsNullOrWhiteSpace($next) -and -not $next.StartsWith('-')) {
                $value = $next
                $i++
            }
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $result[$name] = $value
    }

    return $result
}
