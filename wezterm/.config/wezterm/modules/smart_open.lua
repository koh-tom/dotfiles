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
        "https?://[\\w\\-._~:/?#@!$&'()*+,;=%]+",   -- URL
        "(?:~|/)[/\\w\\-.@~]+:\\d+",                 -- Path:Line (nvimで該当行へ)
        "(?:~|/)[/\\w\\-.@~]+",                      -- Path
        "(?<![\\w./~-])[A-Za-z0-9_-]+/[A-Za-z0-9._-]+(?![\\w./~-])", -- owner/repo (GitHub)
        "[0-9a-f]{7,40}",                            -- Git Hash
      },
      action = wezterm.action_callback(function(window, pane)
        local choices = window:get_selection_text_for_pane(pane)
        window:perform_action(act.ClearSelection, pane)

        local function open_in_pane(args)
          local new_pane = pane:split({ direction = "Bottom", size = 1.0, args = args })
          window:perform_action(act.TogglePaneZoomState, new_pane)
        end

        -- 検知したテキストの種類に合わせて動作を変える
        local path_line, line_no = choices:match("^([~/][^:]*):(%d+)$")
        if choices:match("^http") then
          -- URL ならブラウザで開く
          wezterm.open_with(choices)
        elseif path_line then
          -- path:line なら Neovim で該当行を開く
          open_in_pane({ "nvim", "+" .. line_no, "--", path_line:gsub("^~", wezterm.home_dir) })
        elseif choices:match("^/") or choices:match("^~") then
          -- パスなら別ペインで Neovim で開く
          open_in_pane({ "nvim", "--", choices:gsub("^~", wezterm.home_dir) })
        elseif choices:match("^[%w_%-]+/[%w_%.%-]+$") and not choices:match("^%d+/%d+$") then
          -- owner/repo なら GitHub で開く
          wezterm.open_with("https://github.com/" .. choices)
        elseif choices:match("^[0-9a-f]+$") and #choices >= 7 then
          -- Git Hash ならシェルを介さず git show を表示
          open_in_pane({ "git", "-c", "color.ui=always", "show", "--no-ext-diff", choices })
        end
      end),
    }),
  })
end

return module
