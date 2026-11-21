-- 朝のブリーフィング (scripts/briefing)。その日最初のログインで自動で出る。SUPER+ALT+B でいつでも
-- 画面中央に浮いた窓で開く
o.bind("SUPER + ALT + B", "Morning briefing", "$HOME/dotfiles/scripts/briefing")
hl.window_rule({
  name = "dotfiles-briefing",
  match = { class = "org.omarchy.dotfiles-briefing" },
  float = true,
  size = { "(monitor_w*0.5)", "(monitor_h*0.7)" },
  move = { "(monitor_w*0.25)", "(monitor_h*0.15)" },
})
