local wezterm = require("wezterm")
local module = {}

-- =============================================================================
-- 定数 & アイコン
-- =============================================================================

local WORKSPACE_COLORS = {
  default = "#b4a7d6",
  copy_mode = "#ffd700",
  setting_mode = "#39FF14",
}

local ICONS = {
  git = wezterm.nerdfonts.md_git,
  time = wezterm.nerdfonts.md_clock_outline,
  bat_charging = wezterm.nerdfonts.md_battery_charging,
  bat_discharging = wezterm.nerdfonts.md_battery,
}

-- キャッシュ用変数
local last_color = nil
local last_cwd = nil
local last_git_branch = ""

-- =============================================================================
-- ヘルパー関数
-- =============================================================================

-- Git ブランチ名を取得
local function get_git_branch(pane)
  local cwd_url = pane:get_current_working_dir()
  local cwd = cwd_url and cwd_url.file_path or ""
  
  if cwd == last_cwd then return last_git_branch end
  last_cwd = cwd

  local success, stdout, _ = wezterm.run_child_process({ "git", "-C", cwd, "branch", "--show-current" })
  if success then
    last_git_branch = stdout:gsub("\n", "")
  else
    last_git_branch = ""
  end
  return last_git_branch
end

-- バッテリー情報を取得
local function get_battery_status()
  local bat = ""
  for _, b in ipairs(wezterm.battery_info()) do
    local icon = b.state == "Charging" and ICONS.bat_charging or ICONS.bat_discharging
    bat = string.format("%s %.0f%% ", icon, b.state_of_charge * 100)
  end
  return bat
end

-- =============================================================================
-- メイン処理
-- =============================================================================

function module.apply_to_config(_)
  wezterm.on("update-status", function(window, pane)
    local workspace = window:active_workspace()
    local key_table = window:active_key_table()
    local color = WORKSPACE_COLORS[key_table] or WORKSPACE_COLORS.default

    -- 左側: ワークスペース表示
    window:set_left_status(wezterm.format({
      { Background = { Color = "transparent" } },
      { Foreground = { Color = color } },
      { Text = "  " .. workspace .. "  " },
    }))

    -- 右側: Git, 時刻, バッテリー
    local branch = get_git_branch(pane)
    local time = wezterm.strftime("%H:%M")
    local bat = get_battery_status()
    
    local right_status = {}
    
    -- Git ブランチがあれば表示
    if branch ~= "" then
      table.insert(right_status, { Foreground = { Color = "#a0b88c" } })
      table.insert(right_status, { Text = ICONS.git .. " " .. branch .. "  " })
    end
    
    -- 時刻
    table.insert(right_status, { Foreground = { Color = "#8b9ba8" } })
    table.insert(right_status, { Text = ICONS.time .. " " .. time .. "  " })
    
    -- バッテリー
    if bat ~= "" then
      table.insert(right_status, { Foreground = { Color = "#d4a76a" } })
      table.insert(right_status, { Text = bat })
    end

    window:set_right_status(wezterm.format(right_status))

    -- カーソル色変更
    if last_color ~= color then
      last_color = color
      pane:inject_output("\x1b]12;" .. color .. "\x1b\\")
    end
  end)
end

return module
