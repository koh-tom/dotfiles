# --- Modern CLI Tools ---
alias v="nvim"
alias g="git"
alias lg="lazygit"
alias ra="yazi"
alias ff="fastfetch"

# Yazi: cd on quit
# https://yazi-rs.github.io/docs/quick-start#shell-wrapper
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# --- ls (eza) replacement ---
if type eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --git --group-directories-first'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza --tree --icons'
else
  alias ls='ls -F --color=auto'
  alias ll='ls -lh'
  alias la='ls -A'
fi

# --- Nix ---
alias nd='nix develop --command zsh'  # devshellにzshのまま入る (❄表示とnixwhereが効く)
alias nw='nixwhere'                   # devshellのPATH可視化

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# --- Convenience ---
alias cheat='~/dotfiles/scripts/dotfiles-cheatsheet'  # 全キーバインド/スニペット/タスク検索
alias tip='~/dotfiles/scripts/dotfiles-tip'          # tips をランダム表示。tip -l で全件検索
alias reload='source "$ZDOTDIR/.zshrc"'
alias cz='czg'                       # 対話式conventional commits
alias dotcz='cd ~/dotfiles && czg'   # dotfilesをczgでコミット
alias dot='cd ~/dotfiles && lazygit'
alias wez='nvim ~/dotfiles/wezterm/.config/wezterm/wezterm.lua'
alias miseconfig='nvim ~/dotfiles/mise/.config/mise/config.toml'
