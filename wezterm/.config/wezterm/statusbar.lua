local wezterm = require("wezterm")
local module = {}
local palette = require("omarchy_theme").get_palette()

-- =============================================================================
-- 定数 & アイコン
-- =============================================================================

local WORKSPACE_COLORS = {
  default = palette.accent,
  copy_mode = palette.color3,
  setting_mode = palette.color2,
}

local ICONS = {
  git = wezterm.nerdfonts.md_git,
  dir = wezterm.nerdfonts.md_folder_open,
  server = wezterm.nerdfonts.md_server,
  time = wezterm.nerdfonts.md_clock_outline,
  cpu = wezterm.nerdfonts.md_cpu_64_bit,
  mem = wezterm.nerdfonts.md_memory,
  bat_charging = wezterm.nerdfonts.md_battery_charging,
  bat_discharging = wezterm.nerdfonts.md_battery,
}

-- キャッシュ用変数
local last_color = nil
local git_cache = {}
local GIT_CACHE_TTL = 2

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
  if cwd == "" then return "" end

  local now = os.time()
  local cached = git_cache[cwd]
  if cached and now - cached.updated_at < GIT_CACHE_TTL then
    return cached.branch
  end

  local success, stdout, _ = wezterm.run_child_process({ "git", "-C", cwd, "branch", "--show-current" })
  local branch = success and stdout:gsub("\n", "") or ""
  git_cache[cwd] = { branch = branch, updated_at = now }
  return branch
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
      color = palette.color1
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
    
    -- -------------------------------------------------------------------------
    -- 右側: ガイド表示 (ショートカットヒント)
    -- -------------------------------------------------------------------------
    local hint_text = ""
    local hint_fg = palette.color3

    if window:leader_is_active() then
      hint_text = " [g] Project | [l] Launch | [r/d] Split | [f] Zoom | [z] CopyLast "
    elseif key_table == "setting_mode" then
      hint_text = " [h/j/k/l] Resize | [1-9] Ratio | [q/Esc] Exit "
      hint_fg = palette.color2
    elseif key_table == "copy_mode" then
      hint_text = " [v] Select | [y] Copy | [/] Find | [n/p] Next/Prev | [q] Exit "
      hint_fg = palette.color3
    elseif key_table == "search_mode" then
      hint_text = " [Enter] Case | [Esc] Close "
    end

    if hint_text ~= "" then
      table.insert(right_status, { Foreground = { Color = hint_fg } })
      table.insert(right_status, { Text = "󱊑 " .. hint_text .. " │ " })
    end

    -- ホスト名 (SSH判定)
    local user_vars = pane:get_user_vars()
    if user_vars.ssh_host then
      table.insert(right_status, { Foreground = { Color = palette.color3 } })
      table.insert(right_status, { Text = ICONS.server .. " " .. user_vars.ssh_host .. " │ " })
    end

    -- CWD (短縮パス)
    table.insert(right_status, { Foreground = { Color = palette.color7 } })
    table.insert(right_status, { Text = ICONS.dir .. " " .. cwd .. "  " })
    
    -- Git
    if branch ~= "" then
      table.insert(right_status, { Foreground = { Color = palette.color2 } })
      table.insert(right_status, { Text = "│ " .. ICONS.git .. " " .. branch .. " " })
    end

    -- リソース (CPU/メモリ)
    local load, mem = get_sys_info()
    table.insert(right_status, { Foreground = { Color = palette.color6 } })
    table.insert(right_status, { Text = "│ " .. load .. mem })

    -- 時刻
    table.insert(right_status, { Foreground = { Color = palette.color5 } })
    table.insert(right_status, { Text = "│ " .. ICONS.time .. " " .. wezterm.strftime("%H:%M") .. "  " })

    -- バッテリー (あれば)
    local bat_info = wezterm.battery_info()
    if #bat_info > 0 then
      local b = bat_info[1]
      local bat_icon = b.state == "Charging" and ICONS.bat_charging or ICONS.bat_discharging
      table.insert(right_status, { Foreground = { Color = palette.color3 } })
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
