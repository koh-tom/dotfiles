# /etc/zprofile, /etc/zshrc, /etc/zlogin をスキップ (Ubuntu)
setopt no_global_rcs

# XDG
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-${HOME}/.cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-${HOME}/.local/share}
export XDG_STATE_HOME=${XDG_STATE_HOME:-${HOME}/.local/state}

# Omarchy の現在テーマの場所: 4.x (Quattro) は ~/.local/state/omarchy/current、
# 3.x は ~/.config/omarchy/current。両対応のため存在する方を使う。
if [[ -d "$XDG_STATE_HOME/omarchy/current/theme" ]]; then
  export OMARCHY_CURRENT_DIR="$XDG_STATE_HOME/omarchy/current"
else
  export OMARCHY_CURRENT_DIR="$HOME/.config/omarchy/current"
fi

# Omarchy creates this file from the user theme template on theme changes.
if [[ -r "$OMARCHY_CURRENT_DIR/theme/starship.toml" ]]; then
  export STARSHIP_CONFIG="$OMARCHY_CURRENT_DIR/theme/starship.toml"
else
  export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
fi

# ZDOTDIR
export ZDOTDIR=$XDG_CONFIG_HOME/zsh

# Path (入れ子のシェルで同じディレクトリが何度も先頭に足されないよう重複を除く)
typeset -U path PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=/usr/local/sbin:$PATH

# WezTerm integration
if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
  export PATH="$HOME/.local/share/wezterm:$PATH"
fi

# mise shims (for subshells)
export PATH="$HOME/.local/share/mise/shims:$PATH"
