local wezterm = require("wezterm")
local module = {}
local palette = require("omarchy_theme").get_palette()
local tab = require("tab")
local workspace_color = require("workspace_color")
local ui = require("modules.ui")

-- =============================================================================
-- 定数 & アイコン
-- =============================================================================

local WORKSPACE_COLORS = {
  copy_mode = palette.color3,
  setting_mode = palette.color2,
}

-- nerdfont名が(バージョン差で)存在しなくてもステータスバー全体を壊さない
local function nf(name, fallback)
  local ok, glyph = pcall(function() return wezterm.nerdfonts[name] end)
  if ok and glyph and glyph ~= "" then return glyph end
  return fallback
end

local ICONS = {
  git = wezterm.nerdfonts.md_git,
  dir = wezterm.nerdfonts.md_folder_open,
  server = wezterm.nerdfonts.md_server,
  nix = wezterm.nerdfonts.linux_nixos,
  push = nf("md_key_alert", nf("md_key", "󰌆")),
  time = wezterm.nerdfonts.md_clock_outline,
  cpu = wezterm.nerdfonts.md_cpu_64_bit,
  mem = wezterm.nerdfonts.md_memory,
  bat_charging = wezterm.nerdfonts.md_battery_charging,
  bat_discharging = wezterm.nerdfonts.md_battery,
  workspace = nf("md_view_dashboard", "󰕮"),
  leader = "󱐋",
  hint = "󱊑",
  ssh = wezterm.nerdfonts.md_server,
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
    load = content:match("^(%d+%.%d+)") or ""
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
      mem = string.format("%d%%", used_percent)
    end
  end

  return load, mem
end

-- タブ列が使った残り幅を返す (retroタブバーは右ステータスを左から切り詰めるだけなので自前で予算管理する)
local function available_right_width(window, left_text)
  local mux_window = window:mux_window()
  local active_tab = window:active_tab()
  if not (mux_window and active_tab) then return math.huge end
  local used = wezterm.column_width(left_text)
  for _, t in ipairs(mux_window:tabs()) do
    used = used + (tab.rendered_width[t:tab_id()] or 0)
  end
  return active_tab:get_size().cols - used - 1
end

-- segments: { {prio=, items={format要素...}, width=} ...}。prioが小さいものから捨てて予算に収める
local function fit_segments(segments, budget)
  local total = 0
  for _, seg in ipairs(segments) do total = total + seg.width end
  local order = {}
  for i, seg in ipairs(segments) do order[#order + 1] = { i = i, prio = seg.prio } end
  table.sort(order, function(a, b) return a.prio < b.prio end)
  local dropped = {}
  for _, o in ipairs(order) do
    if total <= budget then break end
    dropped[o.i] = true
    total = total - segments[o.i].width
  end
  local out = {}
  for i, seg in ipairs(segments) do
    if not dropped[i] then
      for _, item in ipairs(seg.items) do out[#out + 1] = item end
    end
  end
  return out
end

-- =============================================================================
-- メイン処理
-- =============================================================================

function module.apply_to_config(_)
  wezterm.on("update-status", function(window, pane)
    local workspace = window:active_workspace()
    local key_table = window:active_key_table()
    -- 通常時はワークスペースごとの色 (左下・カーソル・アクティブタブで共通)
    local color = WORKSPACE_COLORS[key_table] or workspace_color(workspace)

    -- -------------------------------------------------------------------------
    -- 左側: ワークスペース表示 & LEADER 状態
    -- -------------------------------------------------------------------------
    -- 左端: ワークスペース (背景なし。アイコンと名前をワークスペース色で)
    local left_icon, left_label = ICONS.workspace, workspace
    if window:leader_is_active() then
      color = palette.color1
      left_icon, left_label = ICONS.leader, "LEADER"
    end
    local left_items = {
      { Background = { Color = "transparent" } },
      { Text = " " },
      { Foreground = { Color = color } },
      { Text = left_icon .. " " },
      { Attribute = { Intensity = "Bold" } },
      { Text = left_label },
      { Attribute = { Intensity = "Normal" } },
      { Foreground = { Color = ui.muted } },
      { Text = "  " },
    }
    local leader_text = " " .. left_icon .. " " .. left_label .. "  " -- 幅計算用
    window:set_left_status(wezterm.format(left_items))

    -- -------------------------------------------------------------------------
    -- 右側: プログレッシブ・ステータス
    -- タブが増えて幅が足りなくなったら prio の低い項目から非表示にする
    -- -------------------------------------------------------------------------
    local segments = {}
    -- 1項目 = 色付きアイコン + 淡い文字。背景なし、区切りは余白だけ
    local function add(prio, fg, icon, text)
      local items = {
        { Background = { Color = "transparent" } },
        { Foreground = { Color = fg } },
        { Text = icon .. " " },
        { Foreground = { Color = ui.subtext } },
        { Text = text .. "   " },
      }
      segments[#segments + 1] = { prio = prio, items = items, width = wezterm.column_width(icon .. " " .. text .. "   ") }
    end

    local branch = get_git_branch(pane)
    local cwd = get_short_cwd(pane)

    -- ガイド表示 (ショートカットヒント)
    local hint_text = ""
    local hint_fg = palette.color3

    if window:leader_is_active() then
      hint_text = " [g] Project | [l] Launch | [r/d] Split | [f] Zoom | [z] CopyLast | [i] BG "
    elseif key_table == "setting_mode" then
      hint_text = " [h/j/k/l] Resize | [1-9] Ratio | [q/Esc] Exit "
      hint_fg = palette.color2
    elseif key_table == "copy_mode" then
      hint_text = " [v] Select | [y] Copy | [/] Find | [n/p] Next/Prev | [q] Exit "
      hint_fg = palette.color3
    elseif key_table == "search_mode" then
      hint_text = " [Enter] Case | [Esc] Close "
    end

    -- prio: 大きいほど最後まで残る
    if hint_text ~= "" then
      add(90, hint_fg, ICONS.hint, (hint_text:gsub("^%s+", ""):gsub("%s+$", "")))
    end

    -- ホスト名 (SSH判定)
    local user_vars = pane:get_user_vars()
    if user_vars.ssh_host then
      add(80, palette.color3, ICONS.server, user_vars.ssh_host)
    end

    -- CWD (短縮パス)
    add(30, palette.color4, ICONS.dir, cwd)

    -- Git
    if branch ~= "" then
      add(60, palette.color2, ICONS.git, branch)
    end

    -- Nix devshell (zsh側precmdのSetUserVar連携。中身はnixwhereで確認)
    if user_vars.nix_shell and user_vars.nix_shell ~= "" then
      add(40, palette.color6, ICONS.nix, user_vars.nix_shell)
    end

    -- push認証 (常時表示。personal=緑 / lab=赤)。commit authorは常にpersonalなので"誰としてpushするか"
    if user_vars.gh_push and user_vars.gh_push ~= "" then
      local push_color = user_vars.gh_push == "lab" and palette.color1 or palette.color2
      add(70, push_color, ICONS.push, "push:" .. user_vars.gh_push)
    end

    -- リソース (CPU/メモリ)
    local load, mem = get_sys_info()
    add(10, palette.color6, ICONS.cpu, load .. "  " .. ICONS.mem .. " " .. mem)

    -- 時刻
    add(50, palette.color5, ICONS.time, wezterm.strftime("%H:%M"))

    -- バッテリー (あれば)
    local bat_info = wezterm.battery_info()
    if #bat_info > 0 then
      local b = bat_info[1]
      local bat_icon = b.state == "Charging" and ICONS.bat_charging or ICONS.bat_discharging
      add(20, palette.color3, bat_icon, string.format("%.0f%%", b.state_of_charge * 100))
    end

    local right_status = fit_segments(segments, available_right_width(window, leader_text))
    window:set_right_status(wezterm.format(right_status))

    -- カーソル色変更
    if last_color ~= color then
      last_color = color
      pane:inject_output("\x1b]12;" .. color .. "\x1b\\")
    end
  end)
end

return module
