# WezTerm Shell Integration for Zsh

# WezTerm のシェル統合スクリプトがあるか確認
# Ubuntu なら通常 ~/.local/share/wezterm/shell-integration/wezterm.sh
# または公式の URL から取得可能だが、OSパッケージに含まれるものを優先

if [[ -z "$WEZTERM_EXECUTABLE" ]]; then
  # 実行ファイルのパスが取れない場合は適当に補完
  WEZTERM_EXECUTABLE=$(which wezterm 2>/dev/null)
fi

if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
  # WezTerm の機能を使用してシェル統合コードを取得
  source <($WEZTERM_EXECUTABLE shell-integration --shell zsh)
fi

# Zsh-specific semantic zone support
# プロンプトの開始と終了を WezTerm に通知するためのフックを設定
# これにより [ と ] のジャンプが 100% 正確に動作するようになる

function wezterm_precmd() {
  # OSC 133; A: プロンプト開始
  printf "\033]133;A\007"

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

function wezterm_preexec() {
  # OSC 133; C: コマンド開始、プロンプト終了
  printf "\033]133;C\007"
}

# zsh のフックに登録
add-zsh-hook precmd wezterm_precmd
add-zsh-hook preexec wezterm_preexec
