-- =============================================================================
-- modules/session.lua (Stable Tab & CWD Restore)
-- =============================================================================

local wezterm = require("wezterm")
local act     = wezterm.action

local module = {}

-- ---------------------------------------------------------------------------
-- 定数
-- ---------------------------------------------------------------------------
local SESSION_DIR  = wezterm.home_dir .. "/.local/share/wezterm/sessions"
local SESSION_FILE = SESSION_DIR .. "/last.json"

-- ---------------------------------------------------------------------------
-- ユーティリティ
-- ---------------------------------------------------------------------------
local function ensure_dir(path)
  return os.execute("mkdir -p " .. wezterm.shell_quote_arg(path))
end

-- 安全な配列判定
local function is_array(t)
    if type(t) ~= "table" then return false end
    local i = 1
    for _ in pairs(t) do
        if t[i] == nil then return false end
        i = i + 1
    end
    return i > 1 or (next(t) == nil)
end

-- JSON エンコーダ (簡易)
local function json_encode(val)
  local t = type(val)
  if t == "nil" then return "null"
  elseif t == "boolean" then return tostring(val)
  elseif t == "number" then return tostring(val)
  elseif t == "string" then
    local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. escaped .. '"'
  elseif t == "table" then
    if is_array(val) then
      local items = {}
      for _, v in ipairs(val) do table.insert(items, json_encode(v)) end
      return "[" .. table.concat(items, ",") .. "]"
    else
      local pairs_list = {}
      for k, v in pairs(val) do
        table.insert(pairs_list, '"' .. tostring(k) .. '":' .. json_encode(v))
      end
      return "{" .. table.concat(pairs_list, ",") .. "}"
    end
  end
  return '"[' .. t .. ']"'
end

-- JSON デコーダ (Wezterm 内蔵優先)
local function parse_json(s)
  if wezterm.json_decode then return wezterm.json_decode(s) end
  -- 簡易デコード
  local pos = 1
  local function skip_ws() while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end end
  local parse
  local function parse_string()
    pos = pos + 1; local res = {}
    while pos <= #s do
      local c = s:sub(pos, pos)
      if c == '"' then pos = pos + 1; break
      elseif c == '\\' then
        pos = pos + 1; local esc = s:sub(pos, pos)
        if esc == 'n' then table.insert(res, '\n') elseif esc == 'r' then table.insert(res, '\r')
        elseif esc == 't' then table.insert(res, '\t') else table.insert(res, esc) end
        pos = pos + 1
      else table.insert(res, c); pos = pos + 1 end
    end
    return table.concat(res)
  end
  local function parse_array()
    pos = pos + 1; local arr = {}; skip_ws()
    if s:sub(pos, pos) == ']' then pos = pos + 1; return arr end
    while true do
      skip_ws(); table.insert(arr, parse()); skip_ws()
      local c = s:sub(pos, pos)
      if c == ']' then pos = pos + 1; break elseif c == ',' then pos = pos + 1 end
    end
    return arr
  end
  local function parse_object()
    pos = pos + 1; local obj = {}; skip_ws()
    if s:sub(pos, pos) == '}' then pos = pos + 1; return obj end
    while true do
      skip_ws(); local key = parse_string(); skip_ws(); pos = pos + 1 
      skip_ws(); obj[key] = parse(); skip_ws()
      local c = s:sub(pos, pos)
      if c == '}' then pos = pos + 1; break elseif c == ',' then pos = pos + 1 end
    end
    return obj
  end
  parse = function()
    skip_ws(); local c = s:sub(pos, pos)
    if not c or c == "" then return nil end
    if c == '"' then return parse_string()
    elseif c == '[' then return parse_array()
    elseif c == '{' then return parse_object()
    elseif s:sub(pos, pos+3) == "null" then pos=pos+4; return nil
    elseif s:sub(pos, pos+3) == "true" then pos=pos+4; return true
    elseif s:sub(pos, pos+4) == "false" then pos=pos+5; return false
    else
      local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
      if n then pos = pos + #n; return tonumber(n) end
    end
  end
  return parse()
end

-- ---------------------------------------------------------------------------
-- セッション保存
-- ---------------------------------------------------------------------------
local function save_session(window)
  wezterm.log_info("[session] Saving session (Tabs & CWD)...")
  
  local session = { saved_at = os.date("%Y-%m-%dT%H:%M:%S"), workspaces = {} }
  
  for _, ws_name in ipairs(wezterm.mux.get_workspace_names()) do
    local ws_data = { name = ws_name, tabs = {} }
    
    for _, win in ipairs(wezterm.mux.all_windows()) do
      if win:get_workspace() == ws_name then
        for _, tab in ipairs(win:tabs()) do
          local p = tab:active_pane()
          local cwd = wezterm.home_dir
          local ok, cwd_obj = pcall(function() return p:get_current_working_dir() end)
          if ok and cwd_obj then cwd = cwd_obj.file_path or cwd_obj.path or cwd end
          table.insert(ws_data.tabs, { cwd = cwd })
        end
        break
      end
    end
    if #ws_data.tabs > 0 then table.insert(session.workspaces, ws_data) end
  end

  if ensure_dir(SESSION_DIR) then
    local f = io.open(SESSION_FILE, "w")
    if f then
      f:write(json_encode(session))
      f:close()
      wezterm.log_info("[session] Save Complete")
      window:toast_notification("WezTerm Session", "Session Saved", nil, 3000)
    end
  end
end

-- ---------------------------------------------------------------------------
-- セッション復元
-- ---------------------------------------------------------------------------
local function restore_session()
  wezterm.log_info("[session] restore_session started")
  local f = io.open(SESSION_FILE, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()

  local session = parse_json(content)
  if not session or not session.workspaces then return end

  local is_first_win = true
  for _, ws in ipairs(session.workspaces) do
    if is_first_win then
      local win = wezterm.mux.all_windows()[1]
      if win then
        win:set_workspace(ws.name)
        local initial_tabs = win:tabs()
        
        -- 全タブを開く
        for _, t_data in ipairs(ws.tabs) do
          win:spawn_tab({ cwd = t_data.cwd })
        end

        -- 古い初期タブを閉じる
        for _, it in ipairs(initial_tabs) do
          local ps = it:panes()
          if #ps > 0 then ps[1]:close() end
        end
      end
      is_first_win = false
    else
      -- 2つ目以降のウィンドウ
      local win, _, _ = wezterm.mux.spawn_window({ workspace = ws.name, cwd = ws.tabs[1].cwd })
      for i = 2, #ws.tabs do
        win:spawn_tab({ cwd = ws.tabs[i].cwd })
      end
    end
    ::next_ws::
  end
  wezterm.log_info("[session] Restore Complete")
end

-- ---------------------------------------------------------------------------
-- apply_to_config
-- ---------------------------------------------------------------------------
function module.apply_to_config(config)
  table.insert(config.keys, {
    key = "S",
    mods = "LEADER|SHIFT",
    action = wezterm.action_callback(function(window, _)
      save_session(window)
    end),
  })

  wezterm.on("gui-startup", function()
    wezterm.time.call_after(0.05, function()
      restore_session()
    end)
  end)
end

return module
