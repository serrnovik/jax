# Jax bash integration. All Jax logic remains in PowerShell.
_jax_shell_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_jax_pwsh="$(command -v pwsh 2>/dev/null || true)"

_jax_invoke() {
    if [ -z "$_jax_pwsh" ] || [ ! -x "$_jax_pwsh" ]; then
        echo "jax: PowerShell 7+ (pwsh) is required." >&2
        return 127
    fi
    local entry_point="$1"
    shift
    JAX_SHELL_ENTRYPOINT="$entry_point" \
        "$_jax_pwsh" -NoLogo -NoProfile \
        -File "$_jax_shell_root/Jax.ShellLauncher.ps1" "$@"
}

jax() { _jax_invoke jax "$@"; }
jx() { _jax_invoke jx "$@"; }
jxs() { _jax_invoke jxs "$@"; }

_jax_bash_completion() {
    COMPREPLY=()
    while IFS= read -r candidate; do
        [ -n "$candidate" ] && COMPREPLY+=("$candidate")
    done < <(
        "$_jax_pwsh" -NoLogo -NoProfile \
            -File "$_jax_shell_root/Jax.ShellCompletion.ps1" "$COMP_LINE" "$COMP_POINT" 2>/dev/null
    )
}

complete -F _jax_bash_completion jax jx jxs
