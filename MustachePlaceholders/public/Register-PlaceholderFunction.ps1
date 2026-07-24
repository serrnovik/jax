function Register-PlaceholderFunction {
    param(
        [string] $name,
        [scriptblock] $body
    )

    $functions = $global:PlaceholderFunctions
    if (!$functions) {
        $functions = $global:BOB_FUNCTIONS
    }

    if (!$functions) {
        $functions = @{}
    }

    if ($functions[$name]) {
        Write-Debug "Placeholder function '$name' was already registered: new value will override previously registered one"
    }

    $functions[$name] = $body
    $global:PlaceholderFunctions = $functions
    $global:BOB_FUNCTIONS = $functions
}
