function Read-JaxYaml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Jax YAML file not found: '$Path'"
    }

    # Explicit UTF-8: default encoding is host-dependent (e.g. Windows-1252) and would corrupt emoji.
    $rawContent = Get-Content -Path $Path -Raw -Encoding utf8
    Initialize-JaxYamlProvider
    try {
        return ($rawContent | ConvertFrom-Yaml -Ordered)
    } catch {
        throw "Failed to parse YAML file '$Path': $($_.Exception.Message)"
    }
}
