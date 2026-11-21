-- dotfiles のマニュアル (scripts/dotfiles-manual)。Omarchy 標準のキー一覧 SUPER+K の隣に置く。
-- 画面中央に浮いた窓で開く
o.bind("SUPER + SHIFT + K", "Dotfiles manual", "$HOME/dotfiles/scripts/dotfiles-manual")
hl.window_rule({
  name = "dotfiles-manual",
  match = { class = "org.omarchy.dotfiles-manual" },
  float = true,
  size = { "(monitor_w*0.6)", "(monitor_h*0.8)" },
  move = { "(monitor_w*0.2)", "(monitor_h*0.1)" },
})
