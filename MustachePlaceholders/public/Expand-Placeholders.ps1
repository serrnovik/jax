function Expand-Placeholders {
    [cmdletbinding()]
    param (
        [Alias('ht')]
        $context, # [hashtable] or [ordered] hashtable, check below
        [Alias('override')]
        [System.Collections.IDictionary] $overrides, # expand placeholders from here but don't save them to config
        [string[]] $sourcePaths,
        [switch] $expandOverrideAndMainHt,
        [switch] $treatMissingValueAsFalse, # set false if substitution not found,
        [string] $path,
        [Alias('ignoreMissingVariables')]
        [switch] $ignoreMissingPlaceholders,
        [switch] $warningsAsVerbose,
        [switch] $dontThrow
    )
    $commonPSBoundParameters = Get-CommonParameters -BoundParameters $PSBoundParameters
    if ($null -ne $context) {
        Ensure-OrderedOrHashtable -inputObject $context -message "-context in Expand-Placeholders" @commonPSBoundParameters
    }

    if ($ignoreMissingPlaceholders) {
        $message = "Warning! -ignoreMissingPlaceholders passed, all missing substitutions will be replaced with empty string"
        if ($warningsAsVerbose) { Write-Verbose $message } else { Write-Host $message }
    }

    if ($expandOverrideAndMainHt -and $null -ne $overrides) {
        $overrides = Expand-PlaceholdersRec $overrides $context $overrides -sourcePaths $sourcePaths -treatMissingValueAsFalse:$treatMissingValueAsFalse -path $path -ignoreMissingPlaceholders:$ignoreMissingPlaceholders -dontThrow:$dontThrow @commonPSBoundParameters
    }

    $context = Expand-PlaceholdersRec $context $context $overrides -sourcePaths $sourcePaths -treatMissingValueAsFalse:$treatMissingValueAsFalse -path $path -ignoreMissingPlaceholders:$ignoreMissingPlaceholders -dontThrow:$dontThrow @commonPSBoundParameters

    return $context
}
