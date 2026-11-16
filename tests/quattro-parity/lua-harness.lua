-- Hyprland の Lua API (hl.*) を記録用モックに差し替えて Omarchy 4 構成を評価し、
-- 登録されたキーバインド・ウィンドウルール・設定値などを JSON で標準出力に出す。
--
--   lua lua-harness.lua <hyprland.lua> <仮ホーム> <Omarchy 4 ツリー>
--
-- 各登録には呼び出し元ファイルを origin として付ける。仮ホーム配下 (= dotfiles の
-- quattro パッケージ) から来たものが「個人設定」、OMARCHY_PATH 配下が「Omarchy 既定」。
-- 実 Hyprland ではないので、オプション名の正しさまでは保証しない (それは
-- run --live / Hyprland --verify-config の役目)。ここでは「何を登録したか」を見る。

local entry = assert(arg[1], "usage: lua-harness.lua <hyprland.lua> <仮ホーム> <Omarchy 4 ツリー>")
local home = assert(arg[2], "仮ホームを指定")
local omarchy_path = assert(arg[3], "Omarchy 4 ツリーを指定")

-- サンドボックス: 評価する設定 (上流 Omarchy の既定を含む) から外部への副作用を断つ。
--   * シェル実行 (io.popen / os.execute) は実行せず記録だけ。popen は空出力を返す
--   * ファイルは読み取りのみ許可 (書き込み/追記モードは拒否)
--   * HOME / OMARCHY_PATH はプロセス環境を変えずに、この評価内だけ差し替える
-- そのため「コマンドの有無で分岐する既定」(o.shell_succeeds 等) は常に偽側に倒れる。
local sandbox_log = {}
local real_getenv, real_open = os.getenv, io.open
os.getenv = function(key)
  if key == "HOME" then return home end
  if key == "OMARCHY_PATH" then return omarchy_path end
  return real_getenv(key)
end
io.popen = function(cmd)
  table.insert(sandbox_log, { blocked = "io.popen", cmd = tostring(cmd) })
  return { read = function() return "" end, close = function() return true end, lines = function() return function() return nil end end }
end
os.execute = function(cmd)
  table.insert(sandbox_log, { blocked = "os.execute", cmd = tostring(cmd) })
  return nil
end
os.remove, os.rename, os.exit = nil, nil, nil
io.open = function(path, mode)
  mode = mode or "r"
  if not mode:match("^r[b]?$") then
    table.insert(sandbox_log, { blocked = "io.open(" .. mode .. ")", cmd = tostring(path) })
    return nil, "blocked by parity sandbox"
  end
  return real_open(path, mode)
end
io.output, io.lines = nil, io.lines

local seq = 0
local function next_seq() seq = seq + 1 return seq end

local record = {
  binds = {}, unbinds = {}, window_rules = {}, layer_rules = {}, workspace_rules = {},
  config = {}, gestures = {}, monitors = {}, env = {}, on_start = {}, events = {},
  devices = {}, other_calls = {}, errors = {},
}

-- 呼び出し元 (ハーネスと Omarchy の helpers.lua 以外で最初のファイル) を探す
local function origin()
  for level = 3, 40 do
    local info = debug.getinfo(level, "Sl")
    if not info then break end
    local src = info.source or ""
    if src:sub(1, 1) == "@" then
      local path = src:sub(2)
      if not path:find("lua%-harness%.lua$") and not path:find("/default/hypr/helpers%.lua$") then
        local kind = "other"
        if path:sub(1, #home) == home then kind = "user" end
        if path:sub(1, #omarchy_path) == omarchy_path then kind = "omarchy" end
        return { kind = kind, file = path, line = info.currentline }
      end
    end
  end
  return { kind = "unknown" }
end

-- ディスパッチャ: hl.dsp.a.b(args) → { dsp = "a.b", args = args }
local function dsp_namespace(prefix)
  return setmetatable({}, {
    __index = function(_, key)
      local name = prefix == "" and key or (prefix .. "." .. key)
      return dsp_namespace(name)
    end,
    __call = function(_, ...)
      local n = select("#", ...)
      local args = { ... }
      if prefix == "exec_cmd" then
        return { dsp = "exec_cmd", cmd = args[1], opts = args[2] }
      end
      return { dsp = prefix, args = n == 1 and args[1] or args }
    end,
  })
end

local function deep_merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" and #v == 0 then
      deep_merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

local function describe_dispatcher(d)
  if type(d) == "function" then
    local cmd = o and o.bind_commands and o.bind_commands[d]
    return { kind = "function", cmd = cmd }
  elseif type(d) == "table" and d.dsp == "exec_cmd" then
    return { kind = "exec", cmd = d.cmd }
  elseif type(d) == "table" and d.dsp then
    return { kind = "dsp", dsp = d.dsp, args = d.args }
  end
  return { kind = type(d), value = tostring(d) }
end

local function copy_opts(opts)
  local out = {}
  for k, v in pairs(opts or {}) do
    if type(v) ~= "function" then out[k] = v end
  end
  return out
end

hl = setmetatable({
  dsp = dsp_namespace(""),
  bind = function(keys, dispatcher, opts)
    table.insert(record.binds, {
      keys = keys, dispatcher = describe_dispatcher(dispatcher),
      opts = copy_opts(opts), origin = origin(), seq = next_seq(),
    })
  end,
  unbind = function(keys)
    table.insert(record.unbinds, { keys = keys, origin = origin(), seq = next_seq() })
  end,
  window_rule = function(rule)
    table.insert(record.window_rules, { rule = rule, origin = origin() })
  end,
  layer_rule = function(rule)
    table.insert(record.layer_rules, { rule = rule, origin = origin() })
  end,
  workspace_rule = function(rule)
    table.insert(record.workspace_rules, { rule = rule, origin = origin() })
  end,
  config = function(tbl)
    local o_ = origin()
    deep_merge(record.config, tbl)
    record.config_calls = record.config_calls or {}
    table.insert(record.config_calls, { values = tbl, origin = o_ })
  end,
  gesture = function(g)
    table.insert(record.gestures, { gesture = g, origin = origin() })
  end,
  monitor = function(m)
    table.insert(record.monitors, { monitor = m, origin = origin() })
  end,
  env = function(k, v)
    table.insert(record.env, { key = k, value = v, origin = origin() })
  end,
  device = function(d)
    table.insert(record.devices, { device = d, origin = origin() })
  end,
  exec_cmd = function(cmd, opts)
    table.insert(record.on_start, { cmd = cmd, origin = origin(), during = record._event })
  end,
  on = function(event, fn)
    local o_ = origin()
    table.insert(record.events, { event = event, origin = o_ })
    if event == "hyprland.start" then
      record._event = event
      local ok, err = pcall(fn)
      record._event = nil
      if not ok then table.insert(record.errors, "hyprland.start handler: " .. tostring(err)) end
    end
  end,
  timer = function() return { set_enabled = function() end, set_timeout = function() end } end,
  dispatch = function() end,
  get_active_window = function() return nil end,
  get_windows = function() return {} end,
  get_workspaces = function() return {} end,
  get_monitors = function() return {} end,
  get_loaded_plugins = function() return {} end,
  get_config = function() return nil end,
}, {
  -- 未知の hl.xxx(...) は記録だけして nil を返す
  __index = function(_, key)
    return function(...)
      table.insert(record.other_calls, { fn = key, origin = origin() })
      return nil
    end
  end,
})

local ok, err = xpcall(function() dofile(entry) end, debug.traceback)
if not ok then table.insert(record.errors, tostring(err)) end
record._event = nil

-- 最小の JSON エンコーダ (循環参照と関数は捨てる)
local function encode(v, seen)
  seen = seen or {}
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" then return tostring(v)
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type and math.type(v) == "integer" then return tostring(v) end
    return string.format("%.17g", v)
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
      return map[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  elseif t == "table" then
    if seen[v] then return "null" end
    seen[v] = true
    local is_array = #v > 0 or next(v) == nil
    if is_array then
      for k in pairs(v) do
        if type(k) ~= "number" then is_array = false break end
      end
    end
    local parts = {}
    if is_array then
      for _, item in ipairs(v) do table.insert(parts, encode(item, seen)) end
      seen[v] = nil
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local val = v[k]
      if val == nil then val = v[tonumber(k)] end
      if type(val) ~= "function" then
        table.insert(parts, encode(k) .. ":" .. encode(val, seen))
      end
    end
    seen[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

record.sandbox = sandbox_log
io.stdout:write(encode(record), "\n")
