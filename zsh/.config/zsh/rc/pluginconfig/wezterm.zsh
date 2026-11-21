# WezTerm Shell Integration for Zsh
#
# 本体は wezterm パッケージ同梱の /etc/profile.d/wezterm.sh (OSC 7 で cwd、OSC 133 でプロンプト境界、
# WEZTERM_PROG などの user var を送る)。.zshenv の no_global_rcs で /etc/profile.d は自動では読まれないので、
# WezTerm の中でだけ明示的に読む。
# (以前は `wezterm shell-integration` を呼んでいたが、そのサブコマンドは存在せず、zsh-defer がエラーを
#  握りつぶしていたため統合が丸ごと効いていなかった)
if [[ -n "$WEZTERM_PANE" && -r /etc/profile.d/wezterm.sh ]]; then
  source /etc/profile.d/wezterm.sh
fi

# 以下は dotfiles 独自の user var (プロンプト境界は上の wezterm.sh が出す)
function wezterm_precmd() {
  # Nix devshell名をSetUserVarで通知 (statusbar.luaが❄表示に使う)
  # base64のfork代を値が変わった時だけ払う
  local nix_name=""
  if [[ -n "$IN_NIX_SHELL" ]]; then
    nix_name="${DEVSHELL_NAME:-${name:-devshell}}"
  fi
  if [[ "$nix_name" != "${_wezterm_nix_last-__unset__}" ]]; then
    typeset -g _wezterm_nix_last="$nix_name"
    printf "\033]1337;SetUserVar=nix_shell=%s\007" "$(print -rn -- "$nix_name" | base64)"
  fi

  # push認証を常時通知 (personal/lab)。ghpushがGH_PUSH_AS=labをexportする
  local push_id="personal"
  [[ "$GH_PUSH_AS" == "lab" ]] && push_id="lab"
  if [[ "$push_id" != "${_wezterm_push_last-__unset__}" ]]; then
    typeset -g _wezterm_push_last="$push_id"
    printf "\033]1337;SetUserVar=gh_push=%s\007" "$(print -rn -- "$push_id" | base64)"
  fi
}

# zsh のフックに登録
add-zsh-hook precmd wezterm_precmd
