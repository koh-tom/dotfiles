# --- atuin: シェル履歴DB ---
# https://docs.atuin.sh/
# Ctrl+R で全画面の履歴検索 (ディレクトリ/ホスト/セッション単位の絞り込み、終了コード・実行時間付き)。
# 上矢印は従来のzsh履歴のまま (--disable-up-arrow)。zenoの履歴検索は Ctrl+X Ctrl+R に退避。
(( $+commands[atuin] )) || return

_atuin_cache="${XDG_CACHE_HOME:-$HOME/.cache}/atuin.zsh"
if [[ ! -r "$_atuin_cache" || "$(command -v atuin)" -nt "$_atuin_cache" ]]; then
  atuin init zsh --disable-up-arrow > "$_atuin_cache"
fi
source "$_atuin_cache"

if (( ${+widgets[zeno-history-selection]} )); then
  bindkey '^x^r' zeno-history-selection
fi
