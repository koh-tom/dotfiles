# /etc/zprofile, /etc/zshrc, /etc/zlogin をスキップ (Ubuntu)
setopt no_global_rcs

# XDG
export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share
export XDG_STATE_HOME=${HOME}/.local/state

# ZDOTDIR
export ZDOTDIR=$XDG_CONFIG_HOME/zsh

# Path
export PATH=$HOME/.local/bin:$PATH
export PATH=/usr/local/sbin:$PATH

# WezTerm integration
if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
  export PATH="$HOME/.local/share/wezterm:$PATH"
fi

# mise shims (for subshells)
export PATH="$HOME/.local/share/mise/shims:$PATH"
