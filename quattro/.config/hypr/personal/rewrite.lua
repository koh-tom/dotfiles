-- 選んだ文を Claude に校正・書き換えしてもらう (scripts/rewrite)。
-- 文を選ぶ → 何をする → 状況 → 追加の指示 → 結果をクリップボードへ、前後の文と変更点を中央の浮いた窓に出す
-- SHIFT 付きは終わったら元のウィンドウに貼り付けて選択部分を置き換える (窓は通知の「詳しく」から)
o.bind("SUPER + ALT + R", "Rewrite selected text with Claude", "$HOME/dotfiles/scripts/rewrite")
o.bind("SUPER + ALT + SHIFT + R", "Rewrite selected text with Claude and paste", "$HOME/dotfiles/scripts/rewrite --paste")
hl.window_rule({
  name = "rewrite",
  match = { class = "org.omarchy.rewrite" },
  float = true,
  size = { "(monitor_w*0.5)", "(monitor_h*0.7)" },
  move = { "(monitor_w*0.25)", "(monitor_h*0.15)" },
})
