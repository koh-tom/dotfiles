# --- atuin: シェル履歴DB ---
# https://docs.atuin.sh/
# Ctrl+R で全画面の履歴検索 (ディレクトリ/ホスト/セッション単位の絞り込み、終了コード・実行時間付き)。
# 上矢印は従来のzsh履歴のまま (--disable-up-arrow)。zenoの履歴検索は Ctrl+X Ctrl+R に退避。
(( $+commands[atuin] )) || return

_atuin_cache="${XDG_CACHE_HOME:-$HOME/.cache}/atuin.zsh"
if [[ ! -r "$_atuin_cache" || "$(command -v atuin)" -nt "$_atuin_cache" ]]; then
  atuin init zsh --disable-up-arrow > "$_atuin_cache"
fi
# atuin の初期化はシェルごとに `atuin uuid` を起動する (約14ms)。セッションIDは一意なら何でもよいので、
# カーネルの乱数 UUID をファイル読み込みだけで先に入れておく (fork なし)
if [[ -z "${ATUIN_SESSION:-}" || "${ATUIN_SHLVL:-}" != "$SHLVL" ]] && [[ -r /proc/sys/kernel/random/uuid ]]; then
  export ATUIN_SESSION="$(</proc/sys/kernel/random/uuid)"
  export ATUIN_SHLVL=$SHLVL
fi
source "$_atuin_cache"

if (( ${+widgets[zeno-history-selection]} )); then
  bindkey '^x^r' zeno-history-selection
fi
