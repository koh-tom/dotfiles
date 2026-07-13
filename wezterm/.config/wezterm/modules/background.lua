local wezterm = require("wezterm")
local module = {}

-- LEADER + i で、Omarchyの現在壁紙をWezTermの背景として薄く敷くトグル。
-- ~/.config/omarchy/current/background はOmarchyが張る現在壁紙へのsymlink。

function module.apply_to_config(config)
  table.insert(config.keys, {
    key = "i",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, _)
      local overrides = window:get_config_overrides() or {}

      if overrides.window_background_image then
        overrides.window_background_image = nil
        overrides.window_background_image_hsb = nil
        window:toast_notification("Background", "Wallpaper off", nil, 1500)
      else
        local bg = wezterm.home_dir .. "/.config/omarchy/current/background"
        local f = io.open(bg, "rb")
        if not f then
          window:toast_notification("Background", "No Omarchy background found", nil, 2000)
          return
        end
        f:close()

        overrides.window_background_image = bg
        -- 文字が読める明るさまで落とす
        overrides.window_background_image_hsb = { brightness = 0.06, saturation = 0.9 }
        window:toast_notification("Background", "Wallpaper on", nil, 1500)
      end

      window:set_config_overrides(overrides)
    end),
  })
end

return module
