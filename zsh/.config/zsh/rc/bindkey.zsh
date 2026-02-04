# --- Basic Bindkeys ---
bindkey -e # Use emacs-style keybindings

# Home/End/Del for standard terminals
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char

# --- Modern Keybindings for Plugins ---
# Ctrl+Space for Autosuggestion Accept
bindkey '^ ' autosuggest-accept

# Ctrl+R for History Search (handled by Zeno if installed)
# Zeno configuration handles this if sourced in .zshrc
