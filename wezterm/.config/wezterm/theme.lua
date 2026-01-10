local module = {}

local theme = {
  color_scheme = "Solarized Dark Higher Contrast",

  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",

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
    background = "#1e1a2e",

    tab_bar = {
      background = "none",
      inactive_tab_edge = "none",
    },

    cursor_bg = "#b4a7d6",
    cursor_fg = "#1e1a2e",
    cursor_border = "#b4a7d6",

    selection_bg = "#d4c5b0",
    selection_fg = "#1e1a2e",

    ansi = {
      "#2a2340",
      "#c27878",
      "#a0b88c",
      "#d4a76a",
      "#7a9ec2",
      "#b4a7d6",
      "#8b9ba8",
      "#d4c5b0",
    },

    brights = {
      "#5c5470",
      "#d98e8e",
      "#b5cfa0",
      "#e0be82",
      "#92b4d4",
      "#c4b5e3",
      "#a0b0bc",
      "#e8d8c4",
    },
  },
}

function module.apply_to_config(config)
  for k, v in pairs(theme) do
    config[k] = v
  end
end

return module
