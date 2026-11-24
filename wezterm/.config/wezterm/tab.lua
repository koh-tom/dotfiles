local wezterm = require("wezterm")
local module = {}
local palette = require("omarchy_theme").get_palette()
local workspace_color = require("workspace_color")
local ui = require("modules.ui")
local hub = require("modules.hub")

-- Custom tab titles (tab_id -> string or nil)
module.custom_title = {}

-- 描画したタブの表示幅 (tab_id -> cells)。statusbar.lua が右ステータスの幅予算に使う
module.rendered_width = {}

-- =============================================================================
-- 定数
-- =============================================================================

local ICONS = {
  docker = wezterm.nerdfonts.md_docker,
  neovim = wezterm.nerdfonts.linux_neovim,
  nb = wezterm.nerdfonts.md_notebook,
  ssh = wezterm.nerdfonts.md_lan,
  claude = "✳",
  hub = "󰚩",
  fallback = wezterm.nerdfonts.dev_terminal,
  zoom = wezterm.nerdfonts.md_magnify,
}

local ICON_COLORS = {
  docker = palette.color4,
  neovim = palette.color2,
  nb = palette.color5,
  ssh = palette.color1,
  claude = "#D97757",          -- working: Claudeブランドオレンジ
  claude_waiting = palette.color3,   -- 入力待ち: イエロー
  claude_attention = palette.color1, -- 許可待ち等の通知: レッド
  hub = palette.color5,              -- 母艦 (claude-hub) のタブ: 紫 (母艦の tmux の札と同じ色)
}

local TAB_COLORS = {
  foreground_inactive = palette.color7,
  background_inactive = palette.color0,
  foreground_active = palette.background,
  background_ssh_active = palette.color1,
  foreground_ssh_active = palette.background,
}

-- =============================================================================
-- ヘルパー関数
-- =============================================================================

local function basename(path)
  return string.gsub(path or "", "(.*[/\\])(.*)", "%2")
end

local function is_nb_process(process_name, cmdline, cwd)
  return process_name == "nb"
      or (cmdline and (cmdline:find("/nb") or cmdline:find("nb ")))
      or (cwd and cwd:find("%.nb"))
end

local function is_ssh_process(process_name, cmdline, user_vars)
  if user_vars.ssh_host and user_vars.ssh_host ~= "" then
    return true, user_vars.ssh_host
  end
  if process_name:find("ssh") or (cmdline and cmdline:find("ssh")) then
    local host = cmdline and cmdline:match("ssh%s+([%w_%-%.]+)")
    return true, host
  end
  return false, nil
end

local function is_claude_process(process_name, pane_title)
  -- Linux環境では % ではなく ✳ (U+2733) や文字列で判定
  return process_name == "claude" or (pane_title and (pane_title:find("✳") or pane_title:lower():find("claude")))
end

local function extract_project_name(cwd)
  if not cwd then
    return "-"
  end

  local home = os.getenv("HOME")
  if home and cwd:find("^" .. home) then
    cwd = cwd:gsub("^" .. home, "~")
  end

  if cwd:find("%.nb") then
    return "nb"
  end

  local _, project = cwd:match(".*/src/github.com/([^/]+)/([^/]+)")
  if project then
    return project
  end

  cwd = cwd:gsub("/$", "")
  return cwd:match("([^/]+)$") or cwd
end

local function get_icon_and_color(process_name, pane_title, cmdline, cwd, is_ssh, is_active, is_claude, claude_state)
  if is_ssh then
    local color = is_active and "#ffffff" or ICON_COLORS.ssh
    return ICONS.ssh, color
  end

  if pane_title == "nvim" or process_name == "nvim" then
    return ICONS.neovim, ICON_COLORS.neovim -- 既存バグ修正: ICONS.neovim
  end

  if is_nb_process(process_name, cmdline, cwd) then
    return ICONS.nb, ICON_COLORS.nb
  end

  if is_claude then
    -- Claude Code hooks (claude-wezterm-state) が送るuser varで状態色を変える
    if claude_state == "waiting" then
      return ICONS.claude, ICON_COLORS.claude_waiting
    elseif claude_state == "attention" then
      return ICONS.claude, ICON_COLORS.claude_attention
    end
    return ICONS.claude, ICON_COLORS.claude
  end

  if process_name == "docker" or (pane_title and pane_title:find("docker")) then
    return ICONS.docker, ICON_COLORS.docker
  end

  return ICONS.fallback, is_active and TAB_COLORS.foreground_active or TAB_COLORS.foreground_inactive
end

local function get_tab_colors(is_active, is_ssh)
  if is_active and is_ssh then
    return TAB_COLORS.background_ssh_active, TAB_COLORS.foreground_ssh_active
  elseif is_active then
    -- アクティブタブはワークスペースごとの色 (statusbar.lua の左下表示と揃える)
    return workspace_color(wezterm.mux.get_active_workspace()), TAB_COLORS.foreground_active
  end
  return TAB_COLORS.background_inactive, TAB_COLORS.foreground_inactive
end

local function has_zoomed_pane(panes)
  for _, pane_info in ipairs(panes) do
    if pane_info.is_zoomed then
      return true
    end
  end
  return false
end

-- =============================================================================
-- メイン処理
-- =============================================================================

function module.apply_to_config(config)
  local title_cache = {}
  local raw_cwd_cache = {}
  local ssh_host_cache = {}
  local claude_cache = {} -- pane_id -> bool

  -- タイトルキャッシュの更新 (update-statusイベント)
  wezterm.on("update-status", function(_, pane)
    local pane_id = pane:pane_id()
    local user_vars = pane:get_user_vars() or {}

    -- SSH中以外はタイトルキャッシュを更新
    if not (user_vars.ssh_host and user_vars.ssh_host ~= "") then
      local cwd_url = pane:get_current_working_dir()
      local cwd = cwd_url and cwd_url.file_path
      if cwd ~= raw_cwd_cache[pane_id] then
        raw_cwd_cache[pane_id] = cwd
        title_cache[pane_id] = extract_project_name(cwd)
      end
    end

    -- Claude Code検出キャッシュ
    local process_name = basename(pane:get_foreground_process_name() or "")
    local pane_title = pane:get_title() or ""
    if is_claude_process(process_name, pane_title) then
      claude_cache[pane_id] = true
    elseif (process_name == "zsh" or process_name == "bash" or process_name == "fish")
      and not (pane_title:find("✳") or pane_title:lower():find("claude")) then
      claude_cache[pane_id] = nil
    end
  end)

  -- タブタイトルのフォーマット
  wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
    local pane = tab.active_pane
    local pane_id = pane.pane_id -- 修正: フィールドアクセス
    local process_name = basename(pane.foreground_process_name)
    local pane_title = pane.title or ""
    local cmdline = pane.foreground_process_name or ""
    local user_vars = pane.user_vars or {}
    local cached_cwd = title_cache[pane_id] or ""

    -- SSH判定
    local is_ssh, ssh_host = is_ssh_process(process_name, cmdline, user_vars)
    if is_ssh and ssh_host then
      ssh_host_cache[pane_id] = ssh_host
    elseif not is_ssh then
      ssh_host_cache[pane_id] = nil
    end

    -- 母艦 (claude-hub) のタブ: tmux がタイトルを「󰚩 名前」にする。ssh だが母艦の色で別扱いにする
    local is_hub = hub.is_hub_title(pane_title)
    if is_hub then
      is_ssh = false
    end

    -- Claude Code検出と状態 (hooks経由のuser var)
    local is_claude = claude_cache[pane_id] or false
    local claude_state = user_vars.claude_state or ""

    -- タブの色
    local background, foreground = get_tab_colors(tab.is_active, is_ssh)
    if is_hub and tab.is_active then
      background = ICON_COLORS.hub
    end

    -- タイトルテキスト
    local title_text
    local custom = module.custom_title[tab.tab_id]
      or (tab.tab_title ~= "" and tab.tab_title or nil)

    if custom then
      title_text = custom
    elseif is_hub then
      title_text = "母艦 " .. (pane_title:gsub("^" .. ICONS.hub .. "%s*", ""))
    elseif is_ssh then
      title_text = ssh_host_cache[pane_id] or "ssh"
    elseif is_nb_process(process_name, cmdline, cached_cwd) then
      title_text = "nb"
    else
      -- 非アクティブタブはupdate-statusが走らずキャッシュが空のことがあるので、PaneInformationのcwdで補う
      if not title_cache[pane_id] and pane.current_working_dir then
        title_cache[pane_id] = extract_project_name(pane.current_working_dir.file_path)
      end
      title_text = title_cache[pane_id] or "-"
    end

    -- Claude Code のタイトル追加
    local claude_suffix = ""
    if not custom and not is_hub and is_claude and pane_title ~= "" then
      claude_suffix = " " .. pane_title
    end

    -- アイコン
    local icon, icon_color = get_icon_and_color(process_name, pane_title, cmdline, cached_cwd, is_ssh, tab.is_active, is_claude, claude_state)
    if is_hub then
      icon, icon_color = ICONS.hub, ICON_COLORS.hub
    end

    -- ズームインジケーター
    local zoom_indicator = has_zoomed_pane(tab.panes) and (ICONS.zoom .. " ") or ""

    -- ミニマル透明 (bar.wezterm / rose-pine tmux 系): 背景は塗らず、文字色だけで区別する。
    --   今のタブ = ワークスペース色の太字 + 下線 / 他のタブ = 淡いグレー
    local index = tostring(tab.tab_index + 1)
    local title_fg = tab.is_active and background or ui.muted
    local index_fg = tab.is_active and ui.subtext or ui.muted
    local icon_fg = icon_color
    if icon_color == TAB_COLORS.foreground_inactive or icon_color == TAB_COLORS.foreground_active then
      icon_fg = tab.is_active and ui.subtext or ui.muted
    end

    -- 固定部分 (前の余白2 + 番号 + 空白 + アイコン + 空白 + ズーム + 後ろの余白1) を引いた残りをタイトルに
    local fixed = 2 + wezterm.column_width(index) + 1 + wezterm.column_width(icon) + 1
      + wezterm.column_width(zoom_indicator) + 1
    local budget = math.max(max_width - fixed, 1)
    local title = wezterm.truncate_right(title_text, budget)
    local suffix = wezterm.truncate_right(claude_suffix, math.max(budget - wezterm.column_width(title), 0))

    module.rendered_width[tab.tab_id] = fixed + wezterm.column_width(title) + wezterm.column_width(suffix)

    return {
      { Background = { Color = "transparent" } },
      { Text = "  " },
      { Foreground = { Color = index_fg } },
      { Attribute = { Intensity = "Half" } },
      { Text = index },
      { Attribute = { Intensity = "Normal" } },
      { Text = " " },
      { Foreground = { Color = icon_fg } },
      { Text = icon .. " " },
      { Foreground = { Color = title_fg } },
      { Text = zoom_indicator },
      { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
      { Attribute = { Underline = tab.is_active and "Single" or "None" } },
      { Text = title .. suffix },
      { Attribute = { Underline = "None" } },
      { Attribute = { Intensity = "Normal" } },
      { Text = " " },
    }
  end)
end

return module
