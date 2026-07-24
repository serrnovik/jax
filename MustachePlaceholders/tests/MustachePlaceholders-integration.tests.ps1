BeforeAll {
    Import-Module "$PSScriptRoot/../MustachePlaceholders.psm1" -DisableNameChecking -Force -Global
    Import-Module "$PSScriptRoot/TestHelpers.psm1" -DisableNameChecking -Force -Global
}

Describe "Expand-Placeholders with nested fixture config" {
    BeforeAll {
        # Helper function to convert JSON to OrderedHashtable
        function Convert-PSObjectToHashtable {
            param (
                [Parameter(ValueFromPipeline)]
                $InputObject
            )

            process {
                if ($null -eq $InputObject) { return $null }
                if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                    $collection = @(
                        foreach ($object in $InputObject) {
                            Convert-PSObjectToHashtable $object
                        }
                    )
                    return $collection
                }
                if ($InputObject -is [PSCustomObject]) {
                    $hash = [ordered]@{}
                    foreach ($property in $InputObject.PSObject.Properties) {
                        $hash[$property.Name] = Convert-PSObjectToHashtable $property.Value
                    }
                    return $hash
                }
                return $InputObject
            }
        }

        # Load test data
        $overrideJson = Get-Content "$PSScriptRoot/sample_data/overrideHashtable.json" | ConvertFrom-Json
        $script:overrideHashtable = Convert-PSObjectToHashtable $overrideJson

        $yamlJson = Get-Content "$PSScriptRoot/sample_data/yamlHashtable.json" | ConvertFrom-Json
        $script:yamlHashtable = Convert-PSObjectToHashtable $yamlJson
    }

    It "Should expand complex nested variables without infinite recursion" {
        { Invoke-WithTimeout { param($yaml, $override) Expand-Placeholders -ht $yaml -override $override } -ArgumentList @($yamlHashtable, $overrideHashtable) -TimeoutSeconds 30 } |
            Should -Not -Throw
    }

    It "Should correctly resolve framework values" {
        $expanded = Expand-Placeholders -ht $yamlHashtable -override $overrideHashtable -expandOverrideAndMainHt

        # Check specific paths that should be resolved
        $expanded.flows.suite.features.build.common.framework | Should -Be "net8.0"

        # These values come from flows.suite.features.publish section
        $expanded.flows.suite.features.publish.beta.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.publish.alpha.framework | Should -Be "net8.0"

        # These values are references to the publish section
        $expanded.flows.suite.features.pack.beta.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.pack.alpha.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.pack.gamma.framework | Should -Be "net8.0"

        # Run section frameworks reference publish section
        $expanded.flows.suite.features.run.beta.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.run.alpha.framework | Should -Be "net8.0"
    }

    It "Should resolve version number with build counter" {
        $expanded = Expand-Placeholders -ht $yamlHashtable -override $overrideHashtable -expandOverrideAndMainHt

        # The version number should be composed of base version and build counter
        $expectedVersion = "1.2.42"
        $expanded.flows.suite.version.number | Should -Be $expectedVersion
    }


    It "Should handle all variable substitutions in features section" {
        $expanded = Expand-Placeholders -ht $yamlHashtable -override $overrideHashtable

        # Check pack frameworks
        $expanded.flows.suite.features.pack.beta.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.pack.alpha.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.pack.gamma.framework | Should -Be "net8.0"

        # Check build frameworks
        $expanded.flows.suite.features.build.targetFrameworks.Library | Should -Be "net8.0"
        $expanded.flows.suite.features.build.targetFrameworks.Test | Should -Be "net8.0"
        $expanded.flows.suite.features.build.targetFrameworks.AspNet | Should -Be "net8.0"
        $expanded.flows.suite.features.build.targetFrameworks.Executable | Should -Be "net8.0"

        # Check run frameworks
        $expanded.flows.suite.features.run.beta.framework | Should -Be "net8.0"
        $expanded.flows.suite.features.run.alpha.framework | Should -Be "net8.0"
    }

    It "Should correctly resolve environment paths" {
        $expanded = Expand-Placeholders -ht $yamlHashtable -override $overrideHashtable

        # Check environment resolution
        $expanded.flows.suite.env | Should -Be "demo/dev"
        $expanded.flows.suite.client | Should -Be "demo"
        $expanded.flows.suite.env_type | Should -Be "dev"
    }

    It "Should resolve variables from main hashtable by default" {
        $ht = @{
            "root" = @{
                "value" = "{{ root.other.value }}"
                "other" = @{
                    "value" = "test"
                }
            }
        }

        $expanded = Expand-Placeholders -ht $ht -expandOverrideAndMainHt
        $expanded.root.value | Should -Be "test"
    }

}
