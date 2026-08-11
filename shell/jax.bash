# Jax bash integration. All Jax logic remains in PowerShell.
_jax_shell_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_jax_pwsh="$(command -v pwsh 2>/dev/null || true)"

# jax, jx, and jxs are executable shims in $_jax_shell_root/bin, not shell
# functions. PATH is inherited by non-interactive shells, scripts, CI steps,
# and coding-agent shells; sourced functions are not. One command form then
# works everywhere.
case ":$PATH:" in
    *":$_jax_shell_root/bin:"*) ;;
    *)
        if [ -d "$_jax_shell_root/bin" ]; then
            PATH="$_jax_shell_root/bin:$PATH"
            export PATH
        fi
        ;;
esac

# Releases before 0.1.11 defined jax/jx/jxs as functions delegating to a private
# helper. Drop them so an older definition cannot shadow the shims.
unset -f jax jx jxs 2>/dev/null || true
hash -r 2>/dev/null || true

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
