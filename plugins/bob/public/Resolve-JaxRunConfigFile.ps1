function Resolve-JaxRunConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config,
        [System.Collections.IDictionary] $PluginConfig
    )

    if (-not (Test-Path -Path $EnvDir -PathType Container)) {
        return $null
    }

    $pluginDefaults = Get-JaxBobPluginDefaults
    $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $PluginConfig

    $fileNames = @()
    if ($pluginConfig.Keys -contains 'fileNames') {
        $fileNames = @($pluginConfig['fileNames'])
    }
    if ($fileNames.Count -eq 0) {
        $baseNames = @($pluginConfig['fileBaseNames'])
        if ($baseNames.Count -eq 0) {
            $baseNames = @($pluginDefaults['fileBaseNames'])
        }
        $extensions = @($pluginConfig['fileExtensions'])
        if ($extensions.Count -eq 0) {
            $extensions = @($pluginDefaults['fileExtensions'])
        }
        foreach ($baseName in $baseNames) {
            foreach ($ext in $extensions) {
                $trimmedExt = $ext.TrimStart('.')
                $fileNames += "$baseName.$trimmedExt"
            }
        }
    }

    foreach ($fileName in $fileNames) {
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            continue
        }
        $candidate = Join-Path $EnvDir $fileName
        if (Test-Path -Path $candidate -PathType Leaf) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}
