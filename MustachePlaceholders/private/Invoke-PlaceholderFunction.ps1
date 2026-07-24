function Invoke-PlaceholderFunction {
    [cmdletbinding()]
    param (
        $inputValue, # this.
        [string] $functionName,
        [object[]] $extraArgs = @()
    )

    $functions = $global:PlaceholderFunctions
    if ($null -eq $functions) {
        $functions = $global:BOB_FUNCTIONS
    }

    if ($null -ne $functions -and $null -ne $functions[$functionName]) {
        # Running function like this
        # Invoke-Command $f -ArgumentList @("SDFASDdasd", @("_1111"))

        $thisValue = $inputValue

        if (!$extraArgs) {
            $extraArgs = @() # coerce value to empty array if it's not set, empty string, empty array, null etc.
        }

        # Use unary comma to box arrays as a single argument so we don't splat array elements
        $functionArgs = , $thisValue
        if ($extraArgs -and $extraArgs.Count -gt 0) {
            $functionArgs += $extraArgs
        }

        Invoke-Command $functions[$functionName] -ArgumentList $functionArgs
    } else {
        throw "Unsupported function name: '$functionName'. Could not resolve '$inputValue'."
    }
}
