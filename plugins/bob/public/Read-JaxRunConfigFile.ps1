function Read-JaxRunConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string] $RepoRoot,
        [scriptblock] $YamlReader,
        [ref] $UsedPaths
    )

    $commonPSBoundParameters = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    $reader = $YamlReader
    if ($null -eq $reader) {
        $reader = {
            param($path)
            Read-JaxYaml -Path $path
        }
    }

    Write-Debug ("Read-JaxRunConfigFile: '{0}'" -f $Path)
    $config = & $reader $Path
    if ($null -eq $config) {
        return @{}
    }
    if ($config -isnot [System.Collections.IDictionary]) {
        throw "Run-config '$Path' did not return a map/object."
    }

    if ($null -ne $UsedPaths) {
        return Resolve-JaxRunConfigImports -Config $config -ConfigPath $Path -RepoRoot $RepoRoot -YamlReader $reader -UsedPaths $UsedPaths @commonPSBoundParameters
    }

    return Resolve-JaxRunConfigImports -Config $config -ConfigPath $Path -RepoRoot $RepoRoot -YamlReader $reader @commonPSBoundParameters
}
