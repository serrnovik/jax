# jax — Worktree Isolation

Opt-in mode that lets multiple worktrees of this repo deploy to the same dev engine without colliding on namespaces or ports. Off by default.

`wtw go <task>` always sets `DEV_WORKTREE_*` env vars in the shell session. But jax only reads them when you **explicitly opt in** with the `-worktreeIsolation` (or `-wti`) flag:

```powershell
# Shared mode (default) — worktree vars ignored, same namespace/ports for all
jax -env sample-app/deploy -only DeployLocalPostgres -noSavedSettings

# Isolated mode — namespace gets "-auth" suffix, ports offset by 100
jax -env sample-app/deploy -only DeployLocalPostgres -worktreeIsolation -noSavedSettings
```

## Jaxfile variables exposed by the flag

| Jaxfile variable | Resolves to | When flag not passed |
|-----------------|-------------|---------------------|
| `{{ env.worktree.id }}` | `auth` | *(empty)* |
| `{{ env.worktree.index }}` | `1` | `0` |
| `{{ env.worktree.dashed_postfix }}` | `-auth` | *(empty)* |
| `{{ env.worktree.port_offset }}` | `100` | `0` |
| `{{ env.worktree.active }}` | `True` | `False` |

## Namespace

`Get-LocalDevNamespace` appends `env.worktree.dashed_postfix` when `env.worktree.active` is true. Example: `sample-app` becomes `sample-app-auth`.

## Ports

Use `{{ env.worktree.port_offset }}` in jaxfile templates, or read from `$properties` in deploy scripts.

## Example — jaxfile

```yaml
module:
  kubernetes:
    namespace: "{{ boss.suite.name }}{{ env.worktree.dashed_postfix }}"
```
