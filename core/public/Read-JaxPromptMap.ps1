function Read-JaxPromptMap {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [hashtable] $Default,
        [System.Collections.Queue] $InputQueue
    )

    $defaultText = ''
    if ($null -ne $Default -and $Default.Count -gt 0) {
        $pairs = @()
        foreach ($key in $Default.Keys) {
            $pairs += "$key=$($Default[$key])"
        }
        $defaultText = $pairs -join ', '
    }

    if ($null -ne $InputQueue) {
        if ($InputQueue.Count -gt 0) {
            $response = $InputQueue.Dequeue()
        } else {
            return $Default
        }
    } else {
        $suffix = if ([string]::IsNullOrEmpty($defaultText)) { '' } else { " [$defaultText]" }
        $response = Read-Host -Prompt "$Prompt$suffix"
    }

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    $trimmed = $response.Trim()
    if ($trimmed -in @('clear', 'none', '-')) {
        return @{}
    }

    $result = @{}
    $pairs = $trimmed -split ','
    foreach ($pair in $pairs) {
        $entry = $pair.Trim()
        if ($entry.Length -eq 0) {
            continue
        }
        $split = $entry.Split('=', 2)
        if ($split.Count -eq 2) {
            $key = $split[0].Trim()
            $value = $split[1].Trim()
            if ($key.Length -gt 0) {
                $result[$key] = $value
            }
        }
    }

    if ($result.Count -eq 0) {
        return $Default
    }

    return $result
}
