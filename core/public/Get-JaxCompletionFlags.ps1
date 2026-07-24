function Get-JaxCompletionFlags {
    [CmdletBinding()]
    param ()

    $defs = Get-JaxCliParameters
    $flags = @()
    foreach ($def in $defs) {
        $flags += "-$($def.Name)"
        foreach ($alias in $def.Aliases) {
            $flags += "-$alias"
        }
    }

    return @($flags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}
