local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

local RECIPES = {
  { id = "shell", label = "  Shell", args = nil },
  { id = "editor", label = "  Neovim", args = { "nvim" } },
  { id = "ai", label = "󰚩  Claude Code", args = { "claude" } },
  { id = "git", label = "  Lazygit", args = { "lazygit" } },
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

local function choose_recipe(window, pane, path)
  window:perform_action(act.InputSelector({
    title = "Open " .. basename(path),
    choices = RECIPES,
    fuzzy = false,
    action = wezterm.action_callback(function(inner_window, inner_pane, recipe_id)
      if not recipe_id then return end

      local spawn = { cwd = path }
      for _, recipe in ipairs(RECIPES) do
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
