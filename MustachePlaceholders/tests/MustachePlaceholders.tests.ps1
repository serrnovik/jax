BeforeAll {
    Import-Module "$PSScriptRoot/../MustachePlaceholders.psm1" -DisableNameChecking -Force -Global 3>$null
    Import-Module "$PSScriptRoot/TestHelpers.psm1" -DisableNameChecking -Force -Global
}

Describe "Get-PathFromHashtable" {
    Context "No override" {
        It "Empty hash table throws" {
            { Get-PathFromHashtable -path "a.b" } | Should -Throw "Hashtable is null*"
        }

        It "Returns hashtable itself on null variable" {
            $result = (Get-PathFromHashtable @{ a = 1 } $null)
            $result | Should -BeOfType ([System.Collections.IDictionary])
            $result.a | Should -Be 1
        }

        It "Returns hashtable itself on empty path" {
            $result = (Get-PathFromHashtable @{ a = 1 } "")
            $result | Should -BeOfType ([System.Collections.IDictionary])
            $result.a | Should -Be 1
        }

        It "Returns first-level path" {
            $ht = @{ a = 33 }

            $result = (Get-PathFromHashtable $ht "a")
            $result | Should -Be 33
        }

        It "Returns second-level path" {
            $ht = @{ a = @{ b = 33 } }

            $result = (Get-PathFromHashtable $ht "a.b")
            $result | Should -Be 33
        }

        It "Returns second-level array" {
            $ht = @{ a = @{ b = @(1, 2, 3) } }

            $result = (Get-PathFromHashtable $ht "a.b")
            $result | Should -Be @(1, 2, 3)
        }

        It "Throws on non-existing first-level path" {
            $ht = @{ a = @{ b = @(1, 2, 3) } }
            $params = @{}

            { Get-PathFromHashtable $ht "nope" @params } | Should -Throw "*is not found in the hashtable*"
        }

        It "Throws on non-existing second-level path" {
            $ht = @{ a = @{ b = @(1, 2, 3) } }
            $params = @{}

            { Get-PathFromHashtable $ht "a.nope" @params } | Should -Throw "*is not found in the hashtable*"
        }

        # probably obsolete
        # It "Throws on trying to access array value" {
        #     $ht = @{ a = @{ b = @("c", "d") } }

        #     { Get-PathFromHashtable $ht "a.b.c" @params } | Should -Throw "*is not found in the hashtable*"
        # }

        It "array in simle array return array" {
            $ht = @{ flows = @{ modules = @{ workflow = "yes"; networknode = @("task1", "task2" ) } } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "flows.modules.networknode"
            $result | Should -BeOfType [System.Collections.IEnumerable]
            $recieved = $result -join ","
            $expected = @("task1", "task2" ) -join ","
            $recieved | Should -Be $expected
            $result.Count | Should -Be 2
        }
        It "array in complex array return array" {
            $ht = @{ flows = @{ modules = @( "workflow", @{ networknode = @("task1", "task2" ) }) } }

            $result = Get-PathFromHashtable $ht "flows.modules.networknode"
            $result | Should -BeOfType [System.Collections.IEnumerable]
            $recieved = $result -join ","
            $expected = @("task1", "task2" ) -join ","
            $recieved | Should -Be $expected
            $result.Count | Should -Be 2
        }

        It "Returns null conditional access to non-present element with default  (notPresent?.key -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?.key" -defaultValue "default"
            $result | Should -Be $null
        }

        It "Returns null conditional access to non-present element and (present?.key -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present?.key"
            $result | Should -Be "value"
        }

        It "Conditional access to present element returns correct value (notPresent?.key -> 'value')" {
            $ht = @{ present = @{ } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?.never"
            $result | Should -Be $null
        }

        It "Returns null conditional access to non-present element in the end and (present.notPresent? -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present.notPresent?"
            $result | Should -Be $null
        }

        It "Returns null conditional access to non-present element in the end and given default (present.notPresent? -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present.notPresent?" -defaultValue "default"
            $result | Should -Be $null
        }

        It "Returns null conditional access to single non-present element in the end and (notPresent? -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?"
            $result | Should -Be $null
        }

        It "Returns null conditional access to single non-present element in the end and given default (notPresent? -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?" -defaultValue "default"
            $result | Should -Be $null
        }

        It "Returns null on conditional access to single non-present element in the end and given default (notPresent?.notPresent? -> null)" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?.notPresentAgain?" -defaultValue "default"
            $result | Should -Be $null
        }

        It "Returns null conditional access" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?.notPresentAgain" -defaultValue "default"
            $result | Should -Be $null
        }

        It "Returns null on double conditional access" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "notPresent?.notPresentAgain?.key" -defaultValue "default"
            $result | Should -Be $null

        }

        It "Returns value on conditional access when value present" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present?.key" -defaultValue "default"
            $result | Should -Be "value"

        }

        It "Returns value on conditional access when value present" {
            $ht = @{ present = @{ nextLevel = @{ key = "value" } } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present.nextLevel?.key" -defaultValue "default"
            $result | Should -Be "value"

        }

        It "Returns null normal access when value not present but -dontThrow is passed" {
            $ht = @{ present = @{ nextLevel = @{ key = "value" } } } # in our yaml we have more complex case

            $result = Get-PathFromHashtable $ht "present.notPresent" -dontThrow -defaultValue "default"
            $result | Should -Be "default"

        }

        It "Throws on key access after double conditional access after null" {
            $ht = @{ present = @{ key = "value" } } # in our yaml we have more complex case

            $action = { Get-PathFromHashtable $ht "notPresent?.notPresentAgain?.key.anotherKey" -defaultValue "default" }
            $action | Should -Throw

        }
    }

    Context "No override: don't throw + default value" {
        BeforeAll {
            $defaultValue = "__DEFAULT__"
            $params = @{
                dontThrow    = $true
                defaultValue = $defaultValue
            }
        }

        It "Empty hash table throws" {
            { Get-PathFromHashtable -path "a.b" @params } | Should -Throw "Hashtable is null*"
        }

        It "Returns hashtable itself on null variable" {
            $result = (Get-PathFromHashtable @{ a = 1 } $null @params)
            $result | Should -BeOfType ([System.Collections.IDictionary])
            $result.a | Should -Be 1
        }

        It "Returns hashtable itself on empty path" {
            $result = (Get-PathFromHashtable @{ a = 1 } "" @params)
            $result | Should -BeOfType ([System.Collections.IDictionary])
            $result.a | Should -Be 1
        }

        It "Returns default value on non-existing first-level path" {
            $ht = @{ a = @{ b = @(1, 2, 3) } }

            $result = (Get-PathFromHashtable $ht "nope" @params)
            $result | Should -Be $defaultValue
        }

        It "Returns default value on non-existing second-level path" {
            $ht = @{ a = @{ b = @(1, 2, 3) } }

            $result = (Get-PathFromHashtable $ht "a.nope" @params)
            $result | Should -Be $defaultValue
        }

        # probably obsolete
        # It "Returns default value on trying to access array value" {
        #     $ht = @{ a = @{ b = @("c", "d") } }

        #     $result = (Get-PathFromHashtable $ht "a.b.c" @params)
        #     $result | Should -Be $defaultValue
        # }
    }

    Context "Value is in override and in main table" {
        It "Returns overridden value (simple path) when present in the main hashtable" {
            $ht = @{ a = 33 }
            $override = @{ a = 44 }

            $result = (Get-PathFromHashtable $ht "a" -override $override)
            $result | Should -Be 44
        }

        It "Returns overridden value (complex path) when present in the main hashtable" {
            $ht = @{ a = @{b = 33 } }
            $override = @{ "a.b" = 44 }

            $result = (Get-PathFromHashtable $ht "a.b" -override $override)
            $result | Should -Be 44
        }

        It "Returns overridden value (tree path) when present in the main hashtable" {
            $ht = @{ a = @{ b = 33 } }
            $override = @{ a = @{ b = 44 } }

            $result = (Get-PathFromHashtable $ht "a.b" -override $override)
            $result | Should -Be 44
        }
    }

    Context "Value is in override but not in main table" {
        It "Returns overridden value (simple path) when present in the main hashtable" {
            $ht = @{  }
            $override = @{ a = 44 }

            $result = (Get-PathFromHashtable $ht "a" -override $override)
            $result | Should -Be 44
        }

        It "Returns overridden value (complex path) when present in the main hashtable" {
            $ht = @{  }
            $override = @{ "a.b" = 44 }

            $result = (Get-PathFromHashtable $ht "a.b" -override $override)
            $result | Should -Be 44
        }

        It "Returns overridden value (tree path) when present in the main hashtable" {
            $ht = @{  }
            $override = @{ a = @{ b = 44 } }

            $result = (Get-PathFromHashtable $ht "a.b" -override $override)
            $result | Should -Be 44
        }
    }

    Context "Value exists and is null: no override" {
        It "Returns null from main table (simple path)" {
            $ht = @{ value = $null }
            $override = @{}

            $result = Get-PathFromHashtable $ht "value" $override
            $result | Should -Be $null
        }

        It "Returns null from main table (complex path)" {
            $ht = @{ get = @{ value = $null } }
            $override = @{}

            $result = Get-PathFromHashtable $ht "get.value" $override
            $result | Should -Be $null
        }

    }

    Context "Value exists and is null: exists only in override" {
        It "Returns null from main table (simple path)" {
            $ht = @{ }
            $override = @{ value = $null }

            $result = Get-PathFromHashtable $ht "value" $override
            $result | Should -Be $null
        }

        It "Returns null from main table (complex path)" {
            $ht = @{ }
            $override = @{get = @{ value = $null } }

            $result = Get-PathFromHashtable $ht "get.value" $override
            $result | Should -Be $null
        }
    }

    Context "Value exists and is null: exists in both tables but nullly in override" {
        It "Returns null from main table (simple path)" {
            $ht = @{ value = 13 }
            $override = @{ value = $null }

            $result = Get-PathFromHashtable $ht "value" $override
            $result | Should -Be $null
        }

        It "Returns null from main table (complex path)" {
            $ht = @{ get = @{ value = 13 } }
            $override = @{ get = @{ value = $null } }

            $result = Get-PathFromHashtable $ht "get.value" $override
            $result | Should -Be $null
        }
    }

    Context "Value is not in override" {
        It "Returns main hashtable value when path is not present in override (simple path)" {
            $ht = @{ a = 33 }
            $override = @{ x = 44 }

            $result = Get-PathFromHashtable $ht "a" -override $override
            $result | Should -Be 33
        }

        It "Returns main hashtable value when path is not present in override (complex path)" {
            $ht = @{ a = @{b = 33 } }
            $override = @{ "x.x" = 44 }

            $result = Get-PathFromHashtable $ht "a.b" -override $override
            $result | Should -Be 33
        }

        It "Returns main hashtable value when path is not present in override (tree path)" {
            $ht = @{ a = @{ b = 33 } }
            $override = @{ x = @{ y = 44 } }

            $result = Get-PathFromHashtable $ht "a.b" -override $override
            $result | Should -Be 33
        }
    }
}

Describe "Expand-FlatDottedHashtable" {
    It "more specific key should override" {
        $data = @{
            "one"     = "111"
            "one.two" = "222"
        }
        $result = Expand-FlatDottedHashtable $data

        $result.one.two | Should -Be "222"
    }
    It "more specific key should override even if specific is the last" {
        $data = @{
            "one.two" = "222"
            "one"     = "111"
        }
        $result = Expand-FlatDottedHashtable $data

        $result.one.two | Should -Be "222"
    }

    It "more specific key should override even if specific is the last - reversed order" {
        $data = @{
            "one"           = "111"
            "one.two.three" = "222"
        }
        $result = Expand-FlatDottedHashtable $data

        $result.one.two.three | Should -Be "222"
    }
    It "base case" {
        $data = @{
            "one.two.three" = "111"
            "one.two.four"  = "222"
            "five.six"      = "333"
        }
        $result = Expand-FlatDottedHashtable $data

        $result.one.two.three | Should -Be "111"
        $result.one.two.four | Should -Be "222"
        $result.five.six | Should -Be "333"
    }
    It "root variable test" {
        $data = @{
            "one"          = "111"
            "one.two.four" = "222"
            "five.six"     = "333"
        }
        $result = Expand-FlatDottedHashtable $data

        $result.one | Should -BeOfType ([System.Collections.IDictionary])
    }
    It "root empty should return empty" {
        $data = @{        }
        $result = Expand-FlatDottedHashtable $data
        $result.Count | Should -Be 0
    }
    It "root variable test" {
        $data = @{
            "a..b" = "111"
        }
        { Expand-FlatDottedHashtable $data } | Should -Throw
    }
}

Describe "Pipeline functions (partial Jinja)" {
    It "eq + ifElse ternary works" {
        $ht = @{ module = @{ run_type = 'prod' } ; out = "{{ module.run_type | eq('prod') | ifElse('prod','sandbox') }}" }
        $expanded = Expand-Placeholders $ht
        $expanded.out | Should -BeExactly 'prod'
    }

    It "default() returns fallback only for null/empty" {
        $ht = @{ a = $null; b = ''; c = 'x'
            o1 = "{{ a | default('foo') }}"
            o2 = "{{ b | default('foo') }}"
            o3 = "{{ c | default('foo') }}"
        }
        $e = Expand-Placeholders $ht
        $e.o1 | Should -BeExactly 'foo'
        $e.o2 | Should -BeExactly 'foo'
        $e.o3 | Should -BeExactly 'x'
    }

    It "coalesce/isSet/isEmpty work" {
        $ht = @{ a = $null; b = '  '; c = 'v'
            o1 = "{{ a | coalesce('x') }}"
            o2 = "{{ b | coalesce('x') }}"
            s1 = "{{ a | isSet() }}"
            s2 = "{{ c | isEmpty() }}"
        }
        $e = Expand-Placeholders $ht
        $e.o1 | Should -BeExactly 'x'
        $e.o2 | Should -BeExactly 'x'
        $e.s1 | Should -Be $false
        $e.s2 | Should -Be $false
    }

    It "string ops and contains work" {
        $ht = @{ s = ' HelloWorld '
            t      = "{{ s | trim() }}"
            sw     = "{{ s | trim() | startsWith('Hello') }}"
            ew     = "{{ s | trim() | endsWith('World') }}"
            ct     = "{{ s | contains('World') }}"
        }
        $e = Expand-Placeholders $ht
        $e.t | Should -BeExactly 'HelloWorld'
        $e.sw | Should -Be $true
        $e.ew | Should -Be $true
        $e.ct | Should -Be $true
    }

    It "arrays/maps helpers work" {
        $ht = @{ arr = @(1, 2, 3); map = @{ k = 'v' }
            l = "{{ arr | length() }}"
            ks = "{{ map | keys() | length() }}"
            has = "{{ arr | contains(2) }}"
        }
        $e = Expand-Placeholders $ht
        $e.l | Should -Be 3
        $e.ks | Should -Be 1
        $e.has | Should -Be $true
    }

    It "first returns first sequence element or null" {
        $ht = @{
            arr    = @('192.0.2.10', '198.51.100.20')
            empty  = @()
            str    = 'single'
            f      = "{{ arr | first() }}"
            s      = "{{ str | first() }}"
            fe     = "{{ empty | first() }}"
        }
        $e = Expand-Placeholders $ht
        $e.f | Should -BeExactly '192.0.2.10'
        $e.s | Should -BeExactly 'single'
        $e.fe | Should -Be $null
    }

    It "mergeLists combines arrays from dict keys" {
        $ht = @{
            module = @{
                build = @{
                    commonDependencies = @('a', 'b', 'a', 'c')
                    commonUIProjects = @('b', 'd')
                    allDependencies = "{{ module.build | mergeLists('commonDependencies','commonUIProjects') }}"
                }
            }
        }
        $expanded = Expand-Placeholders $ht
        $result = $expanded.module.build.allDependencies

        $result | Should -HaveCount 4
        $result[0] | Should -Be 'a'
        $result[1] | Should -Be 'b'
        $result[2] | Should -Be 'c'
        $result[3] | Should -Be 'd'
    }
}

Describe "Test-PlaceholderString" {
    It "{{ a }} detects well" {
        (Test-PlaceholderString "{{ a }}") | Should -Be $true

    }
    It "{{a }} detects well" {
        (Test-PlaceholderString "{{a }}") | Should -Be $true

    }
    It "{{ a}} detects well" {
        (Test-PlaceholderString "{{ a}}") | Should -Be $true

    }
    It "{{a}} detects well" {
        (Test-PlaceholderString "{{a}}") | Should -Be $true
    }

    It "{{ }} detects nothing" {
        (Test-PlaceholderString "{{ }}") | Should -Be $false
    }

    It "Detects multiple '{{ a }} and {{ b }}'" {
        (Test-PlaceholderString "{{ a }} and {{ b }}") | Should -Be $true
    }
}

Describe "Convert-PlaceholderMatch" {
    It "Replaces with no arguments" {
        $sut = Convert-PlaceholderMatch "{{ a }}"

        $sut | Should -Be "a"
    }

    It "Replaces with before only" {
        $sut = Convert-PlaceholderMatch "{{ a }}" -Before '%'

        $sut | Should -Be "%a"
    }

    It "Replaces with after only" {
        $sut = Convert-PlaceholderMatch "{{ a }}" -After '%'

        $sut | Should -Be "a%"
    }

    It "Replaces with before and after" {
        $sut = Convert-PlaceholderMatch "{{ x }}" -Before "b_"-After '_a'

        $sut | Should -Be "b_x_a"
    }
}

Describe "Test-PlaceholderInTree" {
    It "Gets nested hash parameter" {
        $yaml = @{"bob" = @{"module" = @{"psake" = @{"config" = "/bobroot/.build/ps/tests/bobpsakesample.ps1"; "framework" = "4.0" }; "docker" = @{"mount" = @{"path" = "C:\\sample-project" }; "image" = "registry.example.com/demo/dotnet:3.1" } } } }
        $value = Test-PlaceholderInTree $yaml "bob.module.psake.config"

        $value | Should -Be "/bobroot/.build/ps/tests/bobpsakesample.ps1"
    }
    It "Gets hash in hash value" {
        $yaml = @{
            container = @{
                key = "value"
            }
        }
        $value = Test-PlaceholderInTree $yaml "container.key"

        $value | Should -Be "value"
    }

    It "Gets hash 'yes' value from hash" {
        $yaml = @{
            container = @{
                key = "value"
            }
        }
        $value = Test-PlaceholderInTree $yaml "container"

        $value | Should -Be "yes"
    }

    It "Gets hash value from hash key" {
        $yaml = @{
            container = @{
                key = "value"
            }
        }
        $value = Test-PlaceholderInTree $yaml "container.key"

        $value | Should -Be "value"
    }

    It "Gets hash value from hash key value" {
        $yaml = @{
            container = @{
                key = "value"
            }
        }
        $value = Test-PlaceholderInTree $yaml "container.key.value"

        $value | Should -Be "yes"
    }

    It "Gets hash 'yes' value from array" {
        $yaml = @{
            arr = @(1, 2, 3)
        }
        $value = Test-PlaceholderInTree $yaml "arr"

        $value | Should -Be "yes"
    }

    It "Gets hash 'yes' value from array item" {
        $yaml = @{
            arr = @(1, 2, "item")
        }
        $value = Test-PlaceholderInTree $yaml "arr.item"

        $value | Should -Be "yes"
    }

    It "Returns null from non-existent nested hash" {
        $result = Test-PlaceholderInTree @{"a" = @{"b" = "d" } } "a.x"

        $result | Should -Be $null
    }
}

Describe "Test-PlaceholderInContext" {
    It "Gets value from subtree without override" {
        $ht = @{
            key = "{{ tc.key }}"
            tc  = @{ key = "value" }
        }

        $value = Test-PlaceholderInContext @{} $ht "tc.key"
        $value | Should -Be "value"
    }

    It "Prefers value from override if present in both places" {
        $ht = @{
            key = "{{ tc.key }}"
            tc  = @{ key = "value" }
        }

        $override = @{
            "tc.key" = "another_value"
        }

        $value = Test-PlaceholderInContext $override $ht "tc.key"
        $value | Should -Be "another_value"
    }

    It "Gets value from override when absent in the tree" {
        $ht = @{
            key = "{{ tc.key }}"
        }

        $override = @{
            "tc.key" = "another_value"
        }

        $value = Test-PlaceholderInContext $override $ht "tc.key"
        $value | Should -Be "another_value"
    }
}

Describe "Expand-Placeholders" {
    Context "Variable is not defined" {
        It "Throws when simple variable is not found and no override" {
            $ht = @{
                import = "{{ simpleVar }}"
            }
            $override = @{}

            { Expand-Placeholders $ht $override } | Should -Throw "Can't substitute value of 'simpleVar': not defined (in '.import')."
        }

        It "Throws when complex variable is not found and no override" {
            $ht = @{
                import = "{{ complex.var }}"
            }
            $override = @{}

            { Expand-Placeholders $ht $override } | Should -Throw "Can't substitute value of 'complex.var': not defined (in '.import')."
        }

        It "Throws when complex variable is not found and no override when part of the path exists" {
            $ht = @{
                import  = "{{ complex.var }}"
                complex = 13
            }
            $override = @{

            }

            { Expand-Placeholders $ht $override } | Should -Throw "Can't substitute value of 'complex.var': not defined (in '.import')."
        }
    }

    Context "Just overrides: primitive values" {
        It "References primitive property from override hashtable (structured, not flat)" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                thirdparty = @{
                    vendor = "goodbye"
                }
            }

            $result = Expand-Placeholders $ht $override

            $result.thirdparty.distribs | Should -Be "goodbye"
        }

        It "References primitive property from override hashtable (flat)" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                "thirdparty.vendor" = "goodbye"
            }

            $result = Expand-Placeholders $ht $override

            $result.thirdparty.distribs | Should -Be "goodbye"
        }

        It "Prefers flat path to the structured path from the override hashtable for primitive property" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                "thirdparty.vendor" = "flat"
                thirdparty          = @{
                    vendor = "structured"
                }

            }

            $result = Expand-Placeholders $ht $override

            $result.thirdparty.distribs | Should -Be "flat"
        }
    }

    Context "Just overrides: subtrees" {
        It "References property from override hashtable (structured, not flat)" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                thirdparty = @{
                    vendor = @{
                        value = 13
                    }
                }
            }

            $result = Expand-Placeholders $ht $override

            $result.Count | Should -Be 1
            $result.thirdparty.distribs | Should -BeOfType ([System.Collections.IDictionary])
            $result.thirdparty.distribs.value | Should -BeExactly 13

        }

        It "References property from override hashtable (flat)" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                "thirdparty.vendor" = @{
                    value = 13
                }
            }

            $result = Expand-Placeholders $ht $override

            $result.Count | Should -Be 1
            $result.thirdparty.distribs | Should -BeOfType ([System.Collections.IDictionary])
            $result.thirdparty.distribs.value | Should -BeExactly 13
        }

        It "Prefers flat path to the structured path from the override hashtable" {
            $ht = @{
                thirdparty = @{
                    distribs = "{{ thirdparty.vendor }}"
                }
            }

            $override = @{
                "thirdparty.vendor" = @{
                    value = 12
                }
                thirdparty          = @{
                    vendor = @{
                        value = 13
                    }
                }

            }

            $result = Expand-Placeholders $ht $override

            $result.Count | Should -Be 1
            $result.thirdparty.distribs | Should -BeOfType ([System.Collections.IDictionary])
            $result.thirdparty.distribs.value | Should -BeExactly 12
        }
    }

    Context "Pure substitutions" {
        It "Expands pure substitution (string) without override" {
            $ht = @{
                key = "{{ tc.key }}"
                tc  = @{ key = "value" }
            }

            $newHt = Expand-Placeholders $ht @{}

            $newHt.Count | Should -Be 2
            ($newHt.key) | Should -Be "value"
        }

        It "Expands pure substitution (int) without override" {
            $ht = @{
                key = "{{ tc.key }}"
                tc  = @{ key = 13 }
            }

            $newHt = Expand-Placeholders $ht @{}

            $newHt.Count | Should -Be 2
            ($newHt.key) | Should -BeExactly 13
        }

        It "Expands pure substitution (string) with override" {
            $ht = @{
                key = "{{ tc.key }}"
            }

            $override = @{
                "tc.key" = "tc.value"
            }

            $newHt = Expand-Placeholders $ht $override

            ($newHt.key) | Should -Be "tc.value"
        }

        It "Expands pure substitution (int) with override" {
            $ht = @{
                key = "{{ tc.key }}"
            }

            $override = @{
                "tc.key" = 13
            }

            $newHt = Expand-Placeholders $ht $override

            ($newHt.key) | Should -Be 13
        }

        It "Expands array of one pure substitution (string) with override" {
            $ht = @{
                arr = @(, "{{ tc.key }}") # here shitty unrolling will happen and array will become a string
            }

            $override = @{
                "tc.key" = "tc.value"
            }

            $ht.arr | Should -BeOfType [string]

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 1
            $newHt.arr | Should -BeOfType [string]
            $newHt.arr | Should -Be "tc.value"
        }

        It "Expands array of one pure substitution (int) with override" {
            $ht = @{
                arr = @(, "{{ tc.key }}") # here shitty unrolling will happen and array will become a string
            }

            $override = @{
                "tc.key" = 13
            }

            $ht.arr | Should -BeOfType [string]

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 1
            $newHt.arr | Should -BeExactly 13
        }

        It "Expands array of two pure substitutions (string) with override" {
            $ht = @{
                arr = @( "{{ tc.key1 }}", "{{ tc.key2 }}" ) # here shitty unrolling will happen and array will become a string
            }

            $override = @{
                "tc.key1" = "tc.value1"
                "tc.key2" = "tc.value2"
            }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 1

            $newHt.arr | Should -HaveCount 2
            $newHt.arr[0] | Should -Be "tc.value1"
            $newHt.arr[1] | Should -Be "tc.value2"
        }

        It "Expands array of two pure substitutions (int and bool) with override" {
            $ht = @{
                arr = @( "{{ tc.key1 }}", "{{ tc.key2 }}" ) # here shitty unrolling will happen and array will become a string
            }

            $override = @{
                "tc.key1" = 13
                "tc.key2" = $false
            }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 1

            $newHt.arr | Should -HaveCount 2
            $newHt.arr[0] | Should -BeExactly 13
            $newHt.arr[1] | Should -BeExactly $false
        }

        It "Expands hash value from the same tree (string)" {
            $ht = @{
                suite   = @{
                    root = "rootValue"
                }
                depends = "{{ suite.root }}"
            }

            $override = @{ }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2

            $newHt.suite | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.suite.root | Should -Be "rootValue"

            $newHt.depends | Should -Be "rootValue"
        }
    }

    Context "String interpolations" {
        It "Expands hash value in array from HT and override" {
            $ht = @{
                suite   = @{
                    root = "rootValue"
                }
                depends = "[{{ suite.root }}] [{{ tc.key }}]"
            }

            $override = @{ "tc.key" = "tc.value" }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2

            $newHt.suite | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.suite.root | Should -Be "rootValue"

            $newHt.depends | Should -Be "[rootValue] [tc.value]"
        }

        It "Expands nested variables references" {
            $ht = @{
                var1 = "{{var2 }}"
                var2 = "{{ var.4 }} {{ var3}}"
                var3 = "{{var.4}}1"
            }

            $override = @{ "var.4" = "finalValue" }

            $newHt = Expand-Placeholders $ht $override
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 3

            $newHt.var1 | Should -Be "finalValue finalValue1"
            $newHt.var2 | Should -Be "finalValue finalValue1"
            $newHt.var3 | Should -Be "finalValue1"
        }

        It "Throws on recursive placeholders declarations" -Skip {
            $ht = @{
                var1 = "{{ var.3 }}"
                var2 = "{{ var1 }}"
            }

            $override = @{ "var.3" = "{{ var2 }}" }

            { Expand-Placeholders $ht $override } | Should -Throw "Recursion in placeholders declaration in one of the placeholders."
        }

        It "Preserves types on expansion" {
            $ht = @{
                bool   = $false
                int    = 32
                string = "str"
                arr    = @(1, 2)
            }

            $expanded = Expand-Placeholders $ht @{}

            # $expanded | Should -HaveCount 3
            $expanded.int | Should -BeExactly 32
            $expanded.string | Should -BeExactly "str"
            $expanded.arr | Should -BeExactly @(1, 2)
            $expanded.bool | Should -BeExactly $false
        }
    }

    Context "Tree substitutions: no override" {
        It "Expands subtree substitution" {
            $ht = @{
                one  = @{
                    two = @{
                        three = @{
                            four = "TestValue"
                        }
                    }
                }
                test = "{{ one.two }}"
            }

            $override = @{ }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.test | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.test.three | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.test.three.four | Should -Be "TestValue"
        }

        It "Expands subtree with nested subtree" {
            $ht = @{
                zero = @{
                    three = @{
                        four = "TestValue"
                    }
                }
                one  = @{
                    two = "{{ zero }}"
                }
                test = "{{ one.two }}"
            }

            $override = @{ }

            $newHt = Expand-Placeholders $ht $override

            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            # $newHt.Count | Should -be 2
            $newHt.test | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.test.three | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.test.three.four | Should -Be "TestValue"
        }

        It "References in item from the subtree which itself is substituted" {
            $ht = @{
                import = "{{ test.sub1 }}"
                one    = @{
                    two = @{
                        sub1 = "Source1"
                        five = "{{ one.two.sub1 }}"
                    }
                }
                test   = "{{ one.two }}"
            }

            $override = @{ }

            $newHt = Expand-Placeholders $ht $override

            $newHt.Count | Should -Be 3

            $newHt.test | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.test.Count | Should -Be 2
            $newHt.test.sub1 | Should -Be "Source1"
            $newHt.test.five | Should -Be "Source1"

            $newHt.import | Should -Be "Source1"
        }

        It "Uses the yet unreferenced value from the tree" {
            $ht = @{
                test = "{{ tree.two }}"
                tree = "{{ one }}"
                one  = @{
                    two = "one.two"
                }
            }

            $override = @{ }

            $result = Expand-Placeholders $ht $override
            $result.Count | Should -Be 3

            $result.one.two | Should -Be "one.two"
            $result.tree.two | Should -Be "one.two"
            $result.test | Should -Be "one.two"
        }

        It "Uses the yet unreferenced value from the tree which in turn substitutes another tree" {
            $ht = @{
                test   = "{{ tree.two }}"
                tree   = "{{ second.tree }}"
                second = @{
                    tree = "{{ one }}"
                }
                one    = @{
                    two = "one.two"
                }
            }

            $override = @{ }

            $result = Expand-Placeholders $ht $override
            $result.Count | Should -Be 4

            $result.one.two | Should -Be "one.two"
            $result.tree.two | Should -Be "one.two"
            $result.test | Should -Be "one.two"
        }

        It "Throws when the yet unreferenced value from the tree which in turn substitutes another tree which doesn't contain a tree" {
            $ht = @{
                test   = "{{ tree.two }}" # error
                tree   = "{{ second.tree }}" # = 'one'
                second = @{
                    tree = "one"
                }
                one    = @{
                    two = "one.two"
                }
            }

            $override = @{ }

            { Expand-Placeholders $ht $override } | Should -Throw "Can't substitute value of 'tree.two': not defined (in '.test')."
        }
    }

    Context "Pipline" {
        It "Simple function in pipleine works" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | toLower() }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.ToLower()
        }
        It "Chain of simple functions in pipleine works no brackets" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | toLower | toUpper }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.ToUpper()
        }

        It "Chain of simple functions in pipleine works" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | toLower() | toUpper() }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.ToUpper()
        }

        It "Chain of simple functions in pipleine works" -Tag "varfunctions" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | substring(0,1) | toUpper() }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.Substring(0, 1).ToUpper()
        }

        It "Chain of complex substitution functions in pipleine works" -Tag "varfunctions" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = @{
                    subvar = $origValue
                }
                sutVar  = "{{ somevar.subvar | substring(0,1) | toUpper() }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.Substring(0, 1).ToUpper()
        }
        It "Simple function replace" {
            $origValue = "ORIGINAL_value"
            $replacePart = "_val"
            $replaceValue = "@123@"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | replace('$replacePart','$replaceValue') }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $origValue.Replace($replacePart, $replaceValue)
        }

        It "Simple function in pipleine works" {
            $origValue = "net60"
            $targetValue = "net6.0"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | replace('net60', 'net6.0') }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly $targetValue.ToLower()
        }
        It "Longer parth for var and function in pipleine works" {
            $origValue = "net6.0"
            $targetValue = "net60"
            $ht = @{
                somevar   = @{
                    subvar = $origValue
                }
                targetVar = "{{ somevar.subvar | replace('.', '') }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.targetVar | Should -BeExactly $targetValue.ToLower()
        }


        It "Missing function should throw" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "{{ somevar | nonExistentFunction() }}"
            }

            { Expand-Placeholders $ht } | Should -Throw "Unsupported function name: 'nonExistentFunction'. Could not resolve 'ORIGINAL_value'."

        }
        It "String interpolation works with functions" {
            $origValue = "ORIGINAL_value"
            $ht = @{
                somevar = $origValue
                sutVar  = "This is {{ somevar? | toLower() }} and replaced is {{ somevar? | replace('ORIGINAL', 'REPLACED') | toLower }}"
            }

            $newHt = Expand-Placeholders $ht
            $newHt | Should -BeOfType ([System.Collections.IDictionary])
            $newHt.Count | Should -Be 2
            $newHt.sutVar | Should -BeExactly "This is $($origValue.ToLower()) and replaced is replaced_value"
        }
    }

    Context "Empty array argument tokens" {
        It "default([]) returns empty string (not literal [])" {
            $ht = @{ out = "{{ missing | default([]) }}" }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly $null
        }

        It "default([]) followed by join(' ') yields empty string" {
            $ht = @{ out = "{{ missing | default([]) | join(' ') }}" }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly ""
        }

        It "default([]) followed by length() equals 0" {
            $ht = @{ out = "{{ missing | default([]) | length() }}" }
            $e = Expand-Placeholders $ht
            $e.out | Should -Be 0
        }

        It "join(' ') on real array still works" {
            $ht = @{ arr = @('a', 'b'); out = "{{ arr | join(' ') }}" }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "a b"
        }
        # this is not yet supported by our pipeline parser
        # It "default([1,2,3]) returns array (not literal [])" {
        #     $ht = @{ out = "{{ missing | default([1,2,3]) }}" }
        #     $e = Expand-Placeholders $ht
        #     $e.out | Should -BeExactly @(1, 2, 3)
        # }
        # It "default([a, b, c]) returns array (not literal [])" {
        #     $ht = @{ out = "{{ missing | default([a, b, c]) }}" }
        #     $e = Expand-Placeholders $ht
        #     $e.out | Should -BeExactly @("a", "b", "c")
        # }
    }

    Context "Escaped substitutions with ~!{{ }}" {
        It "Escaped pure substitution remains untouched" {
            $ht = @{
                var = "value"
                out = "~!{{ var }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ var }}"
        }

        It "Escaped substitution in string interpolation" {
            $ht = @{
                var1 = "value1"
                var2 = "value2"
                out  = "Text ~!{{ var1 }} and {{ var2 }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "Text ~!{{ var1 }} and value2"
        }

        It "Mixed escaped and normal substitutions" {
            $ht = @{
                a   = "aValue"
                b   = "bValue"
                c   = "cValue"
                out = "~!{{ a }} then {{ b }} then ~!{{ c }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ a }} then bValue then ~!{{ c }}"
        }

        It "Escaped substitution with pipeline remains untouched" {
            $ht = @{
                var = "VALUE"
                out = "~!{{ var | toLower() }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ var | toLower() }}"
        }

        It "Escaped substitution without closing braces remains untouched" {
            $ht = @{
                var = "value"
                out = "~!{{ var"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ var"
        }

        It "Escaped empty substitution remains untouched" {
            $ht = @{
                out = "~!{{ }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ }}"
        }

        It "Nested escaped patterns handled correctly" {
            $ht = @{
                var = "value"
                out = "~!{{ ~!{{ var }} }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ ~!{{ var }} }}"
        }

        It "Date escaping still works at start of string" {
            $ht = @{
                out = "~!2025-09-15"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "2025-09-15"
        }

        It "Date escaping does not interfere with escaped substitutions" {
            $ht = @{
                asOfDate = "2025-09-15"
                out1     = "~!2025-09-15"
                out2     = "~!{{ asOfDate }}"
            }
            $e = Expand-Placeholders $ht
            $e.out1 | Should -BeExactly "2025-09-15"
            $e.out2 | Should -BeExactly "~!{{ asOfDate }}"
        }

        It "Multiple escaped substitutions in same string" {
            $ht = @{
                a   = "A"
                b   = "B"
                c   = "C"
                out = "Start ~!{{ a }} middle ~!{{ b }} end ~!{{ c }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "Start ~!{{ a }} middle ~!{{ b }} end ~!{{ c }}"
        }

        It "Escaped substitution with complex pipeline" {
            $ht = @{
                var = "value"
                out = "~!{{ var | toLower() | replace('a', 'b') }}"
            }
            $e = Expand-Placeholders $ht
            $e.out | Should -BeExactly "~!{{ var | toLower() | replace('a', 'b') }}"
        }
    }

}

Describe "Test-StringFromHashtable" {
    It "Pass one level hashtable - verify result" {
        $ht = @{"key1" = "value1"; }
        Get-StringFromHashtable $ht | Should -Be "@{""key1""=""value1""}"
    }

    It "Pass nested level hashtable - verify result" {
        $ht = @{"key1" = "value1"; "key2" = @{"key3" = "value3"; } }
        $actual = Invoke-Expression (Get-StringFromHashtable $ht)

        $actual.key1 | Should -Be "value1"
        $actual.key2.key3 | Should -Be "value3"
        $actual.Count | Should -Be 2
        $actual.key2.Count | Should -Be 1
    }
}



Describe "Expand-PlaceholdersInStrings" {
    It "Variables substitution simple case" {
        $in = @'
var sets = db.getCollection('{{ mongo_sets_coll_name }}');
sets.createIndex( { _pid : 1 });
sets.createIndex( { _par : 1 });
var entries = db.getCollection('{{ mongo_entries_coll_name }}');
'@
        $variables = @{
            mongo_sets_coll_name    = "111"
            mongo_entries_coll_name = "222"
        }
        $expected = @'
var sets = db.getCollection('111');
sets.createIndex( { _pid : 1 });
sets.createIndex( { _par : 1 });
var entries = db.getCollection('222');
'@ -split '\r?\n'

        $inLines = $in -split '\r?\n'
        $actual = Expand-PlaceholdersInStrings -lines $inLines -context $variables

        $actual.Length | Should -Be $expected.Length
        $actual | Should -Be $expected
    }

}

Describe "Expand-Placeholders OrderedDictionary Tests" {
    It "Should handle OrderedDictionary without infinite recursion (with timeout)" {
        $ht = [ordered]@{
            "key1" = "value1"
            "key2" = "{{ key1 }}"
        }

        { Invoke-WithTimeout { param($value) Expand-Placeholders $value } -ArgumentList @($ht) } | Should -Not -Throw
    }

    It "Should handle nested OrderedDictionary without infinite recursion (with timeout)" {
        $ht = [ordered]@{
            "outer" = [ordered]@{
                "inner" = "{{ outer.value }}"
                "value" = "test"
            }
        }

        { Invoke-WithTimeout { param($value) Expand-Placeholders $value } -ArgumentList @($ht) } | Should -Not -Throw
    }

    It "Should throw on circular references in OrderedDictionary (with timeout)" {
        $ht = [ordered]@{
            "a" = "{{ b }}"
            "b" = "{{ a }}"
        }

        # 15s timeout, not 2s: `Invoke-WithTimeout` spawns a child pwsh job
        # whose startup alone eats a meaningful chunk of the budget under
        # parallel CI load (TestRepositoryPester runs 4 suites concurrently
        # via `ForEach-Object -Parallel` in a CI psakefile).
        # The test asserts the recursion detector fires — not that it fires
        # within 2s. 15s still bounds the worst case ("logic error caught
        # vs. true infinite loop") while leaving room for slow CPU.
        { Invoke-WithTimeout { param($value) Expand-Placeholders $value } -ArgumentList @($ht) -TimeoutSeconds 15 } | Should -Throw "Recursion in placeholders declaration*"
    }


    It "Should throw on complex circular references (with timeout)" {
        $ht = [ordered]@{
            "a" = "{{ b }}"
            "b" = "{{ c }}"
            "c" = "{{ a }}"
        }

        # Same 15s rationale as the 2-cycle test above. The 3-cycle path
        # walks slightly more nodes and was the suite that actually flaked
        # in pipeline 1164 (2.29s observed against a 2s budget).
        { Invoke-WithTimeout { param($value) Expand-Placeholders $value } -ArgumentList @($ht) -TimeoutSeconds 15 } | Should -Throw "Recursion in placeholders declaration*"
    }
}

Describe "Test-PlaceholderInTree Primitive Values" {
    It "Should return primitive value when it's the last part of the path" {
        $yaml = @{
            "env" = @{
                "tc" = @{
                    "source" = @{
                        "chain" = @{
                            "build" = @{
                                "counter" = "10720"
                            }
                        }
                    }
                }
            }
        }
        $value = Test-PlaceholderInTree $yaml "env.tc.source.chain.build.counter"
        $value | Should -Be "10720"
    }

    It "Should handle numeric primitive values" {
        $yaml = @{
            "root" = @{
                "numeric" = 42
            }
        }
        $value = Test-PlaceholderInTree $yaml "root.numeric"
        $value | Should -Be 42
    }

    It "Should handle boolean primitive values" {
        $yaml = @{
            "root" = @{
                "flag" = $true
            }
        }
        $value = Test-PlaceholderInTree $yaml "root.flag"
        $value | Should -Be $true
    }

    It "Should handle null primitive values" {
        $yaml = @{
            "root" = @{
                "nullValue" = $null
            }
        }
        $value = Test-PlaceholderInTree $yaml "root.nullValue"
        $value | Should -Be $null
    }

    It "Should handle primitive values in arrays" {
        $yaml = @{
            "root" = @{
                "array" = @(1, "two", $true)
            }
        }
        $value = Test-PlaceholderInTree $yaml "root.array"
        $value | Should -Be "yes"  # Arrays return "yes"
    }

    It "Should handle deep nested primitive values" {
        $yaml = @{
            "level1" = @{
                "level2" = @{
                    "level3" = @{
                        "value" = "deepValue"
                    }
                }
            }
        }
        $value = Test-PlaceholderInTree $yaml "level1.level2.level3.value"
        $value | Should -Be "deepValue"
    }

    It "Should handle primitive values in mixed nested structures" {
        $yaml = @{
            "mixed" = @{
                "array" = @(
                    @{
                        "value" = "nestedValue"
                    }
                )
            }
        }
        $value = Test-PlaceholderInTree $yaml "mixed.array"
        $value | Should -Be "yes"  # Arrays return "yes"
    }

    It "Complex substitutuion function in pipleine works" { # todo fix this test. - there is some problem wither. Also in real live it fails sometimes with like - first runs pipeline function like remove dots (and then tries to resolve broken path without dots)
        $origValue = "net6.0"
        $targetValue = "net60-aaaa"
        $ht = @{
            somevar   = @{
                subvar  = $origValue
                postfix = "aaaa"
            }
            targetVar = "{{ somevar.subvar | replace('.', '') }}-{{ somevar.postfix }}"
        }

        $newHt = Expand-Placeholders $ht
        $newHt | Should -BeOfType ([System.Collections.IDictionary])
        $newHt.Count | Should -Be 2
        $newHt.targetVar | Should -BeExactly $targetValue.ToLower()
    }
}
