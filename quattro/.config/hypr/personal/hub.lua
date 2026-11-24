-- Claude の母艦 (scripts/claude-hub) につなぐ。常時起動のマシンの tmux で動いている Claude を開く
o.bind("SUPER + ALT + H", "Claude hub", "uwsm-app -- xdg-terminal-exec --title=claude-hub $HOME/dotfiles/scripts/claude-hub")
