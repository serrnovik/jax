function Format-JaxRunEntityLog {
    [CmdletBinding()]
    param (
        $Entity
    )

    $key = Get-JaxRunEntityKey -Entity $Entity
    $runner = $null
    $tasks = $null
    $script = $null
    $source = $null
    $provenance = $null
    $aliases = $null
    $definition = $null
    $args = $null
    $directoryType = $null
    $scenario = $null
    $container = $null

    if ($Entity -is [System.Collections.IDictionary]) {
        if ($Entity.Contains('Runner')) { $runner = $Entity['Runner'] }
        if ($Entity.Contains('Tasks')) { $tasks = $Entity['Tasks'] }
        if ($Entity.Contains('Script')) { $script = $Entity['Script'] }
        if ($Entity.Contains('SourcePath')) { $source = $Entity['SourcePath'] }
        if ($Entity.Contains('Provenance')) { $provenance = $Entity['Provenance'] }
        if ($Entity.Contains('Aliases')) { $aliases = $Entity['Aliases'] }
        if ($Entity.Contains('Definition')) { $definition = $Entity['Definition'] }
        if ($Entity.Contains('Args')) { $args = $Entity['Args'] }
        if ($Entity.Contains('DirectoryType')) { $directoryType = $Entity['DirectoryType'] }
        if ($Entity.Contains('Scenario')) { $scenario = $Entity['Scenario'] }
        if ($Entity.Contains('Container')) { $container = $Entity['Container'] }
    } else {
        $props = $Entity.PSObject.Properties
        if ($props.Match('Runner').Count -gt 0) { $runner = $Entity.Runner }
        if ($props.Match('Tasks').Count -gt 0) { $tasks = $Entity.Tasks }
        if ($props.Match('Script').Count -gt 0) { $script = $Entity.Script }
        if ($props.Match('SourcePath').Count -gt 0) { $source = $Entity.SourcePath }
        if ($props.Match('Provenance').Count -gt 0) { $provenance = $Entity.Provenance }
        if ($props.Match('Aliases').Count -gt 0) { $aliases = $Entity.Aliases }
        if ($props.Match('Definition').Count -gt 0) { $definition = $Entity.Definition }
        if ($props.Match('Args').Count -gt 0) { $args = $Entity.Args }
        if ($props.Match('DirectoryType').Count -gt 0) { $directoryType = $Entity.DirectoryType }
        if ($props.Match('Scenario').Count -gt 0) { $scenario = $Entity.Scenario }
        if ($props.Match('Container').Count -gt 0) { $container = $Entity.Container }
    }

    $lines = @()
    $lines += "Key: $key"
    if (-not [string]::IsNullOrWhiteSpace($runner)) {
        $lines += "Runner: $runner"
    }
    if ($null -ne $tasks) {
        if ($tasks -is [string]) {
            $lines += "Tasks: $tasks"
        } else {
            $lines += "Tasks: $($tasks -join ', ')"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($script)) {
        $lines += "Script: $script"
    }
    if (-not [string]::IsNullOrWhiteSpace($source)) {
        $lines += "Source: $source"
    }
    if ($null -ne $aliases -and @($aliases).Count -gt 0) {
        $lines += "Aliases: $($aliases -join ', ')"
    }
    if (-not [string]::IsNullOrWhiteSpace($scenario)) {
        $lines += "Scenario: $scenario"
    }
    if (-not [string]::IsNullOrWhiteSpace($directoryType)) {
        $lines += "DirectoryType: $directoryType"
    }
    if ($null -ne $args -and $args -is [System.Collections.IDictionary] -and $args.Keys.Count -gt 0) {
        $argPairs = @()
        foreach ($argKey in $args.Keys) {
            $argPairs += ("{0}={1}" -f $argKey, $args[$argKey])
        }
        $lines += "Args: $($argPairs -join ', ')"
    }
    if ($null -ne $definition -and $definition -is [System.Collections.IDictionary]) {
        if ($definition.Contains('FullPath') -and -not [string]::IsNullOrWhiteSpace($definition['FullPath'])) {
            $lines += "DefinitionPath: $($definition['FullPath'])"
        }
        if ($definition.Contains('Parameters') -and $definition['Parameters']) {
            $paramNames = @()
            foreach ($param in @($definition['Parameters'])) {
                if ($param -is [System.Collections.IDictionary] -and $param.Contains('Name')) {
                    $paramNames += $param['Name']
                }
            }
            if ($paramNames.Count -gt 0) {
                $lines += "Parameters: $($paramNames -join ', ')"
            }
        }
    }
    if ($null -ne $container -and $container -is [System.Collections.IDictionary]) {
        if ($container.Contains('image') -and -not [string]::IsNullOrWhiteSpace($container['image'])) {
            $lines += "ContainerImage: $($container['image'])"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($provenance)) {
        $lines += "Provenance: $provenance"
    }

    return ($lines -join [Environment]::NewLine)
}
