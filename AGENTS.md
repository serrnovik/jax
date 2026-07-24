# Jax contributor instructions

- Jax supports PowerShell 7.2+ on macOS, Linux, and Windows.
- Keep runtime paths relative to the installed tool root; keep task/config paths relative to the target repository root.
- Use `-RepoRoot` or its `-C` alias in out-of-tree tests.
- Do not add product names, internal hosts, credentials, user-specific paths, or personal shorthand comments.
- Update `distribution-manifest.psd1` when a new runtime file is required.
- Run `pwsh -NoProfile -File tests/Invoke-Tests.ps1` before committing.
- Do not publish a release unless the Apache-2.0 metadata, full tests, and public-source audit pass.
