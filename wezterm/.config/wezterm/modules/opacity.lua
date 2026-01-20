local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

function module.apply_to_config(config)
  -- keymaps.lua で定義した setting_mode にキーを追加
  if config.key_tables and config.key_tables.setting_mode then
    table.insert(config.key_tables.setting_mode, { key = ";", action = act.EmitEvent("increase-opacity") })
    table.insert(config.key_tables.setting_mode, { key = "-", action = act.EmitEvent("decrease-opacity") })
    table.insert(config.key_tables.setting_mode, { key = "0", action = act.EmitEvent("reset-opacity") })
  end
end

local function adjust_opacity(window, delta, config)
  local overrides = window:get_config_overrides() or {}
  local current = overrides.window_background_opacity or config.window_background_opacity or 1.0
  local new_opacity = math.max(0.1, math.min(1.0, current + delta))
  overrides.window_background_opacity = new_opacity
  window:set_config_overrides(overrides)
end

wezterm.on("decrease-opacity", function(window, config) adjust_opacity(window, -0.1, config) end)
wezterm.on("increase-opacity", function(window, config) adjust_opacity(window, 0.1, config) end)
wezterm.on("reset-opacity", function(window, config)
  local overrides = window:get_config_overrides() or {}
  overrides.window_background_opacity = config.window_background_opacity
  window:set_config_overrides(overrides)
end)

-- フォーカス連動ブラー/透明度
wezterm.on("window-focus-changed", function(window, _)
  local overrides = window:get_config_overrides() or {}
  overrides.window_background_opacity = window:is_focused() and 0.9 or 1.0
  window:set_config_overrides(overrides)
end)

return module
