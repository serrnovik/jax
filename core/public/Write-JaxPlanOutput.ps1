function Write-JaxPlanOutput {
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [switch] $Detailed,
        [hashtable] $Context = @{}
    )

    $items = @($Entities)
    if ($Detailed) {
        $expanded = @()
        foreach ($entity in $items) {
            if ($null -eq $entity) {
                continue
            }
            if ($entity -is [System.Collections.IDictionary] -and $entity.Contains('Runner') -and (Resolve-JaxRunnerName -Name ([string]$entity['Runner']) -ErrorAction SilentlyContinue) -eq 'scenario') {
                # Expansion uses Context so CLI args can be reflected in the plan (and nested references can resolve).
                $expanded += Expand-JaxScenarioEntity -Entity $entity -Context $Context -InheritedArgs @{}
            } else {
                $expanded += $entity
            }
        }
        $items = @($expanded)
        Write-JaxConsoleLine -Text ("🚀 Run plan ({0} entities) 🕵️‍♂️[DETAILED]" -f $items.Count) -Color 'DarkCyan'
    } else {
        Write-JaxConsoleLine -Text ("🚀 Run plan ({0} entities)" -f $items.Count) -Color 'DarkCyan'
    }
    $index = 1
    foreach ($entity in $items) {
        if ($null -eq $entity) {
            $index++
            continue
        }
        Write-Host ""
        Write-JaxConsoleLine -Text ("# {0}" -f $index) -Color 'DarkGray'
        $entry = Format-JaxRunEntityLog -Entity $entity
        $lines = $entry -split [Environment]::NewLine
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }
            if ($trimmed -notmatch ':') {
                Write-JaxConsoleLine -Text ("  {0}" -f $trimmed) -Color 'DarkGray'
                continue
            }
            $parts = $trimmed -split ':', 2
            $label = $parts[0].Trim()
            $value = $parts[1].Trim()

            # Quick plan: do not show args values, only a count.
            if (-not $Detailed -and $label -eq 'Args') {
                continue
            }

            $valueColor = 'White'
            if ($label -eq 'Key' -or $label -eq 'Tasks' -or $label -eq 'Script') {
                $valueColor = 'DeepSkyBlue'
            }
            Write-JaxKeyValueLine -Label $label -Value $value -Indent '  ' -LabelColor 'DarkGray' -ValueColor $valueColor
        }

        $args = $null
        if ($entity -is [System.Collections.IDictionary] -and $entity.Contains('Args')) {
            $args = $entity['Args']
        }
        if (-not $Detailed) {
            if ($args -is [System.Collections.IDictionary] -and $args.Keys.Count -gt 0) {
                Write-JaxKeyValueLine -Label 'Args' -Value '1 parameter set' -Indent '  ' -LabelColor 'DarkGray' -ValueColor 'White'
            }
        } else {
            if ($args -is [System.Collections.IDictionary] -and $args.Keys.Count -gt 0) {
                Write-JaxConsoleLine -Text ("  Parameters (1 set):") -Color 'DarkGray'
                foreach ($k in @($args.Keys | Sort-Object)) {
                    $v = $args[$k]
                    Write-JaxKeyValueLine -Label ([string]$k) -Value ([string]$v) -Indent '    ' -LabelColor 'DarkGray' -ValueColor 'White'
                }
            }
        }
        $index++
    }
}
