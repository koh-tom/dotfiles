# --- Modern CLI Tools ---
alias v="nvim"
alias g="git"
alias lg="lazygit"
alias ra="yazi"

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

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# --- Convenience ---
alias reload='source ~/.zshrc'
alias dot='cd ~/dotfiles && lazygit'
alias wez='nvim ~/dotfiles/wezterm/.config/wezterm/wezterm.lua'
alias miseconfig='nvim ~/dotfiles/mise/.config/mise/config.toml'
