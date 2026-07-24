# Packaging decisions

## Decision

Jax ships publicly through PowerShell Gallery as an Apache-2.0 PowerShell
module. `Install-PSResource` is the primary installer and PowerShellGet v2
remains supported. Source checkout installation under `~/.jax/module` is for
contributors testing unpublished changes.

`Install-Module` and `Install-PSResource` install packages from registered PowerShell repositories, not Git URLs. The existing `Jax.psd1` and `Jax.psm1` are the package entry points; no runtime redesign is required when publishing is enabled later.

The module manifest declares the exact `powershell-yaml` 0.4.12 runtime
dependency. Source installation ensures that version is present; registered
PowerShell repositories resolve it from the manifest.

## Why this shape

- Preserves the existing sibling-directory runtime invariants.
- Works without administrator access on macOS, Linux, and Windows.
- Supports pinned Git revisions and future zip releases with the same manifest.
- Separates global tool installation from `jax init` repository scaffolding.
- Makes the installed artifact auditable through a single allowlist.

## Artifact manifest

`distribution-manifest.psd1` includes:

- launchers and the Jax PowerShell module;
- core public/private functions;
- generic templates and placeholder runtime;
- built-in production plugins;
- psake 4.9.1 runtime and its upstream license.

It excludes:

- Git history and checkout metadata;
- Pester tests and fixtures;
- psake development tests, images, CI files, and documentation;
- repository-specific templates and personal customizations;
- caches, logs, user config, state, and secrets.

## Versioning

Jax uses independent semantic versions stored in `VERSION` and mirrored in `Jax.psd1` and the distribution manifest. The initial standalone snapshot is `0.1.0`. A release workflow should verify all three values match before tagging.

## Release ownership

- License: Apache-2.0.
- Project and security contact: `sergey@novik.fr`.
- Source: `https://github.com/serrnovik/jax`.
- Package: PowerShell Gallery module `Jax`.
- The first Gallery publish is manual; automate only after the release path has
  been exercised without exposing the API key.

The complete manual sequence is in
[OPEN-SOURCE-RELEASE.md](OPEN-SOURCE-RELEASE.md).
