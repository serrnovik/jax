# Open-source release

Jax is public under Apache-2.0. The dedicated GitHub repository and PowerShell
Gallery package are two views of the same audited release.

## Release gates

Complete these before publishing a version:

1. Confirm `LICENSE`, `Jax.psd1`, and `SECURITY.md` still identify
   Apache-2.0 and `sergey@novik.fr`.
2. Run the full tests and public-source audit on the exact commit to release.
3. Review the dedicated repository's Actions history and artifacts.
4. Enable Dependabot, secret scanning, and push protection where available.

The source snapshot publisher creates an audited root commit when the dedicated
remote is empty. It does not publish monorepo history, unpublished local mirror
commits, a source commit hash, or the operator's Git email.

The publisher also refuses to proceed when the selected source prefix has
uncommitted changes, the target remote does not match its configured URL, or
the target clone contains untracked or ignored local data. Commit the exact
source you reviewed before shipping it.

For the initial `0.1.0` publication only, collapse the pre-release snapshot into
one root commit:

```powershell
pwsh -NoProfile -File devops/subtree-ship/Ship-Subtree.ps1 jax -SquashToInitial
```

This intentionally rewrites `main` with `--force-with-lease`. It refuses a
target that already has more than one public commit or any public release tag.
After the initial release tag, always omit the switch so releases append normal
history:

```powershell
pwsh -NoProfile -File devops/subtree-ship/Ship-Subtree.ps1 jax
```

## Validate and stage a module package

From the standalone Jax checkout:

```powershell
pwsh -NoProfile -File ./tests/Invoke-Tests.ps1
pwsh -NoProfile -File ./tests/Test-PublicSource.ps1
Test-ModuleManifest -Path ./Jax.psd1 -ErrorAction Stop
pwsh -NoProfile -File ./Build-JaxPackage.ps1 -Force
```

`Build-JaxPackage.ps1` stages only the allowlisted runtime under
`.artifacts/Jax`; tests, source-only documentation, and local state are not
included.

Test the staged package in a clean PowerShell process:

```powershell
Import-Module ./.artifacts/Jax/Jax.psd1 -Force
jax help
```

## Publish to PowerShell Gallery

Do not use the Gallery as a test feed; published versions are effectively
permanent. First test the package through a local or private NuGet-compatible
repository.

For the first public release:

1. Create a PowerShell Gallery account and API key.
2. Check that the `Jax` name is available.
3. Store the API key in a secret store or a temporary environment variable; do
   not place it in a script, shell history, repository config, or CI log.
4. Publish the staged allowlisted package:

```powershell
$apiKey = $env:PSGALLERY_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'PSGALLERY_API_KEY is not set.'
}

Publish-PSResource `
    -Path ./.artifacts/Jax `
    -Repository PSGallery `
    -ApiKey $apiKey
```

PowerShellGet v2 remains a supported fallback:

```powershell
Publish-Module `
    -Path ./.artifacts/Jax `
    -Repository PSGallery `
    -NuGetApiKey $env:PSGALLERY_API_KEY
```

Verify installation from a clean user scope:

```powershell
Install-PSResource Jax -Scope CurrentUser -Repository PSGallery
Import-Module Jax -Force
jax info
```

For every later release, increment `VERSION`, `Jax.psd1`, and
`distribution-manifest.psd1` together. A Gallery version cannot be overwritten;
publish a new semantic version for every change.
