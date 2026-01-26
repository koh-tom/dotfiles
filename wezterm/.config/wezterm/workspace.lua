local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

-- 前のワークスペースを記憶する変数
local previous_workspace = nil
local previous_workspace_nb = nil

-- scratch ワークスペースのトグル
local function toggle_scratch_workspace()
  return wezterm.action_callback(function(window, pane)
    local current = wezterm.mux.get_active_workspace()
    if current == "scratch" then
      local target = previous_workspace or "default"
      window:perform_action(act.SwitchToWorkspace({ name = target }), pane)
    else
      previous_workspace = current
      window:perform_action(act.SwitchToWorkspace({ name = "scratch" }), pane)
    end
  end)
end

-- nb ワークスペースのトグル
local function toggle_nb_workspace()
  return wezterm.action_callback(function(window, pane)
    local current = wezterm.mux.get_active_workspace()
    if current == "nb" then
      local target = previous_workspace_nb or "default"
      window:perform_action(act.SwitchToWorkspace({ name = target }), pane)
    else
      previous_workspace_nb = current
      window:perform_action(
        act.SwitchToWorkspace({
          name = "nb",
          spawn = { cwd = wezterm.home_dir .. "/src/github.com/mozumasu/nb" }, -- 適宜修正してパスを調整
        }),
        pane
      )
    end
  end)
end

-- scratch や nb をスキップして次のワークスペースへ
local function switch_to_next_workspace_skip_scratch()
  return wezterm.action_callback(function(window, pane)
    local workspaces = wezterm.mux.get_workspace_names()
    local current = wezterm.mux.get_active_workspace()
    local filtered = {}
    for _, ws in ipairs(workspaces) do
      if ws ~= "scratch" and ws ~= "nb" then table.insert(filtered, ws) end
    end
    local current_index = 1
    for i, ws in ipairs(filtered) do
      if ws == current then current_index = i; break end
    end
    local next_index = current_index + 1
    if next_index > #filtered then next_index = 1 end
    if #filtered > 0 then window:perform_action(act.SwitchToWorkspace({ name = filtered[next_index] }), pane) end
  end)
end

-- スクロールをスキップして前のワークスペースへ
local function switch_to_prev_workspace_skip_scratch()
  return wezterm.action_callback(function(window, pane)
    local workspaces = wezterm.mux.get_workspace_names()
    local current = wezterm.mux.get_active_workspace()
    local filtered = {}
    for _, ws in ipairs(workspaces) do
      if ws ~= "scratch" and ws ~= "nb" then table.insert(filtered, ws) end
    end
    local current_index = 1
    for i, ws in ipairs(filtered) do
      if ws == current then current_index = i; break end
    end
    local prev_index = current_index - 1
    if prev_index < 1 then prev_index = #filtered end
    if #filtered > 0 then window:perform_action(act.SwitchToWorkspace({ name = filtered[prev_index] }), pane) end
  end)
end

function module.apply_to_config(config)
  local workspace_keys = {
    { key = "s", mods = "CTRL|SUPER", action = toggle_scratch_workspace() },
    { key = "a", mods = "CTRL|SUPER", action = toggle_nb_workspace() },
    { key = "n", mods = "CTRL|SUPER", action = switch_to_next_workspace_skip_scratch() },
    { key = "p", mods = "CTRL|SUPER", action = switch_to_prev_workspace_skip_scratch() },
    
    {
      key = "w",
      mods = "LEADER",
      action = wezterm.action_callback(function(window, pane)
        -- モード開始（Shift+C等を受け付ける）
        window:perform_action(act.ActivateKeyTable({ name = "workspace_mode", one_shot = false }), pane)
        local workspaces = {}
        for i, name in ipairs(wezterm.mux.get_workspace_names()) do
          if name ~= "scratch" and name ~= "nb" then
            table.insert(workspaces, { id = name, label = string.format("%d. %s", i, name) })
          end
        end
        window:perform_action(act.InputSelector({
          action = wezterm.action_callback(function(_, _, id, _)
            if id then window:perform_action(act.SwitchToWorkspace({ name = id }), pane) end
          end),
          title = "Select workspace",
          choices = workspaces,
          fuzzy = true,
        }), pane)
      end),
    },
  }

  for _, key in ipairs(workspace_keys) do
    table.insert(config.keys, key)
  end

  config.key_tables = config.key_tables or {}
  config.key_tables.workspace_mode = {
    -- Shift+C でワークスペースを新規作成（名前を入力）
    {
      mods = "SHIFT",
      key = "C",
      action = act.PromptInputLine({
        description = "(wezterm) Create new workspace:",
        action = wezterm.action_callback(function(window, inner_pane, line)
          if line then window:perform_action(act.SwitchToWorkspace({ name = line }), inner_pane) end
        end),
      }),
    },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  }
end

return module
