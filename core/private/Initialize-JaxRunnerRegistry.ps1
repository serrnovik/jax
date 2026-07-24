function Initialize-JaxRunnerRegistry {
    [CmdletBinding()]
    param ()

    if (-not (Get-Variable -Name JaxRunnerRegistry -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxRunnerRegistry = @{}
    }

    if ($script:JaxRunnerRegistry.Keys.Count -eq 0) {
        Register-JaxRunner -Name 'psake' -Handler {
            param($entity, $context, $common)
            $commonParams = if ($common -is [System.Collections.IDictionary]) { $common } else { @{} }
            Invoke-JaxPsakeRunner -Entity $entity -Context $context -CommonParameters $commonParams @commonParams
        }
        Register-JaxRunner -Name 'pwshscript' -Handler {
            param($entity, $context, $common)
            $commonParams = if ($common -is [System.Collections.IDictionary]) { $common } else { @{} }
            Invoke-JaxScriptRunner -Entity $entity -Context $context -CommonParameters $commonParams @commonParams
        }
        Register-JaxRunner -Name 'script' -Handler {
            param($entity, $context, $common)
            $commonParams = if ($common -is [System.Collections.IDictionary]) { $common } else { @{} }
            Invoke-JaxScriptRunner -Entity $entity -Context $context -CommonParameters $commonParams @commonParams
        }
        Register-JaxRunner -Name 'container' -Handler {
            param($entity, $context, $common)
            $commonParams = if ($common -is [System.Collections.IDictionary]) { $common } else { @{} }
            Invoke-JaxContainerRunner -Entity $entity -Context $context -CommonParameters $commonParams @commonParams
        }
        Register-JaxRunner -Name 'scenario' -Handler {
            param($entity, $context, $common)
            $commonParams = if ($common -is [System.Collections.IDictionary]) { $common } else { @{} }
            Invoke-JaxScenarioRunner -Entity $entity -Context $context -CommonParameters $commonParams @commonParams
        }
    }
}
