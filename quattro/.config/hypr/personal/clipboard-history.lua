-- 移植元: ~/.config/hypr/hyprland.conf 末尾の直書き3行
--   exec-once = wl-paste --type text --watch cliphist store
--   exec-once = wl-paste --type image --watch cliphist store
--   bindd = SUPER, V, Clipboard, exec, cliphist list | walker --dmenu | cliphist decode | wl-copy
--
-- 注意: Quattro では Walker が廃止される (Quickshell に統合)。walker が無い環境では
-- SUPER+V の後段が失敗するため、walker が無ければ Quattro 標準のクリップボード
-- パネル (omarchy.clipboard) を開く。walker がある間は現状と同一コマンド。
-- .conf と同じく既定の SUPER+V (Universal paste) には追加する形 (置換しない)。

o.exec_on_start("wl-paste --type text --watch cliphist store")
o.exec_on_start("wl-paste --type image --watch cliphist store")

if o.cmd_present("walker") then
  o.bind("SUPER + V", "Clipboard", "cliphist list | walker --dmenu | cliphist decode | wl-copy")
else
  o.bind("SUPER + V", "Clipboard", { panel = "omarchy.clipboard" })
end
