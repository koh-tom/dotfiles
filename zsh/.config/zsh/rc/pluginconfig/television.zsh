# --- television (tv): 高速fuzzyランチャー ---
# https://alexpasmantier.github.io/television/
# Ctrl+T: 入力中のコマンドから文脈を推測してチャンネルを開く (cd→ディレクトリ, git checkout→ブランチ等)。
# tv 標準の Ctrl+R (履歴) は atuin に任せるため外す。単体起動は `tv` / `tv files` / `tv git-log` など。
(( $+commands[tv] )) || return

_tv_cache="${XDG_CACHE_HOME:-$HOME/.cache}/television.zsh"
if [[ ! -r "$_tv_cache" || "$(command -v tv)" -nt "$_tv_cache" ]]; then
  tv init zsh | sed "/bindkey '^R'/d" > "$_tv_cache"
fi
source "$_tv_cache"
