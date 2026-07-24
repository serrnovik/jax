function Resolve-JaxDefaultContainerImage {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $RunConfig
    )

    if ($null -eq $RunConfig) {
        return $null
    }

    if (Test-JaxDictionaryHasKey -Dictionary $RunConfig -Key 'container') {
        $container = $RunConfig['container']
        if ($container -is [System.Collections.IDictionary] -and (Test-JaxDictionaryHasKey -Dictionary $container -Key 'image')) {
            return $container['image']
        }
    }

    if (Test-JaxDictionaryHasKey -Dictionary $RunConfig -Key 'module') {
        $module = $RunConfig['module']
        if ($module -is [System.Collections.IDictionary] -and (Test-JaxDictionaryHasKey -Dictionary $module -Key 'docker')) {
            $docker = $module['docker']
            if ($docker -is [System.Collections.IDictionary] -and (Test-JaxDictionaryHasKey -Dictionary $docker -Key 'image')) {
                return $docker['image']
            }
        }
    }

    if (Test-JaxDictionaryHasKey -Dictionary $RunConfig -Key 'docker') {
        $dockerRoot = $RunConfig['docker']
        if ($dockerRoot -is [System.Collections.IDictionary] -and (Test-JaxDictionaryHasKey -Dictionary $dockerRoot -Key 'image')) {
            return $dockerRoot['image']
        }
    }

    return $null
}
