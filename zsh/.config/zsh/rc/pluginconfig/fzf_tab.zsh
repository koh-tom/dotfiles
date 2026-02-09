# --- fzf-tab configuration ---
# https://github.com/Aloxaf/fzf-tab

# Disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# Set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# Set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# Preview file content with bat when completing cat/vi etc
zstyle ':fzf-tab:complete:(cat|vi|vim|nvim|bat):*' fzf-preview 'bat --color=always --line-range :500 $realpath'
# Preview git log when completing git etc
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always $word'
zstyle ':fzf-tab:complete:git-help:*' fzf-preview 'git help $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview 'git show --color=always $word | delta'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview '[ -f "$realpath" ] && git diff "$word" | delta || git log --color=always "$word"'

# Switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
