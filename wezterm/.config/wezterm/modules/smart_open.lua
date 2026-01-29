local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

function module.apply_to_config(config)
  -- LEADER + o (Open) でスマート選択・起動
  table.insert(config.keys, {
    key = "o",
    mods = "LEADER",
    action = act.QuickSelectArgs({
      label = "Smart Open",
      patterns = {
        "https?://[\\w\\-._~:/?#@!$&'()*+,;=%]+", -- URL
        "(?:~|/)[/\\w\\-.@~]+",                     -- Path
        "[0-9a-f]{7,40}",                          -- Git Hash
      },
      action = wezterm.action_callback(function(window, pane)
        local choices = window:get_selection_text_for_pane(pane)
        window:perform_action(act.ClearSelection, pane)
        
        -- 検知したテキストの種類に合わせて動作を変える
        if choices:match("^http") then
          -- URL ならブラウザで開く
          wezterm.open_with(choices)
        elseif choices:match("^/") or choices:match("^~") then
          -- パスなら別ペインで Neovim で開く
          local new_pane = pane:split({
            direction = "Bottom",
            size = 1.0,
            args = { os.getenv("SHELL"), "-lc", "nvim " .. choices },
          })
          window:perform_action(act.TogglePaneZoomState, new_pane)
        elseif #choices >= 7 then
          -- Git Hash ぽければ git show を表示
          local new_pane = pane:split({
            direction = "Bottom",
            size = 1.0,
            args = { os.getenv("SHELL"), "-lc", "git show " .. choices .. " | less -R" },
          })
          window:perform_action(act.TogglePaneZoomState, new_pane)
        end
      end),
    }),
  })
end

return module
