function Expand-JaxPlaceholders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [hashtable] $Override,
        [string[]] $SourcePaths,
        [switch] $ExpandOverrideAndMainHt,
        [switch] $TreatMissingValueAsFalse,
        [Alias('IgnoreMissingVariables')]
        [switch] $IgnoreMissingPlaceholders,
        [switch] $WarningsAsVerbose,
        [switch] $DontThrow
    )

    Initialize-JaxPlaceholdersProvider

    $params = @{
        ht                     = $Config
        override               = $Override
        sourcePaths            = $SourcePaths
        expandOverrideAndMainHt = $ExpandOverrideAndMainHt
        treatMissingValueAsFalse = $TreatMissingValueAsFalse
        ignoreMissingPlaceholders = $IgnoreMissingPlaceholders
        warningsAsVerbose      = $WarningsAsVerbose
        dontThrow              = $DontThrow
    }

    return Expand-JaxMPPlaceholders @params
}
