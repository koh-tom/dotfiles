-- 移植元: hypr/.config/hypr/dropdown.conf
-- SUPER+` でトグル。中身は ~/dotfiles/scripts/wezterm-dropdown
--
-- Quattro 既定は SUPER+grave に「Quake console」(special:qconsole) を割り当てる。
-- 3.8.1 ではこのキーはドロップダウン専用だったので、現状維持のため o.rebind で置き換える。
-- (SUPER+SHIFT+grave の「Quake console へ移動」は Quattro の新規既定なので残る)

o.rebind("SUPER + grave", "Dropdown terminal", "~/dotfiles/scripts/wezterm-dropdown")

hl.window_rule({
  name = "wezterm-dropdown",
  match = { class = "org.wezfurlong.wezterm.dropdown" },
  workspace = "special:dropdown",
  float = true,
  size = { "(monitor_w*0.8)", "(monitor_h*0.5)" },
  move = { "(monitor_w*0.1)", "(monitor_h*0.04)" },
  animation = "slide top",
})
