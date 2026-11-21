-- git の情報を、プロセスを起動せずにファイルを直接読んで得る。
-- WezTerm の Lua は GUI スレッドで動くので、git を run_child_process で呼ぶと画面が固まる
-- (Project Cockpit は zoxide の 178 ディレクトリ分 git を呼んで 0.5 秒止まっていた)。
local M = {}

local function exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function read_first_line(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local line = f:read("l")
  f:close()
  return line
end

local root_cache = {}

-- path を含む git リポジトリのルート (無ければ nil)。.git はディレクトリでもファイル (worktree) でもよい
function M.root(path)
  if not path or path == "" then return nil end
  path = path:gsub("/+$", "")
  -- 見つかったルートだけ覚える (リポジトリ外は git init / clone で変わりうるので毎回たどる。stat 数回なので軽い)
  local cached = root_cache[path]
  if cached then return cached end
  local dir = path
  while dir and dir ~= "" do
    if exists(dir .. "/.git") then
      root_cache[path] = dir
      return dir
    end
    dir = dir:match("^(.*)/[^/]*$")
  end
  return nil
end

-- 今のブランチ名。detached HEAD なら短いハッシュ、リポジトリ外なら ""
function M.branch(path)
  local root = M.root(path)
  if not root then return "" end
  local gitdir = root .. "/.git"
  local pointer = read_first_line(gitdir)
  if pointer and pointer:match("^gitdir: ") then
    -- worktree / submodule: .git ファイルが本体の場所を指す
    gitdir = pointer:gsub("^gitdir: ", "")
    if not gitdir:match("^/") then gitdir = root .. "/" .. gitdir end
  end
  local head = read_first_line(gitdir .. "/HEAD")
  if not head then return "" end
  local ref = head:match("^ref: refs/heads/(.+)$")
  if ref then return ref end
  return head:sub(1, 7)
end

return M
