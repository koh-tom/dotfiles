local wezterm = require("wezterm")
local module = {}

local appearance = {
  color_scheme = "Solarized Dark Higher Contrast",

  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",

  audible_bell = "Disabled",
  visual_bell = {
    fade_in_function = "EaseIn",
    fade_in_duration_ms = 150,
    fade_out_function = "EaseOut",
    fade_out_duration_ms = 150,
  },

  inactive_pane_hsb = {
    hue = 0.9,
    saturation = 0.9,
    brightness = 1.0,
  },

  show_tabs_in_tab_bar = true,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = true,
  show_new_tab_button_in_tab_bar = false,
  tab_max_width = 30,
  use_fancy_tab_bar = true,

  window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
  },

  colors = {
    tab_bar = {
      background = "none",
      inactive_tab_edge = "none",
    },
    -- 背景色や ANSI カラーを固定しないことで、カラースキームの切替を有効化
    selection_bg = "#d4c5b0",
    selection_fg = "#1e1a2e",
  },
}

function module.apply_to_config(config)
  for k, v in pairs(appearance) do
    config[k] = v
  end
end

return module
