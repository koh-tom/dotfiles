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
}

function wezterm_preexec() {
  # OSC 133; C: コマンド開始、プロンプト終了
  printf "\033]133;C\007"
}

# zsh のフックに登録
add-zsh-hook precmd wezterm_precmd
add-zsh-hook preexec wezterm_preexec
