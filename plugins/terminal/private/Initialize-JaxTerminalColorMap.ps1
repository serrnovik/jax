function Initialize-JaxTerminalColorMap {
    [CmdletBinding()]
    param ()

    if ($script:JaxTerminalColorMapInitialized) {
        return
    }
    $script:JaxTerminalColorMapInitialized = $true
    $script:JaxTerminalColorMap = @{}

    $pluginRoot = Split-Path -Parent $PSScriptRoot
    $paths = @(
        Join-Path $pluginRoot 'assets/colornames.bestof.csv',
        Join-Path $pluginRoot 'assets/colornames.short.csv',
        Join-Path $pluginRoot 'assets/colorsnames.small.csv',
        Join-Path $pluginRoot 'assets/colorsnames.html.csv'
    )

    foreach ($path in $paths) {
        if (-not (Test-Path -Path $path -PathType Leaf)) {
            continue
        }
        try {
            $rows = Import-Csv -Path $path
            foreach ($row in $rows) {
                if (-not $row.name -or -not $row.hex) {
                    continue
                }
                $nameKey = $row.name.ToString().Trim().ToLowerInvariant()
                if ([string]::IsNullOrWhiteSpace($nameKey)) {
                    continue
                }
                $hex = $row.hex.ToString().Trim()
                if ([string]::IsNullOrWhiteSpace($hex)) {
                    continue
                }
                if (-not $hex.StartsWith('#')) {
                    $hex = "#$hex"
                }
                if (-not $script:JaxTerminalColorMap.ContainsKey($nameKey)) {
                    $script:JaxTerminalColorMap[$nameKey] = $hex
                }
            }
        } catch {
        }
    }
}
