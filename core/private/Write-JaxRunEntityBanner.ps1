function Write-JaxRunEntityBanner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [string] $RunnerName
    )

    $key = Get-JaxRunEntityKey -Entity $Entity
    $runner = $RunnerName
    if ([string]::IsNullOrWhiteSpace($runner)) {
        if ($Entity.Contains('Runner')) {
            $runner = $Entity['Runner']
        }
    }

    $provenance = $null
    $source = $null
    $aliases = $null
    if ($Entity.Contains('Provenance')) { $provenance = $Entity['Provenance'] }
    if ($Entity.Contains('SourcePath')) { $source = $Entity['SourcePath'] }
    if ($Entity.Contains('Aliases')) { $aliases = $Entity['Aliases'] }

    $lineSpecs = @()
    $lineSpecs += @{ Label = '🚀'; Value = $key; Separator = ' ' }
    if (-not [string]::IsNullOrWhiteSpace($runner)) {
        $lineSpecs += @{ Label = '🛸 Runner'; Value = $runner; Separator = ': ' }
    }
    if (-not [string]::IsNullOrWhiteSpace($provenance)) {
        $lineSpecs += @{ Label = '🔍 Provenance'; Value = $provenance; Separator = ': ' }
    }
    if (-not [string]::IsNullOrWhiteSpace($source)) {
        $lineSpecs += @{ Label = '📄 Source'; Value = $source; Separator = ': ' }
    }
    if ($null -ne $aliases -and @($aliases).Count -gt 0) {
        $lineSpecs += @{ Label = '🏷️ Aliases'; Value = ($aliases -join ', '); Separator = ': ' }
    }

    $maxLen = 0
    foreach ($spec in $lineSpecs) {
        $labelText = $spec.Label
        $valueText = $spec.Value
        $sep = $spec.Separator
        $raw = $labelText
        if (-not [string]::IsNullOrWhiteSpace($valueText)) {
            $raw = "{0}{1}{2}" -f $labelText, $sep, $valueText
        }
        if ($raw.Length -gt $maxLen) {
            $maxLen = $raw.Length
        }
    }
    if ($maxLen -lt 10) {
        $maxLen = 10
    }

    $top = "┏" + ("━" * ($maxLen + 2)) + "┓"
    $bottom = "┗" + ("━" * ($maxLen + 2)) + "┛"

    Write-JaxConsoleLine -Text $top -Color 'DarkCyan'
    foreach ($spec in $lineSpecs) {
        $labelColor = 'DarkGray'
        $valueColor = 'White'
        $finalValue = $spec.Value
        $visLen = $null

        if ($spec.Label -eq '🚀') {
            $labelColor = 'DarkCyan'
            $valueColor = 'DarkCyan'
        }
        if ($spec.Label -eq '📄 Source') {
            $valueColor = 'Gray'
            $finalValue = Format-JaxPathLink -Path $spec.Value
            $visLen = $spec.Value.Length
        }

        $params = @{
            Label = $spec.Label
            Value = $finalValue
            Separator = $spec.Separator
            MaxLen = $maxLen
            FrameColor = 'DarkCyan'
            LabelColor = $labelColor
            ValueColor = $valueColor
        }
        if ($null -ne $visLen) {
            $params['ValueVisibleLength'] = $visLen
        }
        Write-JaxFramedKeyValueLine @params
    }
    Write-JaxConsoleLine -Text $bottom -Color 'DarkCyan'
}
