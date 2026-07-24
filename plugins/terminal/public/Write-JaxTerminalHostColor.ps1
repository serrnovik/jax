function Write-JaxTerminalHostColor {
    [CmdletBinding()]
    param(
        [parameter(position = 0)][alias ('Object')]
        [string] $Text,

        [parameter(position = 1)][alias ('C', 'F', 'ForegroundColor', 'FGC')]
        [string] $Color,

        [parameter(position = 2)][alias('BG', 'Background', 'B', 'BGC')]
        [string] $BackgroundColor,

        [alias ('N', 'No', 'Non')][switch]
        $NoNewline
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Color)) {
            Write-Host "$Text" -NoNewline:$NoNewline
            return
        }
        if ([string]::IsNullOrWhiteSpace($BackgroundColor)) {
            $BackgroundColor = $null
        }

        $colorNames = [System.Enum]::GetNames([System.ConsoleColor])
        if (-not [string]::IsNullOrWhiteSpace($Color)) {
            $lookupKey = $Color.ToLowerInvariant()
            if ($script:JaxTerminalColorMap -and $script:JaxTerminalColorMap.ContainsKey($lookupKey)) {
                $Color = $script:JaxTerminalColorMap[$lookupKey]
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($BackgroundColor)) {
            $lookupKey = $BackgroundColor.ToLowerInvariant()
            if ($script:JaxTerminalColorMap -and $script:JaxTerminalColorMap.ContainsKey($lookupKey)) {
                $BackgroundColor = $script:JaxTerminalColorMap[$lookupKey]
            }
        }
        if ($colorNames -contains $Color) {
            if ($null -ne $BackgroundColor -and ($colorNames -contains $BackgroundColor)) {
                Write-Host "$Text" -ForegroundColor $Color -BackgroundColor $BackgroundColor -NoNewline:$NoNewline
            } else {
                Write-Host "$Text" -ForegroundColor $Color -NoNewline:$NoNewline
            }
            return
        }

        if ($Color.StartsWith('#')) {
            $ansiColor = Get-JaxAnsiColor -HexColor $Color
            if (-not [string]::IsNullOrWhiteSpace($BackgroundColor) -and $BackgroundColor.StartsWith('#')) {
                $ansiBackground = Get-JaxAnsiColor -HexColor $BackgroundColor -IsBackground
                Write-Host "${ansiColor}${ansiBackground}$Text`e[0m" -NoNewline:$NoNewline
                return
            }
            Write-Host "${ansiColor}$Text`e[0m" -NoNewline:$NoNewline
            return
        }

        $ansiColor = Convert-ToJaxAnsiColorSequence -Color $Color
        $ansiBackground = if ($BackgroundColor) {
            Convert-ToJaxAnsiColorSequence -Color $BackgroundColor -IsBackground
        } else {
            $null
        }
        if ($null -ne $ansiColor) {
            Write-Host "$ansiColor$ansiBackground$Text`e[0m" -NoNewline:$NoNewline
            return
        }

        Write-Host "$Text" -NoNewline:$NoNewline
    } catch {
        Write-Host $Text -NoNewline:$NoNewline
    }
}
