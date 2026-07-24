# Jax

Jax is a PowerShell 7 task runner for repository-owned environments, flows, scripts, and psake tasks. The CLI is installed once per user and can operate on the current Git repository or an explicit repository path; consumer repositories do not vendor the Jax runtime.

## Quick start

### Install from PowerShell Gallery

Prerequisite: PowerShell 7.2+. The package manager installs Jax and its pinned
`powershell-yaml` dependency for the current user.

```powershell
Install-PSResource Jax -Scope CurrentUser -TrustRepository
Import-Module Jax
jax help
```

PowerShellGet v2 is also supported:

```powershell
Install-Module Jax -Scope CurrentUser -Repository PSGallery
```

PowerShell module auto-loading makes `jax`, `jx`, and `jxs` available in later
PowerShell sessions. Import the module explicitly when you want completion in
the current session.

### Use from zsh or bash

```powershell
Import-Module Jax
Install-JaxShellIntegration
```

This installs thin, argument-safe `jax`, `jx`, and `jxs` functions into the
detected zsh or bash profile. They route commands and dynamic tab completion to
PowerShell, so Jax keeps one implementation. Open a new shell afterward. Pass
`-Shell zsh,bash` to register both shells.

## Start a new consumer repository

```powershell
New-Item -ItemType Directory sample-app
git -C sample-app init

jax -C ./sample-app init -client sample -env dev
jax -C ./sample-app list-envs
jax -C ./sample-app list-tasks -env sample/dev
jax -C ./sample-app run -env sample/dev -only Build -noSavedSettings
```

`jax init` creates a concise, readable `.jax/jax.config.yml` that makes the
repository layout, discovery rules, icons, and enabled plugins visible to
humans and agents. It also creates safe local-state ignores, a three-level
environment hierarchy with tracked directory anchors, a default flow, and
runnable example psake tasks. Compatibility-only conventions are omitted.
Existing files are preserved.

Pass `-Customize` when you want the interactive repository-config wizard.

### Add the Jax agent skill to the consumer repository

Install Jax's bundled cross-agent guidance into the repository so Codex and
other agents can follow the same setup and run conventions:

```powershell
jax -C ./sample-app skill
```

This writes `.agents/skills/jax/` in the consumer repository. Review and
commit it with the Jax scaffold; re-run the command after updating Jax to pick
up skill changes.

### Diagnose an installation or repository

Use `info` when a command behaves unexpectedly or before reporting a problem:

```powershell
jax -C ./sample-app info
```

It prints the installed version, runtime path, source commit recorded at
installation time, target Git repository and branch, plus repository, user, and
local-state configuration presence. It never prints configuration values or
secrets.

Inside the repository, `-C` is optional:

```powershell
Set-Location sample-app
jax -env sample/dev -only Test
```

See [consumer onboarding](docs/CONSUMER-ONBOARDING.md) for configuration ownership, CI use, and an adoption checklist.

## Target repository rules

- `-RepoRoot <path>` and `-C <path>` explicitly select the consumer repository.
- Without either flag, Jax resolves the nearest Git root from the current directory.
- `JAX_REPO_ROOT` remains available for compatibility, but an explicit CLI path wins.
- Tool assets—core, built-in plugins, templates, placeholders, and bundled psake—resolve from the installed module.
- Consumer assets—`.jax/`, `env/`, flows, scripts, config imports, and logs—resolve from the target repository.

## Update or uninstall

Update the Gallery package:

```powershell
Update-PSResource Jax -Scope CurrentUser -Repository PSGallery -TrustRepository
# PowerShellGet v2:
Update-Module Jax
```

Gallery versions install side by side. Restart PowerShell or run
`Import-Module Jax -Force` after updating. Re-run
`Install-JaxShellIntegration` only when its shell bridge itself changes.

Uninstall:

```powershell
Uninstall-PSResource Jax
# PowerShellGet v2:
Uninstall-Module Jax
```

Source contributors can still run `Install-Jax.ps1` from a checkout to test an
unpublished build under `~/.jax/module`; that is a development workflow, not
the public installation path.

## Development

```powershell
pwsh -NoProfile -File ./tests/Invoke-Tests.ps1
pwsh -NoProfile -File ./tests/Test-PublicSource.ps1
```

The distributable is defined by `distribution-manifest.psd1`; tests and development assets are not installed. Bundled psake 4.9.1 retains its upstream MIT license in `psake/LICENSE`.

## License and security

Jax is licensed under Apache-2.0. Report suspected vulnerabilities privately as
described in [SECURITY.md](SECURITY.md).
