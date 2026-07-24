# Jax zsh integration. All Jax logic remains in PowerShell.
typeset -g _jax_shell_root="${${(%):-%x}:A:h}"
typeset -g _jax_pwsh="$(command -v pwsh 2>/dev/null)"

_jax_invoke() {
    if [[ -z "$_jax_pwsh" || ! -x "$_jax_pwsh" ]]; then
        print -u2 "jax: PowerShell 7+ (pwsh) is required."
        return 127
    fi
    local entry_point="$1"
    shift
    JAX_SHELL_ENTRYPOINT="$entry_point" \
        "$_jax_pwsh" -NoLogo -NoProfile \
        -File "$_jax_shell_root/Jax.ShellLauncher.ps1" "$@"
}

jax() { _jax_invoke jax "$@" }
jx() { _jax_invoke jx "$@" }
jxs() { _jax_invoke jxs "$@" }

_jax_zsh_completion() {
    local -a candidates
    candidates=("${(@f)$(
        "$_jax_pwsh" -NoLogo -NoProfile \
            -File "$_jax_shell_root/Jax.ShellCompletion.ps1" "$BUFFER" "$CURSOR" 2>/dev/null
    )}")
    (( ${#candidates[@]} > 0 )) && compadd -Q -- "${candidates[@]}"
}

if (( $+functions[compdef] )); then
    compdef _jax_zsh_completion jax jx jxs
fi
