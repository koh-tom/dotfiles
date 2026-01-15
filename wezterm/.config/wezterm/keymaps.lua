local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

-- オーバーレイペインでコマンドを実行するヘルパー関数
local function spawn_overlay_pane(command)
  return wezterm.action_callback(function(window, pane)
    local new_pane = pane:split({
      direction = "Bottom",
      size = 1.0,
      args = { os.getenv("SHELL"), "-lc", command },
    })
    window:perform_action(act.TogglePaneZoomState, new_pane)
  end)
end

-- ペインの高さを指定したパーセンテージに設定するヘルパー関数
local function set_pane_height_percent(percent)
  return wezterm.action_callback(function(window, pane)
    local tab = pane:tab()
    local tab_size = tab:get_size()
    local pane_dims = pane:get_dimensions()
    local pane_id = pane:pane_id()

    -- ペインの位置を取得（topが0なら上のペイン）
    local is_top_pane = false
    for _, info in ipairs(tab:panes_with_info()) do
      if info.pane:pane_id() == pane_id then
        is_top_pane = (info.top == 0)
        break
      end
    end

    local target_rows = math.floor(tab_size.rows * percent)
    local current_rows = pane_dims.viewport_rows
    local diff = current_rows - target_rows

    if is_top_pane then
      if diff > 0 then window:perform_action(act.AdjustPaneSize({ "Up", diff }), pane)
      elseif diff < 0 then window:perform_action(act.AdjustPaneSize({ "Down", -diff }), pane) end
    else
      if diff > 0 then window:perform_action(act.AdjustPaneSize({ "Down", diff }), pane)
      elseif diff < 0 then window:perform_action(act.AdjustPaneSize({ "Up", -diff }), pane) end
    end
  end)
end

-- リーダーキー定義 (Ctrl + q)
local leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

local keys = {
  -- 基本操作
  { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },
  
  -- タブ操作
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
  { key = "1", mods = "SUPER", action = act.ActivateTab(0) },
  { key = "2", mods = "SUPER", action = act.ActivateTab(1) },
  { key = "3", mods = "SUPER", action = act.ActivateTab(2) },
  { key = "4", mods = "SUPER", action = act.ActivateTab(3) },
  { key = "5", mods = "SUPER", action = act.ActivateTab(4) },
  { key = "9", mods = "SUPER", action = act.ActivateTab(-1) },
  { key = "t", mods = "SUPER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "SUPER", action = act.CloseCurrentTab({ confirm = true }) },

  -- ペイン移動 (Shift + 方向キー風)
  { key = "h", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Left") },
  { key = "l", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Right") },
  { key = "k", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Up") },
  { key = "j", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Down") },

  -- ペイン分割 (LEADER + キー)
  { key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) }, -- 横に分割
  { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },   -- 縦に分割
  { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },      -- ペインを閉じる
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },                             -- ズーム

  -- クリップボード
  { key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },

  -- コマンドパレット・検索
  { key = "P", mods = "CTRL", action = act.ActivateCommandPalette },
  { key = " ", mods = "SUPER", action = act.QuickSelect },
  { key = "f", mods = "SUPER", action = act.Search("CurrentSelectionOrEmptyString") },

  -- 設定モード (LEADER + s)
  { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "setting_mode", one_shot = false }) },

  -- コピーモード
  { key = "x", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
}

local key_tables = {
  -- コピーモード (Vim風キーバインド)
  copy_mode = {
    { key = "q", mods = "NONE", action = act.CopyMode("Close") },
    { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
    { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
    { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
    { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
    { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
    { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
    { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
    { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
    { key = "y", mods = "NONE", action = act.CopyTo("ClipboardAndPrimarySelection") },
    { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
    { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
    { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
    { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
  },

  -- 設定モード (リサイズ)
  setting_mode = {
    { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
    { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "1", action = set_pane_height_percent(0.1) },
    { key = "2", action = set_pane_height_percent(0.2) },
    { key = "5", action = set_pane_height_percent(0.5) },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  },
}

function module.apply_to_config(config)
  config.disable_default_key_bindings = false -- 慣れるまではデフォルト込みでもOK
  config.leader = leader
  config.keys = keys
  config.key_tables = key_tables
end

return module
