# --- carapace: 1000+コマンドの補完 ---
# https://carapace.sh/
# zsh標準/zsh-completions に補完が無いコマンドだけ carapace に任せる (フォールバック方式)。
# git等の既存補完とfzf-tabのプレビュー設定はそのまま活かす。compinit の後に読むこと。
(( $+commands[carapace] )) || return

_carapace_cache="${XDG_CACHE_HOME:-$HOME/.cache}/carapace.zsh"
if [[ ! -r "$_carapace_cache" || "$(command -v carapace)" -nt "$_carapace_cache" ]]; then
  # 一括 compdef 行を「対象コマンド配列」に置き換えて保存する
  carapace _carapace zsh | sed 's/^compdef _carapace_completer /_carapace_cmds=(/; /^_carapace_cmds=(/ s/$/)/' > "$_carapace_cache"
fi
source "$_carapace_cache"

for _c in $_carapace_cmds; do
  (( $+_comps[$_c] )) || compdef _carapace_completer "$_c"
done
unset _c _carapace_cmds
