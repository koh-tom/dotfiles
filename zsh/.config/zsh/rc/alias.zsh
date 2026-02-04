# --- CLI Wrappers ---
alias v="nvim"
alias g="git"
alias lg="lazygit"

# --- ls (eza) replacement ---
if type eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lh --icons'
  alias la='eza -a --icons'
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
