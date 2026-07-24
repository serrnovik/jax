function Read-JaxPromptString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [string] $Default,
        [System.Collections.Queue] $InputQueue
    )

    if ($null -ne $InputQueue) {
        if ($InputQueue.Count -gt 0) {
            $response = $InputQueue.Dequeue()
        } else {
            return $Default
        }
    } else {
        $suffix = if ([string]::IsNullOrEmpty($Default)) { '' } else { " [$Default]" }
        $response = Read-Host -Prompt "$Prompt$suffix"
    }

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    $trimmed = $response.Trim()
    if ($trimmed -in @('clear', 'none', '-')) {
        return ''
    }

    return $trimmed
}
