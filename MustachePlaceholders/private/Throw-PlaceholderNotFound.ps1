function Throw-PlaceholderNotFound {
    [cmdletbinding()]
    param (
        [string] $variable,
        [string] $path,
        [string[]] $sourcePaths
    )

    $sourceInfo = $null
    $searched = @()
    if ($null -ne $sourcePaths -and @($sourcePaths).Count -gt 0) {
        $needleEscaped = [regex]::Escape($variable)
        # Match both {{ var }} and {{{ var }}} forms, and allow pipelines: {{ var | fn() }}
        $matchRegex = [regex]"\{\{\{?\s*$needleEscaped(\s*[|}])"

        foreach ($p in @($sourcePaths) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
            if (-not (Test-Path -LiteralPath $p)) {
                continue
            }
            $searched += $p
            try {
                $lineNo = 0
                foreach ($line in (Get-Content -LiteralPath $p -ErrorAction Stop)) {
                    $lineNo++
                    if ($matchRegex.IsMatch($line)) {
                        $trimmed = $line.Trim()
                        $sourceInfo = "Source: ${p}:${lineNo}`n> $trimmed"
                        break
                    }
                }
            } catch {
                # best effort only
            }
            if ($null -ne $sourceInfo) {
                break
            }
        }
    }

    $suffixParts = @()
    if (-not [string]::IsNullOrWhiteSpace($sourceInfo)) {
        $suffixParts += $sourceInfo
    } elseif ($searched.Count -gt 0) {
        $suffixParts += ("Source: <not found in {0} searched files>" -f $searched.Count)
    } elseif ($null -ne $sourcePaths -and @($sourcePaths).Count -gt 0) {
        $suffixParts += ("Source: <no readable files in SourcePaths ({0})>" -f (@($sourcePaths).Count))
    }
    if ($searched.Count -gt 0) {
        $suffixParts += "Searched:"
        $maxList = 10
        $shown = @($searched | Select-Object -First $maxList)
        foreach ($p in $shown) {
            $suffixParts += ("- {0}" -f $p)
        }
        if ($searched.Count -gt $maxList) {
            $suffixParts += ("- … (+{0} more)" -f ($searched.Count - $maxList))
        }
    }
    $suffix = if ($suffixParts.Count -gt 0) { " ($($suffixParts -join "`n"))" } else { "" }

    throw "Can't substitute value of '$variable': not defined (in '$path').$suffix"
}
