local wezterm = require("wezterm")
local module = {}

local appearance = {
  -- カラースキーム（既存のSolarizedを流用）
  color_scheme = "Solarized Dark Higher Contrast",

  -- ウィンドウ装飾 (RESIZEのみでタイトルバーを消す)
  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",

  -- Pane (非アクティブを少し暗く)
  inactive_pane_hsb = {
    hue = 0.9,
    saturation = 0.9,
    brightness = 1.0,
  },

  -- Tab
  show_tabs_in_tab_bar = true,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = true,
  show_new_tab_button_in_tab_bar = false,
  -- show_close_tab_button_in_tabs = false, -- エラー回避のためコメントアウト
  tab_max_width = 30,
  use_fancy_tab_bar = true,

  -- 透明設定 (Fancy Tab Bar使用時の透過設定)
  window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
  },

  colors = {
    -- 既存の独自背景色を尊重
    background = "#1e1a2e",

    tab_bar = {
      background = "none",
      inactive_tab_edge = "none",
    },

    -- カーソルと選択色
    cursor_bg = "#b4a7d6",
    cursor_fg = "#1e1a2e",
    cursor_border = "#b4a7d6",
    selection_bg = "#d4c5b0",
    selection_fg = "#1e1a2e",

    -- 既存のANSIカラー定義を維持
    ansi = {
      "#2a2340", "#c27878", "#a0b88c", "#d4a76a",
      "#7a9ec2", "#b4a7d6", "#8b9ba8", "#d4c5b0",
    },
    brights = {
      "#5c5470", "#d98e8e", "#b5cfa0", "#e0be82",
      "#92b4d4", "#c4b5e3", "#a0b0bc", "#e8d8c4",
    },
  },
}

function module.apply_to_config(config)
  for k, v in pairs(appearance) do
    config[k] = v
  end
end

return module
