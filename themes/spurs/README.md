# Spurs

A navy, lilywhite, and matchday-yellow Omarchy theme for this dotfiles setup.

`colors.toml` が唯一のソース。それ以外のテーマファイル (btop / neovim /
hyprland / hyprlock / mako / swayosd / waybar / wofi / alacritty / preview.png)
は `tools/build_theme.py` が生成するので手で編集しない。

```bash
mise run build-theme     # colors.tomlから再生成
mise run install-spurs   # 生成込みで ~/.config/omarchy/themes/spurs へ配置
omarchy theme set Spurs
```
