function Get-JaxOnlySelectors {
    [CmdletBinding()]
    param (
        [AllowNull()]
        $Only
    )

    $selectors = @()
    foreach ($value in @($Only)) {
        if ($null -eq $value) {
            continue
        }

        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        foreach ($part in @($text -split ',')) {
            $selector = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($selector)) {
                continue
            }

            $selectors += $selector
        }
    }

    return @($selectors)
}
