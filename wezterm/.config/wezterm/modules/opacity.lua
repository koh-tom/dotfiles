local wezterm = require("wezterm")
local cheatbar = require("modules.cheatbar")
local module = {}

function module.apply_to_config(config)
  wezterm.on("window-focus-changed", function(window, pane)
    -- config.background (cheatbar) 使用中は window_background_opacity が効かないので、
    -- 背景レイヤーの透過度として反映する
    cheatbar.refresh(window, { opacity = window:is_focused() and 0.94 or 0.82 })
  end)
end

return module
