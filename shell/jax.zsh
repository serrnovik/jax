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

_jax_enable_zsh_menu_completion() {
    zmodload -i zsh/complist 2>/dev/null || return 0
    zstyle ':completion:*:*:jax:*' menu select=1
    zstyle ':completion:*:*:jx:*' menu select=1
    zstyle ':completion:*:*:jxs:*' menu select=1
}

_jax_register_zsh_completion() {
    (( $+functions[compdef] )) || return 0
    compdef _jax_zsh_completion jax jx jxs
    if (( $+functions[add-zsh-hook] )); then
        add-zsh-hook -d precmd _jax_register_zsh_completion 2>/dev/null
    fi
}

_jax_enable_zsh_menu_completion

if (( $+functions[compdef] )); then
    _jax_register_zsh_completion
else
    # Some frameworks run compinit after user profile fragments. Register on
    # the first prompt as well so their later compinit cannot leave Jax on the
    # filesystem fallback completer.
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _jax_register_zsh_completion
fi
