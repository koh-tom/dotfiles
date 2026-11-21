# shellcheck shell=bash
# Omarchy 4 (Quattro) が生成する既定ファイルの退避。migrate-to-quattro post と
# bootstrap-omarchy (新規 Quattro 機) が source して使う。実行用ではない (source 専用)。
#
# これらは Omarchy が通常ファイルとして置くため、そのままだと quattro パッケージの
# stow が衝突する。*.quattro-default.<stamp> へ改名して dotfiles 版に差し替える。

# ~/.config からの相対パス
QUATTRO_DEFAULT_FILES=(
  hypr/hyprland.lua
  hypr/bindings.lua
  hypr/input.lua
  hypr/looknfeel.lua
  hypr/autostart.lua
  omarchy/shell.json
  omarchy/extensions/omarchy-menu.jsonc
)

# backup_quattro_defaults <stamp> [runner...]
#   runner を渡すとコマンドの前に付けて実行する (例: migrate-to-quattro の dry-run 用 run)。
#   既にリンク (dotfiles 版) になっているものは触らない。
backup_quattro_defaults() {
  local stamp=$1
  shift
  local f target
  for f in "${QUATTRO_DEFAULT_FILES[@]}"; do
    target="$HOME/.config/$f"
    if [[ -f $target && ! -L $target ]]; then
      if (($#)); then
        "$@" mv "$target" "$target.quattro-default.$stamp"
      else
        mv "$target" "$target.quattro-default.$stamp"
        printf 'Backed up %s\n' "$target"
      fi
    fi
  done
}
