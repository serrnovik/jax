function Initialize-JaxTypeExtensions {
    [CmdletBinding()]
    param ()

    # OrderedDictionary (from ConvertFrom-Yaml -Ordered) does not implement .ContainsKey().
    # Large parts of the codebase expect IDictionary-like objects to have ContainsKey.
    # Add a lightweight scriptmethod so OrderedDictionary behaves like a normal map.
    $typeName = 'System.Collections.Specialized.OrderedDictionary'

    try {
        $td = Get-TypeData -TypeName $typeName -ErrorAction SilentlyContinue
        $hasContainsKey = $false
        if ($null -ne $td -and $null -ne $td.Members) {
            $hasContainsKey = $td.Members.Keys -contains 'ContainsKey'
        }
        if (-not $hasContainsKey) {
            Update-TypeData -TypeName $typeName -MemberType ScriptMethod -MemberName 'ContainsKey' -Value {
                param($key)
                return $this.Contains($key)
            } -Force
        }
    } catch {
        # Best effort only; Jax should still run even if type data updates are blocked.
    }
}
