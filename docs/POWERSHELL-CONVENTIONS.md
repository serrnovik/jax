# PowerShell Conventions

## Naming

- `lowerCamelCase` for variables
- `UPPER_SNAKE_CASE` for constants
- `&` to call scripts

## Parameter Style

- 3+ params: each on new line
- 5+ params: prefer hashtable splatting
- Use `[datetime]::ParseExact` for ISO date parsing (`yyyy-MM-dd`)

## Module Layout

Every `.psm1` module **must** use the one-function-per-file pattern:

```
myModule/
├── myModule.psm1          # loader only — no function definitions
├── public/
│   ├── Get-Something.ps1  # one exported function per file, filename = function name
│   └── Set-Something.ps1
└── private/               # omit folder if no private helpers needed
    └── Resolve-Internal.ps1
```

### The `.psm1` loader

Dot-sources `public/` and `private/`, then exports by basename:

```powershell
$dotSourceParams = @{ Filter = '*.ps1'; Recurse = $true; ErrorAction = 'Stop' }

$public  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'public')  @dotSourceParams)
$private = @()
if (Test-Path (Join-Path $PSScriptRoot 'private')) {
    $private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'private') @dotSourceParams)
}

foreach ($import in @($public + $private)) {
    try { . $import.FullName } catch { throw "Unable to dot source [$($import.FullName)]" }
}

Export-ModuleMember -Function $public.BaseName
```

### Module-scope state

Constants, regex patterns, platform branches go at the top of the `.psm1` before the dot-source loop. Never put function definitions directly in the `.psm1`.

### Import pattern (always silent)

```powershell
Import-Module (Join-Path $gitRoot "path/to/myModule/myModule.psm1") -DisableNameChecking -Verbose:$false -Debug:$false 1>$null 4>$null 5>$null 6>$null
```

## Reference implementations

- `core/Jax.Core.psm1`
- `plugins/bob/Jax.Plugin.Bob.psm1`
- `MustachePlaceholders/MustachePlaceholders.psm1`
