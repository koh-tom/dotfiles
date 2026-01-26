local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

local function translate_selection()
  return wezterm.action_callback(function(window, pane)
    local text = window:get_selection_text_for_pane(pane)
    if not text or text == "" then return end

    -- plamo-translate-cli 等の外部ツールを想定（なければ echo で表示）
    local command = string.format("echo %s | plamo-translate --to Japanese 2>/dev/null || echo 'Translation tool not found. Selected text: %s' | less -R", 
      "'" .. text:gsub("'", "'\\''") .. "'", "'" .. text:gsub("'", "'\\''") .. "'")

    local new_pane = pane:split({
      direction = "Bottom",
      size = 1.0,
      args = { os.getenv("SHELL"), "-lc", command },
    })
    window:perform_action(act.TogglePaneZoomState, new_pane)
  end)
end

function module.apply_to_config(config)
  -- copy_mode 中に Shift+Y で実行
  if config.key_tables and config.key_tables.copy_mode then
    table.insert(config.key_tables.copy_mode, { key = "Y", mods = "SHIFT", action = translate_selection() })
  end
end

return module
