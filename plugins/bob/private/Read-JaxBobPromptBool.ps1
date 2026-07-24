function Read-JaxBobPromptBool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Prompt,
        [bool] $Default,
        [System.Collections.Queue] $InputQueue
    )

    if ($null -ne $InputQueue -and $InputQueue.Count -gt 0) {
        $response = $InputQueue.Dequeue()
    } else {
        $suffix = if ($Default) { ' [Y/n]' } else { ' [y/N]' }
        $response = Read-Host -Prompt "$Prompt$suffix"
    }

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    switch ($response.Trim().ToLower()) {
        'y' { return $true }
        'yes' { return $true }
        'true' { return $true }
        '1' { return $true }
        'n' { return $false }
        'no' { return $false }
        'false' { return $false }
        '0' { return $false }
        default { return $Default }
    }
}
