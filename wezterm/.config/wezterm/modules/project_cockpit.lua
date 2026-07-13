local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

-- 既定レシピ。"dev" は nvim + 下30%シェル + lazygitタブの複合レイアウト
local RECIPES = {
  { id = "dev", label = "  Dev Layout (nvim + shell + lazygit)" },
  { id = "shell", label = "  Shell", args = nil },
  { id = "editor", label = "  Neovim", args = { "nvim" } },
  { id = "ai", label = "󰚩  Claude Code", args = { "claude" } },
  { id = "git", label = "  Lazygit", args = { "lazygit" } },
  { id = "github", label = "  GitHub Dashboard", args = { "gh", "dash" } },
}

local function basename(path)
  return (path:gsub("/$", ""):match("([^/]+)$")) or path
end

local function workspace_name(path)
  local clean = path:gsub("/$", "")
  local parent, project = clean:match(".*/([^/]+)/([^/]+)$")
  if parent and project then return parent .. "/" .. project end
  return basename(clean)
end

local function workspace_exists(name)
  for _, ws in ipairs(wezterm.mux.get_workspace_names()) do
    if ws == name then return true end
  end
  return false
end

-- プロジェクトルートの .cockpit.lua があれば独自レシピを先頭に足す
--   例: return { { id = "server", label = "󰒋  Dev Server", args = { "pnpm", "dev" } } }
local function recipes_for(path)
  local recipes = {}
  local ok, custom = pcall(dofile, path .. "/.cockpit.lua")
  if ok and type(custom) == "table" then
    for _, r in ipairs(custom) do
      if type(r) == "table" and r.id and r.label then
        table.insert(recipes, r)
      end
    end
  end
  for _, r in ipairs(RECIPES) do
    table.insert(recipes, r)
  end
  return recipes
end

local function project_choices()
  local ok, stdout = wezterm.run_child_process({ "zoxide", "query", "-l" })
  if not ok then return {} end

  local choices = {}
  local seen = {}
  for path in stdout:gmatch("[^\r\n]+") do
    local project_path = path
    local name = basename(project_path)
    if project_path ~= wezterm.home_dir and name:sub(1, 1) ~= "." and name ~= "Downloads" then
      local git_ok, git_stdout = wezterm.run_child_process({ "git", "-C", project_path, "rev-parse", "--show-toplevel" })
      if git_ok and git_stdout and git_stdout:match("%S") then
        project_path = git_stdout:gsub("%s+$", "")
        name = basename(project_path)
      end

      if not seen[project_path] then
        seen[project_path] = true
        local display = project_path:gsub("^" .. wezterm.home_dir, "~")
        table.insert(choices, { id = project_path, label = name .. "  " .. display })
      end
    end
  end
  return choices
end

-- nvim(70%) / shell(30%) 分割 + lazygitタブのworkspaceを一発構築
local function spawn_dev_layout(window, pane, path)
  local name = workspace_name(path)

  if workspace_exists(name) then
    -- 既存workspaceは壊さず切り替えるだけ
    window:perform_action(act.SwitchToWorkspace({ name = name }), pane)
    return
  end

  window:perform_action(act.SwitchToWorkspace({
    name = name,
    spawn = { cwd = path, args = { "nvim" } },
  }), pane)

  wezterm.time.call_after(0.4, function()
    for _, win in ipairs(wezterm.mux.all_windows()) do
      if win:get_workspace() == name then
        local tabs = win:tabs()
        local first_tab = tabs[1]
        if first_tab and #tabs == 1 and #first_tab:panes() == 1 then
          local main_pane = first_tab:active_pane()
          main_pane:split({ direction = "Bottom", size = 0.3, cwd = path })
          win:spawn_tab({ args = { "lazygit" }, cwd = path })
          first_tab:activate()
          main_pane:activate()
        end
        break
      end
    end
  end)
end

local function choose_recipe(window, pane, path)
  local recipes = recipes_for(path)
  local choices = {}
  for _, r in ipairs(recipes) do
    table.insert(choices, { id = r.id, label = r.label })
  end

  window:perform_action(act.InputSelector({
    title = "Open " .. basename(path),
    choices = choices,
    fuzzy = false,
    action = wezterm.action_callback(function(inner_window, inner_pane, recipe_id)
      if not recipe_id then return end

      if recipe_id == "dev" then
        spawn_dev_layout(inner_window, inner_pane, path)
        return
      end

      local spawn = { cwd = path }
      for _, recipe in ipairs(recipes) do
        if recipe.id == recipe_id then spawn.args = recipe.args; break end
      end

      inner_window:perform_action(act.SwitchToWorkspace({
        name = workspace_name(path),
        spawn = spawn,
      }), inner_pane)
    end),
  }), pane)
end

local function open_project_cockpit()
  return wezterm.action_callback(function(window, pane)
    local choices = project_choices()
    if #choices == 0 then
      window:toast_notification("Project Cockpit", "No zoxide projects found", nil, 3000)
      return
    end

    window:perform_action(act.InputSelector({
      title = "Project Cockpit",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, path)
        if path then choose_recipe(inner_window, inner_pane, path) end
      end),
    }), pane)
  end)
end

function module.apply_to_config(config)
  table.insert(config.keys, { key = "g", mods = "LEADER", action = open_project_cockpit() })
end

return module
