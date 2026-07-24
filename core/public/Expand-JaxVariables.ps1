function Expand-JaxVariables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [hashtable] $Override,
        [string[]] $SourcePaths,
        [switch] $ExpandOverrideAndMainHt,
        [switch] $TreatMissingValueAsFalse,
        [switch] $IgnoreMissingVariables,
        [switch] $WarningsAsVerbose,
        [switch] $DontThrow
    )

    return Expand-JaxPlaceholders `
        -Config $Config `
        -Override $Override `
        -SourcePaths $SourcePaths `
        -ExpandOverrideAndMainHt:$ExpandOverrideAndMainHt `
        -TreatMissingValueAsFalse:$TreatMissingValueAsFalse `
        -IgnoreMissingPlaceholders:$IgnoreMissingVariables `
        -WarningsAsVerbose:$WarningsAsVerbose `
        -DontThrow:$DontThrow
}
