local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

-- アイコン定義
local ICONS = {
  workspace = wezterm.nerdfonts.md_view_dashboard,
  project = wezterm.nerdfonts.md_folder,
  claude = wezterm.nerdfonts.md_robot,
  separator = wezterm.nerdfonts.ple_right_half_circle_thin,
  status_running = "●",
}

-- プロジェクト名を取得（パスから）
local function get_project_name(path)
  if not path or path == "" then return "unknown" end
  path = path:gsub("/$", "")
  return path:match("([^/]+)$") or "unknown"
end

-- 全セッションをスキャン
local function scan_active_claude_sessions()
  local sessions = {}
  for _, mux_window in ipairs(wezterm.mux.all_windows()) do
    local workspace = mux_window:get_workspace()
    for _, tab in ipairs(mux_window:tabs()) do
      for _, pane_info in ipairs(tab:panes_with_info()) do
        local pane = pane_info.pane
        local process_name = pane:get_foreground_process_name()
        if process_name and process_name:find("claude") then
          local cwd_url = pane:get_current_working_dir()
          local cwd = cwd_url and cwd_url.file_path or ""
          table.insert(sessions, {
            pane = pane, pane_id = pane:pane_id(),
            workspace = workspace, cwd = cwd,
            tab_id = tab:tab_id(), mux_window = mux_window,
          })
        end
      end
    end
  end
  return sessions
end

-- セッション情報をファイル出力
local function export_sessions(sessions, filepath, formatted_path)
  local jsonl = io.open(filepath, "w")
  local fzf_in = io.open(formatted_path, "w")
  if not jsonl or not fzf_in then return end

  for _, s in ipairs(sessions) do
    local project = get_project_name(s.cwd)
    local workspace = s.workspace or "default"
    
    -- JSON Line 形式 (preview script用)
    jsonl:write(string.format('{"pane_id":"%s","workspace":"%s","project":"%s","content":""}\n', s.pane_id, workspace, project))
    
    -- fzf 表示用形式 (ANSI色付き)
    local line = string.format("\x1b[38;5;114m%s \x1b[38;5;141m%s %s \x1b[38;5;240m%s \x1b[38;5;117m%s %s|%s\n",
      ICONS.status_running, ICONS.workspace, workspace, ICONS.separator, ICONS.project, project, s.pane_id)
    fzf_in:write(line)
  end
  
  jsonl:close()
  fzf_in:close()
end

-- fzf セレクター起動
local function create_fzf_selector()
  return wezterm.action_callback(function(window, pane)
    local sessions = scan_active_claude_sessions()
    if #sessions == 0 then
      window:toast_notification("Claude Code", "No active Claude Code sessions found", nil, 4000)
      return
    end

    local tmp = "/tmp/wezterm_claude_" .. os.time()
    local sessions_file = tmp .. ".jsonl"
    local fzf_input = tmp .. ".txt"
    local result_file = tmp .. ".res"
    export_sessions(sessions, sessions_file, fzf_input)

    local config_dir = wezterm.config_dir or (os.getenv("HOME") .. "/.config/wezterm")
    local preview_script = config_dir .. "/scripts/preview_claude_session.lua"

    local fzf_colors = "--color=fg:255,bg:-1,hl:117,fg+:255,bg+:237,hl+:141,info:240,prompt:141,pointer:141,marker:141,spinner:141,header:240"
    local command = string.format([[fzf --ansi --height=50%% --reverse --border=rounded --prompt="🤖 Claude Session > " --preview='lua "%s" "%s" {}' --preview-window=right:60%%:wrap --delimiter='|' --with-nth=1 %s < "%s" > "%s"]],
      preview_script, sessions_file, fzf_colors, fzf_input, result_file)

    local new_pane = pane:split({ direction = "Bottom", size = 1.0, args = { os.getenv("SHELL"), "-lc", command } })
    window:perform_action(act.TogglePaneZoomState, new_pane)

    -- 結果処理
    wezterm.time.call_after(0.5, function()
      local function check_pane_closed()
        local tab = window:active_tab()
        if not tab then return end
        local pane_exists = false
        for _, p in ipairs(tab:panes()) do if p:pane_id() == new_pane:pane_id() then pane_exists = true; break end end

        if pane_exists then
          wezterm.time.call_after(0.3, check_pane_closed)
        else
          local res = io.open(result_file, "r")
          if res then
            local line = res:read("*line")
            res:close()
            local pane_id = line and line:match("|([^|]+)$")
            if pane_id then
              for _, s in ipairs(sessions) do
                if tostring(s.pane_id) == pane_id then
                  if s.workspace ~= wezterm.mux.get_active_workspace() then
                    window:perform_action(act.SwitchToWorkspace({ name = s.workspace }), pane)
                  end
                  s.pane:activate()
                  break
                end
              end
            end
          end
          os.remove(sessions_file); os.remove(fzf_input); os.remove(result_file)
        end
      end
      check_pane_closed()
    end)
  end)
end

function module.apply_to_config(config)
  table.insert(config.keys, { key = "c", mods = "LEADER", action = create_fzf_selector() })
end

return module
