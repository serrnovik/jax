function Read-JaxPromptList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [string[]] $Default,
        [System.Collections.Queue] $InputQueue
    )

    $normalizedDefault = @()
    if ($null -ne $Default) {
        $normalizedDefault = @($Default)
    }

    $defaultText = if ($normalizedDefault.Count -gt 0) { $normalizedDefault -join ', ' } else { '' }

    if ($null -ne $InputQueue) {
        if ($InputQueue.Count -gt 0) {
            $response = $InputQueue.Dequeue()
        } else {
            return $normalizedDefault
        }
    } else {
        $suffix = if ([string]::IsNullOrEmpty($defaultText)) { '' } else { " [$defaultText]" }
        $response = Read-Host -Prompt "$Prompt$suffix"
    }

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $normalizedDefault
    }

    $trimmed = $response.Trim()
    if ($trimmed -in @('clear', 'none', '-')) {
        return @()
    }

    return ($trimmed -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}
