Register-PlaceholderFunction "yamlFile" {
    param($thisValue, [string]$filePath, [string]$dottedKey = "")

    $repoRoot = Get-JaxRepoRoot
    # Resolve-JaxRepoRootedPath is private in Jax.Core.psm1 and not accessible from a registered
    # scriptblock invoked inside the placeholders module — inline the ^/ logic here directly.
    $resolvedPath = if ($filePath.StartsWith('^/')) {
        Join-Path $repoRoot $filePath.Substring(2)
    } elseif ([IO.Path]::IsPathRooted($filePath)) {
        $filePath
    } else {
        Join-Path $repoRoot $filePath
    }
    $yaml = Read-JaxYaml -Path $resolvedPath

    if ([string]::IsNullOrWhiteSpace($dottedKey)) {
        return $yaml
    }

    return Get-PathFromHashtable -ht $yaml -path $dottedKey
}

Register-PlaceholderFunction "asPnpmFilters" {
    param($thisValue)

    if ($null -eq $thisValue) { return "" }

    $items = @()
    if ($thisValue -is [System.Collections.IEnumerable] -and $thisValue -isnot [string]) {
        $items = @($thisValue)
    } else {
        $items = @($thisValue.ToString())
    }

    $filters = $items | ForEach-Object { "--filter `"$_`"" }
    return ($filters -join " ")
}
