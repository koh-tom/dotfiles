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
-- セッション保存 (タブ + ペイン分割ジオメトリ + CWD)
-- ---------------------------------------------------------------------------
local function pane_cwd(p)
  local cwd = wezterm.home_dir
  local ok, cwd_obj = pcall(function() return p:get_current_working_dir() end)
  if ok and cwd_obj then cwd = cwd_obj.file_path or cwd_obj.path or cwd end
  return cwd
end

-- windowがnilなら静かに保存 (自動保存用)
local function save_session(window)
  wezterm.log_info("[session] Saving session (Tabs, Panes & CWD)...")

  local session = { saved_at = os.date("%Y-%m-%dT%H:%M:%S"), workspaces = {} }

  for _, ws_name in ipairs(wezterm.mux.get_workspace_names()) do
    local ws_data = { name = ws_name, tabs = {} }

    for _, win in ipairs(wezterm.mux.all_windows()) do
      if win:get_workspace() == ws_name then
        for _, tab in ipairs(win:tabs()) do
          local tab_data = { panes = {} }
          local infos = tab:panes_with_info()
          table.sort(infos, function(a, b)
            if a.top ~= b.top then return a.top < b.top end
            return a.left < b.left
          end)
          for _, info in ipairs(infos) do
            table.insert(tab_data.panes, {
              cwd = pane_cwd(info.pane),
              top = info.top, left = info.left,
              width = info.width, height = info.height,
            })
          end
          -- 旧フォーマット互換フィールド
          tab_data.cwd = tab_data.panes[1] and tab_data.panes[1].cwd or wezterm.home_dir
          table.insert(ws_data.tabs, tab_data)
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
      if window then
        window:toast_notification("WezTerm Session", "Session Saved", nil, 3000)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- セッション復元 (ペイン分割はベストエフォートで再構築)
-- ---------------------------------------------------------------------------

-- 保存したジオメトリから分割方向とサイズを推定して再分割する
local function apply_splits(first_pane, tab_data)
  local panes_data = tab_data.panes
  if not panes_data or #panes_data < 2 then return end

  local prev_pane, prev_data = first_pane, panes_data[1]
  for i = 2, #panes_data do
    local pd = panes_data[i]
    local direction, size
    if pd.top == prev_data.top then
      direction = "Right"
      size = (pd.width and prev_data.width) and pd.width / (pd.width + prev_data.width) or 0.5
    else
      direction = "Bottom"
      size = (pd.height and prev_data.height) and pd.height / (pd.height + prev_data.height) or 0.5
    end
    size = math.max(0.1, math.min(0.9, size))

    local ok, new_pane = pcall(function()
      return prev_pane:split({ direction = direction, size = size, cwd = pd.cwd })
    end)
    if ok and new_pane then
      prev_pane, prev_data = new_pane, pd
    end
  end
end

local function tab_first_cwd(tab_data)
  if tab_data.panes and tab_data.panes[1] then return tab_data.panes[1].cwd end
  return tab_data.cwd or wezterm.home_dir
end

local function restore_tab(win, tab_data)
  local _, pane = win:spawn_tab({ cwd = tab_first_cwd(tab_data) })
  if pane then apply_splits(pane, tab_data) end
end

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

        -- 全タブを開く (分割込み)
        for _, t_data in ipairs(ws.tabs) do
          restore_tab(win, t_data)
        end

        -- 古い初期タブを閉じる
        for _, it in ipairs(initial_tabs) do
          local ps = it:panes()
          if #ps > 0 then ps[1]:close() end
        end
      end
      is_first_win = false
    else
      -- 2つ目以降のワークスペースは新規ウィンドウ
      local _, pane, win = wezterm.mux.spawn_window({ workspace = ws.name, cwd = tab_first_cwd(ws.tabs[1]) })
      if pane then apply_splits(pane, ws.tabs[1]) end
      for i = 2, #ws.tabs do
        restore_tab(win, ws.tabs[i])
      end
    end
  end
  wezterm.log_info("[session] Restore Complete")
end

-- ---------------------------------------------------------------------------
-- セッション削除 (リセット)
-- ---------------------------------------------------------------------------
local function clear_session(window)
  os.remove(SESSION_FILE)
  wezterm.log_info("[session] Session file deleted")
  window:toast_notification("WezTerm Session", "Session reset: starting fresh next time", nil, 3000)
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

  table.insert(config.keys, {
    key = "D",
    mods = "LEADER|SHIFT",
    action = wezterm.action_callback(function(window, _)
      clear_session(window)
    end),
  })

  -- 5分ごとの自動保存 (トースト無しの静かな保存)
  local AUTOSAVE_INTERVAL = 300
  local function schedule_autosave()
    wezterm.time.call_after(AUTOSAVE_INTERVAL, function()
      pcall(save_session, nil)
      schedule_autosave()
    end)
  end

  wezterm.on("gui-startup", function()
    wezterm.time.call_after(0.05, function()
      restore_session()
    end)
    schedule_autosave()
  end)
end

return module
