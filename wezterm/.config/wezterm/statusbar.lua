local wezterm = require("wezterm")
local module = {}

-- =============================================================================
-- 定数 & アイコン
-- =============================================================================

local WORKSPACE_COLORS = {
  default = "#cba6f7", -- Mauve
  copy_mode = "#f9e2af", -- Yellow
  setting_mode = "#a6e3a1", -- Green
}

local ICONS = {
  git = wezterm.nerdfonts.md_git,
  time = wezterm.nerdfonts.md_clock_outline,
  bat_charging = wezterm.nerdfonts.md_battery_charging,
  bat_discharging = wezterm.nerdfonts.md_battery,
  cpu = wezterm.nerdfonts.md_cpu_64_bit,
  mem = wezterm.nerdfonts.md_memory,
  dir = wezterm.nerdfonts.md_folder_open,
  server = wezterm.nerdfonts.md_server,
}

-- キャッシュ用変数
local last_color = nil
local last_cwd = nil
local last_git_branch = ""

-- =============================================================================
-- ヘルパー関数
-- =============================================================================

-- カレントディレクトリを短縮して取得
local function get_short_cwd(pane)
  local cwd_url = pane:get_current_working_dir()
  if not cwd_url then return "" end
  local path = cwd_url.file_path
  local home = wezterm.home_dir
  if path:sub(1, #home) == home then path = "~" .. path:sub(#home + 1) end
  return path
end

-- Git ブランチ名を取得 (キャッシュ対応)
local function get_git_branch(pane)
  local cwd_url = pane:get_current_working_dir()
  local cwd = cwd_url and cwd_url.file_path or ""
  if cwd == last_cwd then return last_git_branch end
  last_cwd = cwd

  local success, stdout, _ = wezterm.run_child_process({ "git", "-C", cwd, "branch", "--show-current" })
  last_git_branch = success and stdout:gsub("\n", "") or ""
  return last_git_branch
end

-- CPU 負荷とメモリ使用率を取得 (Linux 特化)
local function get_sys_info()
  local load = ""
  local mem = ""
  
  -- CPU Load (1分平均)
  local f = io.open("/proc/loadavg", "r")
  if f then
    local content = f:read("*all")
    f:close()
    load = string.format("%s %s ", ICONS.cpu, content:match("^(%d+%.%d+)"))
  end

  -- Memory Usage
  local f_mem = io.open("/proc/meminfo", "r")
  if f_mem then
    local content = f_mem:read("*all")
    f_mem:close()
    local total = tonumber(content:match("MemTotal:%s+(%d+)"))
    local available = tonumber(content:match("MemAvailable:%s+(%d+)"))
    if total and available then
      local used_percent = math.floor((total - available) / total * 100)
      mem = string.format("%s %d%% ", ICONS.mem, used_percent)
    end
  end
  
  return load, mem
end

-- =============================================================================
-- メイン処理
-- =============================================================================

function module.apply_to_config(_)
  wezterm.on("update-status", function(window, pane)
    local workspace = window:active_workspace()
    local key_table = window:active_key_table()
    local color = WORKSPACE_COLORS[key_table] or WORKSPACE_COLORS.default

    -- -------------------------------------------------------------------------
    -- 左側: ワークスペース表示 & LEADER 状態
    -- -------------------------------------------------------------------------
    local leader_text = "  " .. workspace .. "  "
    if window:leader_is_active() then
      color = "#ff757f" -- Hot Pink for Leader
      leader_text = "  󱐋 LEADER  "
    end

    window:set_left_status(wezterm.format({
      { Background = { Color = "transparent" } },
      { Foreground = { Color = color } },
      { Text = leader_text },
    }))

    -- -------------------------------------------------------------------------
    -- 右側: プログレッシブ・ステータス
    -- -------------------------------------------------------------------------
    local right_status = {}
    local branch = get_git_branch(pane)
    local cwd = get_short_cwd(pane)
    local load, mem = get_sys_info()
    local time = wezterm.strftime("%H:%M")
    
    -- ホスト名 (SSH判定)
    local user_vars = pane:get_user_vars()
    if user_vars.ssh_host then
      table.insert(right_status, { Foreground = { Color = "#ffd700" } })
      table.insert(right_status, { Text = ICONS.server .. " " .. user_vars.ssh_host .. " │ " })
    end

    -- CWD (短縮パス)
    table.insert(right_status, { Foreground = { Color = "#a6adc8" } }) -- Subtext0
    table.insert(right_status, { Text = ICONS.dir .. " " .. cwd .. "  " })
    
    -- Git
    if branch ~= "" then
      table.insert(right_status, { Foreground = { Color = "#a6e3a1" } }) -- Green
      table.insert(right_status, { Text = "│ " .. ICONS.git .. " " .. branch .. " " })
    end
    
    -- リソース (CPU/メモリ)
    table.insert(right_status, { Foreground = { Color = "#89dceb" } }) -- Sky
    table.insert(right_status, { Text = "│ " .. load .. mem })
    
    -- 時刻
    table.insert(right_status, { Foreground = { Color = "#b4befe" } }) -- Lavender
    table.insert(right_status, { Text = "│ " .. ICONS.time .. " " .. time .. "  " })
    
    -- バッテリー (あれば)
    local bat_info = wezterm.battery_info()
    if #bat_info > 0 then
      local b = bat_info[1]
      local bat_icon = b.state == "Charging" and ICONS.bat_charging or ICONS.bat_discharging
      table.insert(right_status, { Foreground = { Color = "#fab387" } }) -- Peach
      table.insert(right_status, { Text = string.format("│ %s %.0f%% ", bat_icon, b.state_of_charge * 100) })
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
