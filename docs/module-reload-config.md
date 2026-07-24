# Module Reload Configuration

The JAX module reload feature (`-forceReloadModules`) allows you to reload all modules during execution for development purposes. However, some modules may cause issues when reloaded (e.g., modules with `Add-Type` compilation dependencies).

## Configuration

You can configure which modules to exclude from reloading in your JAX configuration file.

### Location

Create or edit one of these files:

- **Repo config**: `.jax/jax.config.yml` (recommended for team-wide settings)
- **User config**: `~/.jax/config.yml` (for personal overrides)

### Example Configuration

```yaml
moduleReload:
  # Patterns (relative to repo root) of module paths to exclude from force reload
  excludePathPatterns:
    # Exclude all modules in the .build submodule
    - '.build/**/*.psm1'
    # Exclude specific problematic modules
    - 'jax/plugins/specific-plugin.psm1'
    # Exclude modules in any vendor directory
    - '**/vendor/**/*.psm1'
```

### Default Exclusions

The configurable exclusion list is empty by default. `Jax.Core.psm1` remains
hardcoded as always excluded. Add repository-specific paths such as
`.build/**/*.psm1` only when that layout exists in your repository.

### Pattern Syntax

- Use glob-style patterns relative to the repository root
- `**` matches any number of directory levels
- `*` matches any characters within a single path segment
- `?` matches a single character

### Examples

```yaml
moduleReload:
  excludePathPatterns:
    # Single directory
    - '.build/**/*.psm1'

    # Multiple directories
    - '.build/**/*.psm1'
    - 'external/**/*.psm1'
    - 'vendor/**/*.psm1'

    # Specific file patterns
    - '**/compiledClasses.psm1'
    - 'tools/build/compiled-types.psm1'
```

## Troubleshooting

If you see compilation errors like:

```
Add-Type: error CS0012: The type 'Object' is defined in an assembly that is not referenced.
You must add a reference to assembly 'netstandard, Version=2.1.0.0...'
```

This indicates a module has Add-Type dependencies that aren't available during reload. Add the problematic module's path to `excludePathPatterns`.

### Debug Mode

Use `-Debug` or `-dv` flags to see which modules are being skipped:

```powershell
jax -env myenv run -forceReloadModules -Debug
```

You'll see output like:

```
DEBUG: Skipping module '/path/to/module.psm1' (matches exclude pattern: .build/**/*.psm1)
DEBUG: Reloading module '/path/to/other.psm1'
```
