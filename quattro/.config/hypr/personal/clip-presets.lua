-- 移植元: hypr/.config/hypr/clip-presets.conf
-- SUPER+V の履歴 (cliphist) とは別枠。処理は ~/dotfiles/scripts/clip-presets
-- 中身は git 管理外の ~/.local/share/clip-presets/ に保存される

o.bind("SUPER + ALT + V", "Clipboard presets", "~/dotfiles/scripts/clip-presets")
o.bind("SUPER + ALT + C", "Save clipboard as preset", "~/dotfiles/scripts/clip-presets save")
o.bind("SUPER + ALT + SHIFT + C", "Delete clipboard preset", "~/dotfiles/scripts/clip-presets delete")
