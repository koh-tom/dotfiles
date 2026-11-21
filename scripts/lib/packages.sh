# shellcheck shell=bash disable=SC2034  # DOTFILES_* は source した側で使う
# Stow パッケージ一覧の唯一の定義。apply-dotfiles / dotfiles-doctor / CI (.github/workflows/check.yml)
# がここを source して同じ一覧を使う。実行用ではない (source 専用)。
#
#   source scripts/lib/packages.sh
#   dotfiles_select_packages [quattro|omarchy3|tools]   # 省略時は実機から判定
#   stow -n -v "${DOTFILES_STOW_OPTS[@]}" "${DOTFILES_PACKAGES[@]}"

# Omarchy 4 (Quattro) 判定: Lua 構成の bootstrap.lua があるか
dotfiles_is_quattro() { [[ -e /usr/share/omarchy/default/hypr/bootstrap.lua ]]; }

# 実機のプラットフォーム: quattro (Omarchy 4) / omarchy3 (Omarchy 3.x) / tools (Ubuntu 等)
dotfiles_platform() {
  if dotfiles_is_quattro; then
    echo quattro
  elif command -v omarchy >/dev/null 2>&1; then
    echo omarchy3
  else
    echo tools
  fi
}

# ツール群 (Ubuntu/Debian にも移植できる層。apply-dotfiles-ubuntu と同じ)
DOTFILES_TOOL_PACKAGES=(atuin git mise starship wezterm zsh fastfetch ssh nvim)
# Omarchy (3.x / 4 共通) で足すもの
DOTFILES_OMARCHY_PACKAGES=(chrome hypr omarchy xdg-terminal)
# Omarchy 3.x だけ (Quattro のバーは omarchy-shell なので Waybar は使わない)
DOTFILES_OMARCHY3_PACKAGES=(waybar)
# Omarchy 4 (Quattro) だけ (Hyprland Lua 構成と omarchy-shell 設定)
DOTFILES_QUATTRO_PACKAGES=(quattro)

# Quattro では張らないファイル (stow --ignore は末尾一致の正規表現なので / から書く)
#   hyprland-config.conf: .conf 構成を強制する HYPRLAND_CONFIG (hypr パッケージ)
#   extensions/menu.sh  : 3.x のメニュー拡張 (Quattro は quattro の omarchy-menu.jsonc)
DOTFILES_QUATTRO_IGNORES=('/environment\.d/hyprland-config\.conf' '/extensions/menu\.sh')

dotfiles_select_packages() {
  local platform=${1:-$(dotfiles_platform)}
  local pattern
  DOTFILES_STOW_OPTS=()
  case $platform in
    quattro)
      DOTFILES_PACKAGES=("${DOTFILES_TOOL_PACKAGES[@]}" "${DOTFILES_OMARCHY_PACKAGES[@]}" "${DOTFILES_QUATTRO_PACKAGES[@]}")
      for pattern in "${DOTFILES_QUATTRO_IGNORES[@]}"; do
        DOTFILES_STOW_OPTS+=("--ignore=$pattern")
      done
      ;;
    omarchy3)
      DOTFILES_PACKAGES=("${DOTFILES_TOOL_PACKAGES[@]}" "${DOTFILES_OMARCHY_PACKAGES[@]}" "${DOTFILES_OMARCHY3_PACKAGES[@]}")
      ;;
    tools)
      DOTFILES_PACKAGES=("${DOTFILES_TOOL_PACKAGES[@]}")
      ;;
    *)
      printf 'unknown platform: %s (quattro|omarchy3|tools)\n' "$platform" >&2
      return 1
      ;;
  esac
}
