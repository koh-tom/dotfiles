local wezterm = require("wezterm")
local cheatbar = require("modules.cheatbar")
local module = {}

-- 背景の透過度。以前は フォーカス時 0.94 / 非フォーカス時 0.82 で切り替えていたが、
-- ワークスペース移動の瞬間に見える 0.82 (壁紙がやや透ける明るさ) を常用にした。
-- 両方を同じ値にしているので、フォーカスが移るときのチラつきも出ない。
-- 非フォーカス時だけ変えたくなったら UNFOCUSED を下げる。
module.FOCUSED = 0.82
module.UNFOCUSED = 0.82

function module.apply_to_config(config)
  wezterm.on("window-focus-changed", function(window, pane)
    -- config.background (cheatbar) 使用中は window_background_opacity が効かないので、
    -- 背景レイヤーの透過度として反映する
    cheatbar.refresh(window, { opacity = window:is_focused() and module.FOCUSED or module.UNFOCUSED })
  end)
end

return module
