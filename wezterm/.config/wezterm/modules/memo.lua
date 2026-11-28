-- 設定の読み直しをまたいで、外部コマンドの結果を覚えておく。
--   WezTerm は window:set_config_overrides のたびに wezterm.lua を最初から実行し直す。cheatbar は
--   アプリが変わるたび (nvim を開く・閉じるたび) にそれを呼ぶので、毎回コマンドを呼ぶと画面が止まって見える。
--   wezterm.GLOBAL は GUI のプロセスが終わるまで残るので、そこに JSON で入れておく。
--
--   memo.get(key, fn, { stamp = 文字列?, ttl = 秒? })
--     覚えた値が無い・stamp が変わった・ttl 秒より古いときだけ fn() を呼び直す
local wezterm = require("wezterm")
local M = {}

function M.get(key, fn, opts)
  opts = opts or {}
  local slot = "memo:" .. key
  local now = os.time()
  local raw = wezterm.GLOBAL[slot]
  if raw then
    local ok, e = pcall(wezterm.json_parse, raw)
    if ok and type(e) == "table"
      and (opts.stamp == nil or e.stamp == opts.stamp)
      and (opts.ttl == nil or now - (e.at or 0) < opts.ttl) then
      return e.value
    end
  end
  local value = fn()
  wezterm.GLOBAL[slot] = wezterm.json_encode({ value = value, stamp = opts.stamp, at = now })
  return value
end

-- ファイルの中身 (stamp 用)。無ければ空文字
function M.read(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local s = f:read("a") or ""
  f:close()
  return s
end

return M
