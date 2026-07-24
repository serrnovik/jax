function Expand-PlaceholderPipelineRec {
    [cmdletbinding()]
    param (
        $value,
        [string] $pipeline
    )

    $pipeline = $pipeline.Trim()
    if (-not $pipeline.StartsWith("|")) {
        # should not get here, just in case
        throw "Invalid pipeline element '$pipeline' for the value '$value'"
    }
    $pipeline = $pipeline.Substring(1).Trim() # here we have something like 'toLower() | toUpper()'

    $currentExpressionString = $pipeline
    $restOfPipeline = ""
    if ($pipeline.IndexOf('|') -gt 0) {
        $currentExpressionString = $pipeline.Substring(0, $pipeline.IndexOf('|')).Trim() # eg: toLower()
        $restOfPipeline = $pipeline.Substring($pipeline.IndexOf('|')).Trim() # eg: | toUpper()'
    }

    # start to identify function:
    $functionNameGroup = "functionname"
    $functionArgsGroup = "functionargs"
    # we don\t really need variables, so check for variables are minimal. Improve if this functionalitiy is needed
    $FUNCTION_REGEXP_ST = "^(?<$functionNameGroup>[a-zA-Z0-9_]+)?(\((?<$functionArgsGroup>.*)\))?" # https://regex101.com/r/5CIzOv/1
    # Valid examples:
    # fn1('dfdf', 'dfdf', adsf, )
    # fn2
    # fn3(234)
    # fn4()
    $fnRegex = [regex]$FUNCTION_REGEXP_ST
    $functionName = ""
    $functionArgs = @()

    $fnMatchList = $fnRegex.Matches($currentExpressionString)
    if ($fnMatchList.Count -eq 1) {
        # there should only be 1 match. Otherwise more than one function like expression passed, which is error
        $fnGroup = $fnMatchList.Groups | Where-Object { $_.Name -eq $functionNameGroup }
        $fnARgsGroup = $fnMatchList.Groups | Where-Object { $_.Name -eq $functionArgsGroup }
        if (@($fnGroup).Count -eq 1) {
            $functionName = $fnGroup.Value.Trim()
        }
        if (($fnARgsGroup).Count -eq 1) {
            # Parse arguments safely without Invoke-Expression
            $rawVars = $fnARgsGroup.Value.Trim().Split(',')
            foreach ($raw in $rawVars) {
                $tok = $raw.Trim()
                if ([string]::IsNullOrWhiteSpace($tok)) { continue }

                # full arrays support todo if needed.
                # Empty array/object tokens -> coerce to empty string to avoid '[]' later being executed anywhere
                if ($tok -match '^\[\s*\]$') { $functionArgs += @(); continue }
                if ($tok -match '^\{\s*\}$') { $functionArgs += @{}; continue }

                # Quoted strings
                if ($tok.StartsWith("'") -and $tok.EndsWith("'")) { $functionArgs += $tok.Trim("'"); continue }
                if ($tok.StartsWith('"') -and $tok.EndsWith('"')) { $functionArgs += $tok.Trim('"'); continue }

                # Booleans
                if ($tok -ieq 'true') { $functionArgs += $true; continue }
                if ($tok -ieq 'false') { $functionArgs += $false; continue }

                # Numbers
                if ($tok -match '^[+-]?[0-9]+$') { $functionArgs += [int]$tok; continue }
                if ($tok -match '^[+-]?[0-9]*\.[0-9]+$') { $functionArgs += [double]$tok; continue }

                # Fallback: pass as raw string token
                $functionArgs += $tok
            }
        }
    }

    if ($functionName -eq "") {
        throw "Invalid function expression ' $currentExpressionString'. Should match: '$FUNCTION_REGEXP_ST' and have only one function with correct but optional variables. . Could not resolve '$inputValue'"
    }

    $resolvedCurrentValue = Invoke-PlaceholderFunction -inputValue $value -functionName $functionName -extraArgs $functionArgs

    if ($restOfPipeline -ne "") {
        # dive to next iteration
        return Expand-PlaceholderPipelineRec -value $resolvedCurrentValue -pipeline $restOfPipeline
    } else {
        return $resolvedCurrentValue
    }
    # $PIPELINE_PATTERN = "\{\{\s*([a-zA-Z0-9_]+\??(\??\.[a-zA-Z0-9_]+)*)\s*(?<$pipeLineGroupName>\|.*)?\}\}"  # https://regex101.com/r/IBFgBT/1


}