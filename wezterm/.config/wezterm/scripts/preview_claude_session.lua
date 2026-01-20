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
    -- JSON を簡易パース
    local content = l:match('"content":"(.-)"')
    local workspace = l:match('"workspace":"(.-)"')
    local project = l:match('"project":"(.-)"')
    
    print("\x1b[38;5;141mWorkspace: " .. workspace .. "\x1b[0m")
    print("\x1b[38;5;117mProject:   " .. project .. "\x1b[0m")
    print("\x1b[38;5;240m------------------------------------------------------------\x1b[0m")
    print(content:gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\t", "\t"):gsub('\\"', '"'))
    break
  end
end
file:close()
