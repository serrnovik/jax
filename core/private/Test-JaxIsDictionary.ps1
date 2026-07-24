function Test-JaxIsDictionary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object] $Value
    )

    # Performance critical: skip full params capture for this tiny helper unless Debug is on
    if ($PSBoundParameters['Debug']) {
        Write-Debug "FUNC: $($MyInvocation.MyCommand.Name)"
    }
    # $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters # Skip overhead
    return ($Value -is [System.Collections.IDictionary])
}
