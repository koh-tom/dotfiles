-- 移植元: ~/.config/hypr/input.conf (コメントアウトされていた項目は移植しない)

hl.config({
  input = {
    kb_layout = "jp",
    kb_options = "compose:caps",
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,
    touchpad = {
      scroll_factor = 0.4,
    },
  },
})

-- Scroll nicely in the terminal
--   windowrule = match:class (Alacritty|kitty|foot), scroll_touchpad 1.5
--   windowrule = match:class com.mitchellh.ghostty, scroll_touchpad 0.2
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
