function Get-JaxJsonProperty {
    <#
    .SYNOPSIS
        Read a property from a deserialized JSON object without failing under
        Set-StrictMode when the property is absent.
    #>
    [CmdletBinding()]
    param (
        $Object,
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $Object) {
        return $null
    }
    if ($Object.PSObject.Properties.Match($Name).Count -eq 0) {
        return $null
    }

    return $Object.$Name
}
