local wezterm = require("wezterm")
local module = {}

-- Custom tab titles (tab_id -> string or nil)
module.custom_title = {}

-- =============================================================================
-- 定数
-- =============================================================================

local ICONS = {
  docker = wezterm.nerdfonts.md_docker,
  neovim = wezterm.nerdfonts.linux_neovim,
  nb = wezterm.nerdfonts.md_notebook,
  ssh = wezterm.nerdfonts.md_lan,
  claude = "✳",
  fallback = wezterm.nerdfonts.dev_terminal,
  zoom = wezterm.nerdfonts.md_magnify,
}

local ICON_COLORS = {
  docker = "#7a9ec2",
  neovim = "#a0b88c",
  nb = "#b4a7d6",
  ssh = "#c27878",
  claude = "#D97757",
}

local TAB_COLORS = {
  foreground_inactive = "#8b8498",
  background_inactive = "none",
  foreground_active = "#1e1a2e",
  background_active = "#b4a7d6",
  background_ssh_active = "#c27878",
  foreground_ssh_active = "#e8d8c4",
}

local DECORATIONS = {
  left_circle = wezterm.nerdfonts.ple_left_half_circle_thick,
  right_circle = wezterm.nerdfonts.ple_right_half_circle_thick,
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

local function get_icon_and_color(process_name, pane_title, cmdline, cwd, is_ssh, is_active, is_claude)
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
    return ICONS.claude, ICON_COLORS.claude
  end

  if process_name == "docker" or (pane_title and pane_title:find("docker")) then
    return ICONS.docker, ICON_COLORS.docker
  end

  return ICONS.fallback, TAB_COLORS.foreground_inactive
end

local function get_tab_colors(is_active, is_ssh)
  if is_active and is_ssh then
    return TAB_COLORS.background_ssh_active, TAB_COLORS.foreground_ssh_active
  elseif is_active then
    return TAB_COLORS.background_active, TAB_COLORS.foreground_active
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

    -- Claude Code検出
    local is_claude = claude_cache[pane_id] or false

    -- タブの色
    local background, foreground = get_tab_colors(tab.is_active, is_ssh)
    local edge_background = "transparent"
    local edge_foreground = background

    -- タイトルテキスト
    local title_text
    local custom = module.custom_title[tab.tab_id]
      or (tab.tab_title ~= "" and tab.tab_title or nil)
    
    if custom then
      title_text = custom
    elseif is_ssh then
      title_text = ssh_host_cache[pane_id] or "ssh"
    elseif is_nb_process(process_name, cmdline, cached_cwd) then
      title_text = "nb"
    else
      title_text = title_cache[pane_id] or "-"
    end

    -- Claude Code のタイトル追加
    local claude_suffix = ""
    if not custom and is_claude and pane_title ~= "" then
      claude_suffix = " " .. pane_title
    end

    -- アイコン
    local icon, icon_color = get_icon_and_color(process_name, pane_title, cmdline, cached_cwd, is_ssh, tab.is_active, is_claude)

    -- ズームインジケーター
    local zoom_indicator = has_zoomed_pane(tab.panes) and (ICONS.zoom .. " ") or ""

    -- 半円
    local left_circle = tab.is_active and DECORATIONS.left_circle or ""
    local right_circle = tab.is_active and DECORATIONS.right_circle or ""

    return {
      { Background = { Color = edge_background } },
      { Text = " " },
      { Foreground = { Color = edge_foreground } },
      { Text = left_circle },
      { Background = { Color = background } },
      { Foreground = { Color = icon_color } },
      { Text = icon },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = zoom_indicator },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. wezterm.truncate_right(title_text, max_width) },
      { Attribute = { Intensity = "Normal" } },
      { Text = wezterm.truncate_right(claude_suffix, max_width) .. " " },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = right_circle },
    }
  end)
end

return module
