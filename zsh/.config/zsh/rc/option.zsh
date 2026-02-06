# --- Completion ---
setopt LIST_PACKED
unsetopt LIST_TYPES
zstyle ':completion:*' menu select=2

# --- Better Nav ---
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# --- Hooks ---
autoload -Uz add-zsh-hook

# cd した後に ls (eza) を自動実行
function chpwd_ls() {
  if type eza &>/dev/null; then
    eza --icons
  else
    ls -F
  fi
}
add-zsh-hook chpwd chpwd_ls

# Use bat for help/man if available
if type bat &>/dev/null; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
