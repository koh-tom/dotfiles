# ----------------------------------------------------
# 1. Faster Loading: zcompile - Compile zsh files
# ----------------------------------------------------
function ensure_zcompiled {
  local src=$1
  local zwc="$src.zwc"
  local dir="${src:h}"
  if [[ ! -w "$dir" ]]; then
    return
  fi
  if [[ ! -r "$zwc" || "$src" -nt "$zwc" ]]; then
    zcompile "$src"
  fi
}

function source_compiled {
  ensure_zcompiled "$1"
  builtin source "$1"
}

# ----------------------------------------------------
# 2. Keybinds, Options & Aliases
# ----------------------------------------------------
fpath=($ZDOTDIR/rc/functions $ZDOTDIR/rc/functions/*(/N) $fpath)
autoload -Uz $ZDOTDIR/rc/functions/*(-.N:t) $ZDOTDIR/rc/functions/**/*(-.N:t)

source_compiled "$ZDOTDIR/rc/alias.zsh"
source_compiled "$ZDOTDIR/rc/option.zsh"
source_compiled "$ZDOTDIR/rc/bindkey.zsh"

# ----------------------------------------------------
# 3. Sheldon Plugin Manager (Plugin loadings)
# ----------------------------------------------------
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
sheldon_cache="$cache_dir/sheldon.zsh"
sheldon_toml="$HOME/.config/sheldon/plugins.toml"

if [[ ! -r "$sheldon_cache" || "$sheldon_toml" -nt "$sheldon_cache" ]]; then
  mkdir -p $cache_dir
  /home/koh/.local/share/mise/shims/sheldon source > "$sheldon_cache"
  zcompile "$sheldon_cache"
fi
source_compiled "$sheldon_cache"

# ----------------------------------------------------
# 4. mise (Delayed activation)
# ----------------------------------------------------
if type mise &>/dev/null; then
  _mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/mise.zsh"
  if [[ ! -r "$_mise_cache" || "$(command -v mise)" -nt "$_mise_cache" ]]; then
    mise activate zsh > "$_mise_cache"
    mise activate --shims >> "$_mise_cache"
    zcompile "$_mise_cache"
  fi
  zsh-defer source_compiled "$_mise_cache"
fi

# ----------------------------------------------------
# 5. Core Options
# ----------------------------------------------------
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt correct
setopt interactive_comments
setopt no_beep

# History
HISTFILE=$ZDOTDIR/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY

# ----------------------------------------------------
# 6. zoxide (z: jump around directories)
# ----------------------------------------------------
if type zoxide &>/dev/null; then
  _zoxide_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zoxide.zsh"
  if [[ ! -r "$_zoxide_cache" || "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
    zoxide init zsh > "$_zoxide_cache"
    zcompile "$_zoxide_cache"
  fi
  source_compiled "$_zoxide_cache"
fi

# ----------------------------------------------------
# 7. Starship Prompt (Must be after other tools)
# ----------------------------------------------------
if type starship &>/dev/null; then
  _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship.zsh"
  _starship_config="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
  if [[ ! -r "$_starship_cache" || "$_starship_config" -nt "$_starship_cache" || "$(command -v starship)" -nt "$_starship_cache" ]]; then
    starship init zsh > "$_starship_cache"
    zcompile "$_starship_cache"
  fi
  source_compiled "$_starship_cache"
fi

# ----------------------------------------------------
# 8. WezTerm Shell Integration & Semantic Jump [B-5 link]
# ----------------------------------------------------
# WezTerm のシェル統合スクリプトを読み込み、ジャンプ機能を有効にする
if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
  # zsh-defer で遅延読み込みして起動速度を優先
  zsh-defer source_compiled "$HOME/.config/zsh/rc/pluginconfig/wezterm.zsh"
fi

# ----------------------------------------------------
# 9. Zeno.zsh (SQLite History Search & Abbr)
# ----------------------------------------------------
# Sheldon で zeno がロードされた後に実行する必要があるため末尾付近に配置
if [[ -n "$ZENO_HOME" ]]; then
  export ZENO_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zeno"
  # zeno の初期化 (Sheldon で zeno 読込済み)
fi

# ----------------------------------------------------
# 10. Simple completion
# ----------------------------------------------------
zstyle ':completion:*' matcher-list "" 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'
zstyle ':completion:*' format '%B%F{blue}%d%f%b'
zstyle ':completion:*' group-name ""
zstyle ':completion:*:default' menu select=2
autoload -Uz compinit && compinit
