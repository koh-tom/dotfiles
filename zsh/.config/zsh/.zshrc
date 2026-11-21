# Runtime state belongs outside the Stow-managed source tree.
_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_zsh_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "$_zsh_cache_dir" "$_zsh_state_dir"

# ----------------------------------------------------
# 2. Keybinds, Options & Aliases
# ----------------------------------------------------
fpath=($ZDOTDIR/rc/functions $ZDOTDIR/rc/functions/*(/N) $fpath)
autoload -Uz $ZDOTDIR/rc/functions/*(-.N:t) $ZDOTDIR/rc/functions/**/*(-.N:t)

source "$ZDOTDIR/rc/alias.zsh"
source "$ZDOTDIR/rc/option.zsh"
source "$ZDOTDIR/rc/bindkey.zsh"

# ----------------------------------------------------
# 2.5. CLI theme (Omarchyパレット → fzf / bat / autosuggest)
# ----------------------------------------------------
_cli_theme="$_zsh_cache_dir/../dotfiles/cli-theme.zsh"
_omarchy_palette="${OMARCHY_CURRENT_DIR:-$HOME/.config/omarchy/current}/theme/colors.toml"
if [[ ! -r "$_cli_theme" || "$_omarchy_palette" -nt "$_cli_theme" ]]; then
  "$HOME/dotfiles/scripts/generate-cli-theme" >/dev/null 2>&1
fi
[[ -r "$_cli_theme" ]] && source "$_cli_theme"

# ----------------------------------------------------
# 3. Sheldon Plugin Manager (Plugin loadings)
# ----------------------------------------------------
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
sheldon_cache="$cache_dir/sheldon.zsh"
sheldon_toml="$HOME/.config/sheldon/plugins.toml"

# Zeno needs this before Sheldon loads the plugin.
# スニペット定義 (config.yml) はdotfilesで管理する
export ZENO_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/zeno"
# 起動のたびに走る `deno cache` (約11ms) を省く。zeno 更新後に補完が壊れたら一度 unset して起動すれば作り直される
export ZENO_DISABLE_EXECUTE_CACHE_COMMAND=1

if [[ ! -r "$sheldon_cache" || "$sheldon_toml" -nt "$sheldon_cache" ]]; then
  mkdir -p "$cache_dir"
  command sheldon source > "$sheldon_cache"
fi
source "$sheldon_cache"

# Zenoウィジェット (プラグインロード後に定義される)
if (( ${+functions[zeno-auto-snippet]} )); then
  bindkey ' '    zeno-auto-snippet             # Space: キーワード展開
  bindkey '^m'   zeno-auto-snippet-and-accept-line
  bindkey '^r'   zeno-history-selection        # 履歴のfuzzy検索
  bindkey '^x^s' zeno-insert-snippet           # スニペット一覧から挿入
fi

# ----------------------------------------------------
# 4. mise (Delayed activation)
# ----------------------------------------------------
if type mise &>/dev/null; then
  _mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/mise.zsh"
  if [[ ! -r "$_mise_cache" || "$(command -v mise)" -nt "$_mise_cache" ]]; then
    mise activate zsh > "$_mise_cache"
    mise activate --shims >> "$_mise_cache"
  fi
  zsh-defer source "$_mise_cache"
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

# History. Migrate the legacy in-repository history once without deleting it.
HISTFILE="$_zsh_state_dir/history"
if [[ ! -e "$HISTFILE" && -r "$ZDOTDIR/.zsh_history" ]]; then
  cp -p "$ZDOTDIR/.zsh_history" "$HISTFILE" 2>/dev/null
fi
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
  fi
  source "$_zoxide_cache"
fi

# ----------------------------------------------------
# 7. Starship Prompt (Must be after other tools)
# ----------------------------------------------------
if type starship &>/dev/null; then
  _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship.zsh"
  _starship_config="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
  if [[ ! -r "$_starship_cache" || "$_starship_config" -nt "$_starship_cache" || "$(command -v starship)" -nt "$_starship_cache" ]]; then
    starship init zsh > "$_starship_cache"
  fi
  source "$_starship_cache"
fi

# ----------------------------------------------------
# 8. WezTerm Shell Integration & Semantic Jump [B-5 link]
# ----------------------------------------------------
# WezTerm のシェル統合スクリプトを読み込み、ジャンプ機能を有効にする
if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
  # zsh-defer で遅延読み込みして起動速度を優先
  zsh-defer source "$HOME/.config/zsh/rc/pluginconfig/wezterm.zsh"
  zsh-defer source "$HOME/.config/zsh/rc/pluginconfig/fzf_tab.zsh"
fi

# ----------------------------------------------------
# 10. Simple completion
# ----------------------------------------------------
zstyle ':completion:*' matcher-list "" 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'
zstyle ':completion:*' format '%B%F{blue}%d%f%b'
zstyle ':completion:*' group-name ""
zstyle ':completion:*:default' menu select=2
autoload -Uz compinit
# dump が24時間以内なら compaudit (権限チェック、約18ms) を省く。古ければ通常どおり作り直す
_zcompdump="$_zsh_cache_dir/zcompdump-$ZSH_VERSION"
_zcompdump_fresh=( $_zcompdump(N.mh-24) )
if (( ${#_zcompdump_fresh} )); then
  compinit -C -d "$_zcompdump"
else
  compinit -d "$_zcompdump"
fi
unset _zcompdump _zcompdump_fresh

# ----------------------------------------------------
# 10.5. Modern shell tools (compinit / zeno の後に読む)
# ----------------------------------------------------
source "$ZDOTDIR/rc/pluginconfig/carapace.zsh"
source "$ZDOTDIR/rc/pluginconfig/television.zsh"
source "$ZDOTDIR/rc/pluginconfig/atuin.zsh"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ----------------------------------------------------
# 11. Startup Screen (fastfetch)
# ----------------------------------------------------
if [[ "$TERM_PROGRAM" == "WezTerm" ]] && (( $+commands[fastfetch] )); then
  _fastfetch_stamp="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-fastfetch-${UID}-${PPID}"
  if [[ ! -e "$_fastfetch_stamp" ]]; then
    : > "$_fastfetch_stamp"
    fastfetch
    # dotfiles の機能を少しずつ思い出すための tip を1件 (tips/tips.tsv)
    "$HOME/dotfiles/scripts/dotfiles-tip"
  fi
fi
