local wezterm = require("wezterm")
local module = {}

function module.apply_to_config(config)
  wezterm.on("window-focus-changed", function(window, pane)
    -- 現在のオーバーライド設定を取得 (存在しなければ空のテーブル)
    local overrides = window:get_config_overrides() or {}
    
    -- 他のモジュールの設定 (color_scheme 等) はそのままに、透過度だけを更新
    if window:is_focused() then
      overrides.window_background_opacity = 0.85
      -- Linux/Ubuntu では Acrylic 効かないためスキップ、または Blur 用
    else
      overrides.window_background_opacity = 0.6
    end
    
    window:set_config_overrides(overrides)
  end)
end

return module
