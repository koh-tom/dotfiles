-- Workspace Overview (Mac の Mission Control 風)。本体は Omarchy shell のプラグイン
--   quattro/.config/omarchy/plugins/dotfiles.overview/
-- Mac と同じく 3本指の上スワイプでも開く (左右スワイプはワークスペース切り替えのまま)。
local toggle = "omarchy-shell shell toggle dotfiles.overview"

o.bind("SUPER + CTRL + UP", "Workspace overview", { panel = "dotfiles.overview" })

hl.gesture({
  fingers = 3,
  direction = "up",
  action = function() hl.dispatch(hl.dsp.exec_cmd(toggle)) end,
})
