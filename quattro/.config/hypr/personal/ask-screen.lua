-- 画面の一部を Claude に聞く (scripts/ask-screen)。範囲 → 質問 → 答えを中央の浮いた窓に出す
o.bind("SUPER + ALT + A", "Ask Claude about screen region", "$HOME/dotfiles/scripts/ask-screen")
hl.window_rule({
  name = "ask-screen",
  match = { class = "org.omarchy.ask-screen" },
  float = true,
  size = { "(monitor_w*0.5)", "(monitor_h*0.6)" },
  move = { "(monitor_w*0.25)", "(monitor_h*0.2)" },
})
