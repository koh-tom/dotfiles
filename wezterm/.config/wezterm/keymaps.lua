local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

-- ペインの比率を保存するテーブル
local pane_height_store = {}

-- ペインの高さを指定したパーセンテージに設定するヘルパー関数
local function apply_pane_height_percent(window, pane, percent)
  local tab = pane:tab()
  local tab_size = tab:get_size()
  local pane_dims = pane:get_dimensions()
  local pane_id = pane:pane_id()

  local is_top_pane = false
  for _, info in ipairs(tab:panes_with_info()) do
    if info.pane:pane_id() == pane_id then is_top_pane = (info.top == 0); break end
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
end

local function set_pane_height_percent(percent)
  return wezterm.action_callback(function(window, pane) apply_pane_height_percent(window, pane, percent) end)
end

-- ペインの幅をパーセンテージで設定するヘルパー関数
local function set_pane_width_percent(percent)
  return wezterm.action_callback(function(window, pane)
    local tab = pane:tab()
    local tab_size = tab:get_size()
    local pane_dims = pane:get_dimensions()
    local pane_id = pane:pane_id()

    local is_left_pane = false
    for _, info in ipairs(tab:panes_with_info()) do
      if info.pane:pane_id() == pane_id then is_left_pane = (info.left == 0); break end
    end

    local target_cols = math.floor(tab_size.cols * percent)
    local current_cols = pane_dims.cols
    local diff = current_cols - target_cols

    if is_left_pane then
      if diff > 0 then window:perform_action(act.AdjustPaneSize({ "Left", diff }), pane)
      elseif diff < 0 then window:perform_action(act.AdjustPaneSize({ "Right", -diff }), pane) end
    else
      if diff > 0 then window:perform_action(act.AdjustPaneSize({ "Right", diff }), pane)
      elseif diff < 0 then window:perform_action(act.AdjustPaneSize({ "Left", -diff }), pane) end
    end
  end)
end

-- リーダーキー定義 (Ctrl + q)
local leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

local keys = {
  { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },
  { key = "n", mods = "SUPER", action = act.SpawnWindow },
  { key = "l", mods = "CTRL|SHIFT", action = act.ShowDebugOverlay },
  { key = ".", mods = "LEADER", action = act.ShowDebugOverlay },
  { key = "r", mods = "SUPER", action = act.ReloadConfiguration },
  { key = "R", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },

  -- フォントサイズ変更
  { key = "phys:Equal", mods = "SUPER", action = act.IncreaseFontSize },
  { key = "phys:Equal", mods = "SHIFT|SUPER", action = act.IncreaseFontSize },
  { key = "phys:Semicolon", mods = "SHIFT|SUPER", action = act.IncreaseFontSize },
  { key = "i", mods = "SUPER", action = act.IncreaseFontSize },
  { key = "phys:Minus", mods = "SUPER", action = act.DecreaseFontSize },
  { key = "o", mods = "SUPER", action = act.DecreaseFontSize },
  { key = "phys:0", mods = "SUPER", action = act.ResetFontSize },

  -- タブ操作
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
  { key = "1", mods = "SUPER", action = act.ActivateTab(0) },
  { key = "2", mods = "SUPER", action = act.ActivateTab(1) },
  { key = "3", mods = "SUPER", action = act.ActivateTab(2) },
  { key = "4", mods = "SUPER", action = act.ActivateTab(3) },
  { key = "5", mods = "SUPER", action = act.ActivateTab(4) },
  { key = "6", mods = "SUPER", action = act.ActivateTab(5) },
  { key = "7", mods = "SUPER", action = act.ActivateTab(6) },
  { key = "8", mods = "SUPER", action = act.ActivateTab(7) },
  { key = "9", mods = "SUPER", action = act.ActivateTab(-1) },
  { key = "t", mods = "SUPER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "SUPER", action = act.CloseCurrentTab({ confirm = true }) },
  
  -- タブリネーム (LEADER + ,)
  {
    key = ",",
    mods = "LEADER",
    action = act.PromptInputLine({
      description = "(wezterm) Rename tab:",
      action = wezterm.action_callback(function(_, inner_pane, line)
        if line then
          local t = inner_pane:tab()
          require("tab").custom_title[t:tab_id()] = line == "" and nil or line
        end
      end),
    }),
  },

  -- ペイン操作
  { key = "h", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Left") },
  { key = "l", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Right") },
  { key = "k", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Up") },
  { key = "j", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Down") },
  { key = ":", mods = "CTRL", action = act.PaneSelect },

  { key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  
  -- ペイン最小化 / 復元 (CTRL+SHIFT+C)
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = wezterm.action_callback(function(window, pane)
      local dims = pane:get_dimensions()
      local id = pane:pane_id()
      if dims.viewport_rows <= 1 then
        local p = pane_height_store[id] or 0.5
        apply_pane_height_percent(window, pane, p)
      else
        local tab = pane:tab()
        pane_height_store[id] = dims.viewport_rows / tab:get_size().rows
        apply_pane_height_percent(window, pane, 0)
        wezterm.time.call_after(0.05, function() pane:inject_output("\r\x1b[2K\x1b[33m◀ Pane Focused ▶\x1b[0m") end)
      end
    end),
  },

  -- ==========================================
  -- その他ツール
  -- ==========================================
  { key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
  { key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },
  { key = "p", mods = "ALT|CTRL", action = act.ScrollByPage(-0.5) },
  { key = "n", mods = "ALT|CTRL", action = act.ScrollByPage(0.5) },
  { key = "[", mods = "ALT", action = act.ScrollToPrompt(-1) },
  { key = "]", mods = "ALT", action = act.ScrollToPrompt(1) },
  
  { key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },
  { key = "P", mods = "CTRL", action = act.ActivateCommandPalette },
  { key = "U", mods = "CTRL", action = act.CharSelect({ copy_on_select = true }) },
  { key = " ", mods = "SUPER", action = act.QuickSelect },
  { key = "f", mods = "SUPER", action = act.Search("CurrentSelectionOrEmptyString") },
  { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },

  -- 直前コマンドと出力をコピー (LEADER + z)
  {
    key = "z",
    mods = "LEADER",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode({ MoveBackwardZoneOfType = "Input" }),
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode({ MoveForwardZoneOfType = "Prompt" }),
      act.CopyMode("MoveUp"),
      act.CopyMode("MoveToEndOfLineContent"),
      { CopyTo = "ClipboardAndPrimarySelection" },
      { Multiple = { "ScrollToBottom", { CopyMode = "Close" } } },
    }),
  },

  -- ランチャー (LEADER + l)
  {
    key = "l",
    mods = "LEADER",
    action = act.InputSelector({
      title = "Launch",
      choices = { { label = "Lazygit" }, { label = "Neovim" }, { label = "Yazi" }, { label = "Claude" } },
      fuzzy = true,
      action = wezterm.action_callback(function(window, pane, _, label)
        if label then
          local cmd = label:lower()
          local new_pane = pane:split({ direction = "Bottom", size = 1.0, args = { os.getenv("SHELL"), "-lc", cmd } })
          window:perform_action(act.TogglePaneZoomState, new_pane)
        end
      end),
    }),
  },

  -- モード開始
  { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "setting_mode", one_shot = false }) },
  { key = "x", mods = "SHIFT|CTRL", action = act.ActivateCopyMode },
}

local key_tables = {
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
    { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
    { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
    { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
    { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
    { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
    { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
    { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
    { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
    { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
    { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
    { key = "/", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") },
  },
  search_mode = {
    { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
    { key = "n", mods = "CTRL", action = act.Multiple({ act.CopyMode("NextMatch"), act.ActivateCopyMode }) },
    { key = "p", mods = "CTRL", action = act.Multiple({ act.CopyMode("PriorMatch"), act.ActivateCopyMode }) },
  },
  setting_mode = {
    { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
    { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "1", action = set_pane_height_percent(0.1) },
    { key = "2", action = set_pane_height_percent(0.2) },
    { key = "3", action = set_pane_height_percent(0.3) },
    { key = "4", action = set_pane_height_percent(0.4) },
    { key = "5", action = set_pane_height_percent(0.5) },
    { key = "6", action = set_pane_height_percent(0.6) },
    { key = "7", action = set_pane_height_percent(0.7) },
    { key = "8", action = set_pane_height_percent(0.8) },
    { key = "9", action = set_pane_height_percent(0.9) },
    { key = "1", mods = "CTRL", action = set_pane_width_percent(0.1) },
    { key = "2", mods = "CTRL", action = set_pane_width_percent(0.2) },
    { key = "3", mods = "CTRL", action = set_pane_width_percent(0.3) },
    { key = "4", mods = "CTRL", action = set_pane_width_percent(0.4) },
    { key = "5", mods = "CTRL", action = set_pane_width_percent(0.5) },
    { key = "6", mods = "CTRL", action = set_pane_width_percent(0.6) },
    { key = "7", mods = "CTRL", action = set_pane_width_percent(0.7) },
    { key = "8", mods = "CTRL", action = set_pane_width_percent(0.8) },
    { key = "9", mods = "CTRL", action = set_pane_width_percent(0.9) },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  },
}

function module.apply_to_config(config)
  config.disable_default_key_bindings = false
  config.leader = leader
  config.keys = keys
  config.key_tables = key_tables
end

return module
