function Expand-PlaceholdersInStrings {
    [cmdletbinding()]
    param (
        [string[]] $lines,
        [Alias('variables')]
        [hashtable] $context
    )
    $expandedLines = @()
    foreach ($line in $lines) {
        $expandedLines += @(Expand-PlaceholdersRec -node $line -ht $context)
    }
    return $expandedLines
}
