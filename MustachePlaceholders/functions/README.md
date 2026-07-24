Examples:

```
  variables_playground:
    use_cases:
      run_type_effective: "{{ module.run_type | whenEq('prod','prod','sandbox') }}"
      ternary_ifElse: "{{ module.run_type | eq('prod') | ifElse('prod','sandbox') }}"
      coalesce_missing: "{{ module.variables_playground.missing | coalesce('default_value') }}"
      branch_lower_trim: "{{ module.branch_name | trim() | toLower() }}"
      env_contains_uat: "{{ flows.suite.env | contains('uat') }}"
      is_set_branch: "{{ module.branch_name | isSet() }}"
      is_empty_unknown: "{{ module.unknown | isEmpty() }}"
      length_branch: "{{ module.branch_name | length() }}"
      not_prod: "{{ module.run_type | eq('prod') | not() }}"
      or_example: "{{ module.run_type | eq('prod') | or(false) }}"
      and_example: "{{ module.run_type | eq('prod') | and(true) }}"
      env_home: "{{ module.run_type | env('HOME','nohome') }}"
```
