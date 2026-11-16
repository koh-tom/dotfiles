local wezterm = require("wezterm")
local cheatbar = require("modules.cheatbar")
local module = {}

-- LEADER + i で、Omarchyの現在壁紙をWezTermの背景として薄く敷くトグル。
-- <Omarchy current>/background はOmarchyが張る現在壁紙へのsymlink (場所は omarchy_theme.current_dir)。
-- 背景はcheatbarがレイヤーとして一元管理しているので、そちらに状態を渡す。

function module.apply_to_config(config)
  table.insert(config.keys, {
    key = "i",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, _)
      if cheatbar.wallpaper_enabled(window) then
        cheatbar.refresh(window, { wallpaper = false })
        window:toast_notification("Background", "Wallpaper off", nil, 1500)
        return
      end

      local f = io.open(require("omarchy_theme").current_dir() .. "/background", "rb")
      if not f then
        window:toast_notification("Background", "No Omarchy background found", nil, 2000)
        return
      end
      f:close()

      cheatbar.refresh(window, { wallpaper = true })
      window:toast_notification("Background", "Wallpaper on", nil, 1500)
    end),
  })
end

return module
