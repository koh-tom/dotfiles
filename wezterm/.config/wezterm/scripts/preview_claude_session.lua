-- fzf プレビュー用のヘルパースクリプト
local sessions_file = arg[1]
local line = arg[2]

if not sessions_file or not line then return end

-- パイプ区切りから pane_id を抽出
local pane_id = line:match("|([^|]+)$")
if not pane_id then return end

local file = io.open(sessions_file, "r")
if not file then return end

for l in file:lines() do
  if l:find('"pane_id":"' .. pane_id .. '"') then
    -- JSON を簡易パース (contentはjson_escape済みなので \" を考慮)
    local content = l:match('"content":"(.-)"}%s*$') or ""
    local workspace = l:match('"workspace":"(.-)"') or "?"
    local project = l:match('"project":"(.-)"') or "?"
    local state = l:match('"state":"(.-)"') or ""

    local state_label = ({
      working = "\x1b[38;5;209m● working\x1b[0m",
      waiting = "\x1b[38;5;221m● waiting for input\x1b[0m",
      attention = "\x1b[38;5;203m● needs attention\x1b[0m",
    })[state] or "\x1b[38;5;114m● running\x1b[0m"

    print("\x1b[38;5;141mWorkspace: " .. workspace .. "\x1b[0m")
    print("\x1b[38;5;117mProject:   " .. project .. "\x1b[0m")
    print("Status:    " .. state_label)
    print("\x1b[38;5;240m------------------------------------------------------------\x1b[0m")
    print(content:gsub("\\\\", "\\"):gsub('\\"', '"'):gsub("\\n", "\n"):gsub("\\t", "\t"))
    break
  end
end
file:close()
