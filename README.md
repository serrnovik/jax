# Jax

Jax is a PowerShell 7 task runner for repository-owned environments, flows, scripts, and psake tasks. The CLI is installed once per user and can operate on the current Git repository or an explicit repository path; consumer repositories do not vendor the Jax runtime.

## Quick start

### Install from PowerShell Gallery

Prerequisite: PowerShell 7.2+. The package manager installs Jax and its pinned
`powershell-yaml` dependency for the current user.

```powershell
Install-PSResource Jax -Scope CurrentUser -TrustRepository
Import-Module Jax
Install-JaxShellIntegration -Shell powershell
jax help
```

PowerShellGet v2 is also supported:

```powershell
Install-Module Jax -Scope CurrentUser -Repository PSGallery
```

The one-time shell-integration command imports the newest installed Jax module
from your PowerShell profile, so `jax`, `jx`, `jxs`, and their completion are
ready before the first Tab press in every new PowerShell session. Without it,
module auto-loading makes commands available only after their first invocation.

### Use from zsh or bash

```powershell
Import-Module Jax
Install-JaxShellIntegration
```

By default this registers PowerShell plus the detected zsh or bash login shell.
When `SHELL` is unavailable to a non-interactive installer, it uses the platform
default (zsh on macOS, bash on Linux).
The thin, argument-safe `jax`, `jx`, and `jxs` functions route commands and
dynamic tab completion to PowerShell, so Jax keeps one implementation. Open a
new shell afterward. Pass `-Shell powershell,zsh,bash` to register all three.
The wrappers are sourced as shell functions from `~/.jax/shell`; they do not
need to be added to `PATH`. Bash integration is written to both `~/.bashrc` and
the login-shell `~/.bash_profile`. In zsh, Jax candidates open in a
command-scoped selection menu: use the arrow keys and Enter to choose.

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

Source contributors can run `./Install-Jax.ps1` directly in PowerShell to test
an unpublished build under `~/.jax/module`. It activates that build in the
current PowerShell and persistently pins PowerShell plus the detected zsh/bash
shell to it. When launched through a child `pwsh -File` process, run the
printed `Import-Module` command once in the parent process.

## Development

```powershell
pwsh -NoProfile -File ./tests/Invoke-Tests.ps1
pwsh -NoProfile -File ./tests/Test-PublicSource.ps1
```

The distributable is defined by `distribution-manifest.psd1`; tests and development assets are not installed. Bundled psake 4.9.1 retains its upstream MIT license in `psake/LICENSE`. It is Jax's compatibility task runner and keeps clean and offline installations deterministic; removing it would break existing psakefile-based repositories.

## License and security

Jax is licensed under Apache-2.0. Report suspected vulnerabilities privately as
described in [SECURITY.md](SECURITY.md).
