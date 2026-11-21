local wezterm = require("wezterm")
local module = {}

local appearance = {
  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",

  audible_bell = "Disabled",
  visual_bell = {
    fade_in_function = "EaseIn",
    fade_in_duration_ms = 150,
    fade_out_function = "EaseOut",
    fade_out_duration_ms = 150,
  },

  -- 分割時にどのペインを操作中か一目で分かるよう、非アクティブ側をはっきり暗くする
  inactive_pane_hsb = {
    saturation = 0.6,
    brightness = 0.45,
  },

  show_tabs_in_tab_bar = true,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = true,
  show_new_tab_button_in_tab_bar = false,
  tab_max_width = 30,
  -- retroタブバーは端末本体のフォントで描画されるため、Ctrl+-等のフォントサイズ変更に追従する
  -- (fancyはwindow_frame.font_size固定で追従しない)。右ステータスとも重ならない
  use_fancy_tab_bar = false,

  window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
  },

  colors = {
    tab_bar = {
      background = "none",
      inactive_tab_edge = "none",
    },
    -- 背景色・ANSI・選択色は固定しない (omarchy_theme.lua がテーマの colors.toml から入れる)
  },
}

function module.apply_to_config(config)
  for k, v in pairs(appearance) do
    config[k] = v
  end
end

return module
