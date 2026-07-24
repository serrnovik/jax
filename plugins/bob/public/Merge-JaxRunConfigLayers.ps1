function Merge-JaxRunConfigLayers {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Defaults,
        [System.Collections.IDictionary] $RunConfig,
        [System.Collections.IDictionary] $EnvConfig,
        [System.Collections.IDictionary] $RepoConfig,
        [System.Collections.IDictionary] $UserConfig,
        [System.Collections.IDictionary] $CliOverrides
    )

    $merged = @{}
    if ($null -ne $Defaults) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $Defaults
    }
    if ($null -ne $RunConfig) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $RunConfig
    }
    if ($null -ne $EnvConfig) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $EnvConfig
    }
    if ($null -ne $RepoConfig) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $RepoConfig
    }
    if ($null -ne $UserConfig) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $UserConfig
    }
    if ($null -ne $CliOverrides) {
        $merged = Merge-JaxHashtable -Base $merged -Overlay $CliOverrides
    }

    return $merged
}
