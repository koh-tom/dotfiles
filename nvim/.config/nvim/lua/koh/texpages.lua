-- tex を PDF にしたときの長さを「6.8 ページ」のように出す (最後のページがどれだけ埋まったかを小数で)。
-- ページ制限があれば「6.8/8p 85%」。lualine に出す (lua/plugins/koh-tex.lua)。
-- 毎回ビルドはしない: 最後にビルドした PDF の正確な値と、そのときの文字量を覚えておき、
-- 打っている間は文字量の増減から推定する (先頭に ~)。ビルドすると正確な値に戻る。
--
-- 正確な値: コンパイル方法には依存しない。PDF の更新を見張り、変わったら poppler の pdfinfo と
-- pdftotext -bbox で最後のページと1つ前のページの文字の位置を読み、本文の領域に対して
-- 最後のページの本文がどこまで来ているかを測る。2段組は左右の段を別々に測って平均する。
-- ヘッダ・フッタ (ページ番号など) は、本文から離れて孤立した短い行として除く。
-- 文字の無い図だけが最後のページの下にある場合などは測れない (目安として使う)。
--
-- ページ制限は tex の先頭 50 行のどこかに書く:   % pagelimit: 8
-- 分割したファイルでは vimtex と同じ書き方で親を指す:   %! TEX root = main.tex
local M = {}

local uv = vim.uv or vim.loop

-- 結果のキャッシュ (PDF のパス → { mtime, text, pages, limit })
local cache = {}

---------------------------------------------------------------------------
-- PDF の解析 (純粋な関数。テストしやすいように外に出す)
---------------------------------------------------------------------------

-- pdftotext -bbox の出力 (1ページ分) から、ページの幅・高さと単語の箱を取り出す
function M.parse_page(html)
  local w, h = html:match('<page width="([%d%.]+)" height="([%d%.]+)"')
  local words = {}
  for x1, y1, x2, y2, text in html:gmatch('<word xMin="([%d%.]+)" yMin="([%d%.]+)" xMax="([%d%.]+)" yMax="([%d%.]+)">(.-)</word>') do
    words[#words + 1] = { x1 = tonumber(x1), y1 = tonumber(y1), x2 = tonumber(x2), y2 = tonumber(y2), text = text }
  end
  return { w = tonumber(w) or 0, h = tonumber(h) or 0, words = words }
end

-- 単語を行にまとめる (下端の y が近いものを同じ行とする)。y の小さい順 (上から)
local function lines_of(words)
  local sorted = vim.deepcopy(words)
  table.sort(sorted, function(a, b) return a.y2 < b.y2 end)
  local lines = {}
  for _, wd in ipairs(sorted) do
    local last = lines[#lines]
    if last and math.abs(wd.y2 - last.y2) < 2 then
      last.y1 = math.min(last.y1, wd.y1)
      last.x1 = math.min(last.x1, wd.x1)
      last.x2 = math.max(last.x2, wd.x2)
      last.n = last.n + 1
    else
      lines[#lines + 1] = { y1 = wd.y1, y2 = wd.y2, x1 = wd.x1, x2 = wd.x2, n = 1 }
    end
  end
  return lines
end

local function median(t)
  if #t == 0 then return 0 end
  local s = vim.deepcopy(t)
  table.sort(s)
  return s[math.ceil(#s / 2)]
end

-- ヘッダ・フッタを除いた本文の行。本文から大きく離れた、ページ幅の 1/3 未満の短い行を落とす
local function body_lines(page)
  local lines = lines_of(page.words)
  if #lines < 3 then return lines end
  local gaps = {}
  for i = 2, #lines do gaps[#gaps + 1] = lines[i].y2 - lines[i - 1].y2 end
  local step = math.max(median(gaps), 6)
  local function short(l) return (l.x2 - l.x1) < page.w / 3 end
  -- 下から (フッタ)
  while #lines >= 3 do
    local l, prev = lines[#lines], lines[#lines - 1]
    if short(l) and (l.y2 - prev.y2) > step * 2.5 then table.remove(lines) else break end
  end
  -- 上から (ヘッダ)
  while #lines >= 3 do
    local l, nxt = lines[1], lines[2]
    if short(l) and (nxt.y2 - l.y2) > step * 2.5 then table.remove(lines, 1) else break end
  end
  return lines
end

-- 2段組か: 中央をまたぐ行がほとんど無く、左右どちらにも十分な行がある
local function is_two_column(page, lines)
  local mid = page.w / 2
  local cross, left, right = 0, 0, 0
  for _, wd in ipairs(page.words) do
    if wd.x1 < mid - 3 and wd.x2 > mid + 3 then cross = cross + 1
    elseif wd.x2 <= mid + 3 then left = left + 1
    else right = right + 1 end
  end
  local total = cross + left + right
  if total < 40 or #lines < 5 then return false end
  return cross / total < 0.03 and left / total > 0.2 and right / total > 0.2
end

-- 本文の上端・下端 (参照ページ = 埋まっているはずのページから)
local function text_area(page)
  local lines = body_lines(page)
  if #lines == 0 then
    -- 文字が無ければ上下 1 インチの余白とみなす
    return 72, page.h - 72
  end
  return lines[1].y1, lines[#lines].y2
end

-- 最後のページの埋まり具合 (0〜1)
-- ref: 最後の1つ前のページ (1ページしか無いときは nil)
function M.last_page_fill(last, ref)
  local top, bottom
  if ref and #ref.words > 0 then
    top, bottom = text_area(ref)
  else
    top, bottom = text_area(last)
    -- 1ページだけのときは本文の下端が分からないので、下余白 1 インチを仮定する
    bottom = math.max(bottom, last.h - 72)
  end
  local height = bottom - top
  if height <= 0 then return 0 end
  local lines = body_lines(last)
  if #lines == 0 then return 0 end
  local function fill_of(ls)
    local lowest = top
    for _, l in ipairs(ls) do
      -- 本文の範囲の外 (ページ番号・ヘッダ) は数えない
      if l.y1 <= bottom + 2 and l.y2 >= top - 2 then lowest = math.max(lowest, l.y2) end
    end
    return math.min(math.max((lowest - top) / height, 0), 1)
  end
  local two = is_two_column(ref or last, body_lines(ref or last))
  if not two then return fill_of(lines) end
  -- 2段組: 単語を左右に分けて、それぞれの段の埋まり具合を平均する
  local mid = last.w / 2
  local lw, rw = {}, {}
  for _, wd in ipairs(last.words) do
    if (wd.x1 + wd.x2) / 2 < mid then lw[#lw + 1] = wd else rw[#rw + 1] = wd end
  end
  local function col_fill(ws)
    if #ws == 0 then return 0 end
    return fill_of(body_lines({ w = last.w, h = last.h, words = ws }))
  end
  return (col_fill(lw) + col_fill(rw)) / 2
end

---------------------------------------------------------------------------
-- tex のファイルから PDF とページ制限を探す
---------------------------------------------------------------------------

local function head_lines(path, n)
  local ok, lines = pcall(vim.fn.readfile, path, "", n)
  return ok and lines or {}
end

-- 親の tex (%! TEX root = ...) をたどる
function M.root_of(path)
  for _, line in ipairs(head_lines(path, 50)) do
    local root = line:match("^%%%s*!%s*[Tt][Ee][Xx]%s+root%s*=%s*(.-)%s*$")
    if root and root ~= "" then
      local p = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(path), root))
      if not p:match("%.tex$") then p = p .. ".tex" end
      if uv.fs_stat(p) then return p end
    end
  end
  return path
end

function M.page_limit(root)
  for _, line in ipairs(head_lines(root, 50)) do
    local n = line:match("^%%%s*[Pp]age%s*[Ll]imit%s*[:=]%s*([%d%.]+)")
    if n then return tonumber(n) end
  end
  return vim.g.tex_page_limit
end

-- PDF の候補 (いちばん新しいもの)。latexmk の out_dir でよく使う場所も見る
function M.pdf_of(root)
  local dir, base = vim.fs.dirname(root), vim.fn.fnamemodify(root, ":t:r")
  local best, best_t
  for _, sub in ipairs({ "", "build", "out", "_build", "output" }) do
    local p = sub == "" and vim.fs.joinpath(dir, base .. ".pdf") or vim.fs.joinpath(dir, sub, base .. ".pdf")
    local st = uv.fs_stat(p)
    if st and (not best_t or st.mtime.sec > best_t) then best, best_t = p, st.mtime.sec end
  end
  return best
end

---------------------------------------------------------------------------
-- 文字量 (ビルドせずに推定するための目安)
---------------------------------------------------------------------------

-- 本文の文字量。コメント・コマンド名・記号を除き、空白は数えない。
-- 全角 (日本語など) は半角 2 文字分の幅として数える。
function M.weight(text)
  local n = 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local s = line:gsub("\\%%", "\1")      -- \% はコメントではない
    s = s:gsub("%%.*$", "")                 -- コメント
    s = s:gsub("\\[%a@]+%*?", "")           -- \section などのコマンド名
    s = s:gsub("[{}%[%]$&~^_\\%s]", "")     -- 記号と空白
    local ascii = s:gsub("[\128-\255]", "")
    local lead = s:gsub("[^\192-\255]", "") -- 多バイト文字の先頭バイト = 文字数
    n = n + #ascii + 2 * #lead
  end
  return n
end

local function strip_comments(text)
  return (text:gsub("\\%%", "\1"):gsub("%%[^\n]*", ""))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local t = f:read("*a")
  f:close()
  return t
end

-- 開いているバッファがあればその中身 (保存前も含む)、無ければディスク
local function live_text(path)
  local buf = vim.fn.bufnr(path)
  if buf > 0 and vim.api.nvim_buf_is_loaded(buf) then
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  end
  return read_file(path)
end

-- 親から \input / \include / \subfile / \import でつながる tex ファイル (親を含む)
function M.files(root, text_of)
  text_of = text_of or read_file
  local seen, order = {}, {}
  local function add(path)
    path = vim.fs.normalize(path)
    if not path:match("%.tex$") and not uv.fs_stat(path) then path = path .. ".tex" end
    if seen[path] or not uv.fs_stat(path) then return end
    seen[path] = true
    order[#order + 1] = path
    local text = text_of(path)
    if not text then return end
    text = strip_comments(text)
    local base = vim.fs.dirname(root)
    for name in text:gmatch("\\input%s*{([^}]+)}") do add(vim.fs.joinpath(base, name)) end
    for name in text:gmatch("\\include%s*{([^}]+)}") do add(vim.fs.joinpath(base, name)) end
    for name in text:gmatch("\\subfile%s*{([^}]+)}") do add(vim.fs.joinpath(base, name)) end
    for dir, name in text:gmatch("\\s?u?b?import%s*{([^}]*)}%s*{([^}]+)}") do
      add(vim.fs.joinpath(base, dir, name))
    end
  end
  add(root)
  return order
end

-- プロジェクト全体の文字量。live = true なら開いているバッファの中身 (保存前) を使う
function M.project_weight(root, live)
  local text_of = live and live_text or read_file
  local total = 0
  for _, path in ipairs(M.files(root, text_of)) do
    local t = text_of(path)
    if t then total = total + M.weight(t) end
  end
  return total
end

---------------------------------------------------------------------------
-- キャッシュ (PDF のパス → { mtime, pages, chars })。nvim を開き直しても使えるようファイルにも保存
---------------------------------------------------------------------------

local store = vim.fn.stdpath("cache") .. "/koh-texpages.json"

local function load_store()
  local t = read_file(store)
  local ok, data = pcall(vim.json.decode, t or "")
  if ok and type(data) == "table" then
    for pdf, e in pairs(data) do cache[pdf] = e end
  end
end

local function save_store()
  vim.fn.mkdir(vim.fs.dirname(store), "p")
  local f = io.open(store, "w")
  if f then
    f:write(vim.json.encode(cache))
    f:close()
  end
end

local function refresh_bar()
  vim.schedule(function()
    local ok, lualine = pcall(require, "lualine")
    if ok then lualine.refresh() end
  end)
end

---------------------------------------------------------------------------
-- PDF を非同期で測る (更新されたときだけ)
---------------------------------------------------------------------------

local running = {}

local function measure(pdf, mtime, root)
  if running[pdf] then return end
  running[pdf] = true
  -- ビルドしたときの文字量 = いまディスクにある tex の文字量 (保存してからビルドするので)
  local chars = M.project_weight(root, false)
  local function done(entry)
    running[pdf] = nil
    if entry then
      vim.schedule(function()
        cache[pdf] = entry
        save_store()
      end)
      refresh_bar()
    end
  end
  vim.system({ "pdfinfo", pdf }, { text = true }, function(info)
    local n = tonumber((info.stdout or ""):match("Pages:%s+(%d+)"))
    if info.code ~= 0 or not n or n == 0 then return done(nil) end
    local first = math.max(n - 1, 1)
    vim.system({ "pdftotext", "-bbox", "-f", tostring(first), "-l", tostring(n), pdf, "-" }, { text = true }, function(r)
      if r.code ~= 0 then return done(nil) end
      local pages = {}
      for chunk in (r.stdout or ""):gmatch("<page .-</page>") do pages[#pages + 1] = M.parse_page(chunk) end
      local last = pages[#pages]
      if not last then return done(nil) end
      local ref = (n > 1 and #pages >= 2) and pages[#pages - 1] or nil
      local fill = M.last_page_fill(last, ref)
      done({ mtime = mtime, pages = (n - 1) + fill, chars = chars })
    end)
  end)
end

---------------------------------------------------------------------------
-- 表示
---------------------------------------------------------------------------

-- いまのページ数: ビルドしたときの値 + (いまの文字量 - そのときの文字量) / 1ページあたりの文字量
-- 戻り値: ページ数, 推定かどうか
function M.estimate(buf)
  local b = vim.b[buf or 0].koh_texpages
  local e = b and b.pdf and cache[b.pdf]
  if not e then return nil end
  if not (b.now and e.chars and e.chars > 0 and e.pages > 0) or b.now == e.chars then
    return e.pages, false
  end
  local per_page = e.chars / e.pages
  return math.max(e.pages + (b.now - e.chars) / per_page, 0), true
end

function M.status()
  local pages, approx = M.estimate()
  if not pages then return "" end
  local limit = vim.b.koh_texpages.limit
  local s = (approx and "~" or "") .. string.format("%.1f", pages)
  if limit then
    s = string.format("%s/%gp %d%%", s, limit, math.floor(pages / limit * 100 + 0.5))
  else
    s = s .. "p"
  end
  return "󰈙 " .. s
end

-- 色: 制限を超えたら赤、9割を超えたら黄
function M.color()
  local pages = M.estimate()
  local limit = vim.b.koh_texpages and vim.b.koh_texpages.limit
  if not (pages and limit) then return nil end
  if pages > limit then return { fg = "#f38ba8" } end
  if pages > limit * 0.9 then return { fg = "#f9e2af" } end
  return nil
end

---------------------------------------------------------------------------
-- 更新
---------------------------------------------------------------------------

-- バッファの PDF を確かめて、更新されていれば測り直す (軽い。2 秒ごとに呼ぶ)
function M.check(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "tex" then return end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then return end
  local root = M.root_of(path)
  local pdf = M.pdf_of(root)
  local b = vim.b[buf].koh_texpages or {}
  b.root, b.pdf, b.limit = root, pdf, M.page_limit(root)
  vim.b[buf].koh_texpages = b
  if not pdf then return end
  local st = uv.fs_stat(pdf)
  if not st then return end
  local e = cache[pdf]
  if e and e.mtime == st.mtime.sec then return end
  measure(pdf, st.mtime.sec, root)
end

-- いまの文字量を数え直す (打っている間、少し間をおいて呼ぶ)
function M.recount(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local b = vim.api.nvim_buf_is_valid(buf) and vim.b[buf].koh_texpages
  if not (b and b.root) then return end
  b.now = M.project_weight(b.root, true)
  vim.b[buf].koh_texpages = b
  refresh_bar()
end

function M.setup()
  if vim.fn.executable("pdftotext") ~= 1 or vim.fn.executable("pdfinfo") ~= 1 then return end
  load_store()
  local group = vim.api.nvim_create_augroup("koh_texpages", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
    group = group,
    callback = function(ev)
      M.check(ev.buf)
      M.recount(ev.buf)
    end,
  })
  -- 打っている間: 最後の入力から 300ms たったら数え直す (ビルドはしない)
  local debounce = uv.new_timer()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype ~= "tex" then return end
      debounce:stop()
      debounce:start(300, 0, vim.schedule_wrap(function() M.recount(ev.buf) end))
    end,
  })
  -- ビルドは保存のあと少し遅れて終わるので、tex を開いている間は 2 秒ごとに PDF の更新を見る
  local timer = uv.new_timer()
  timer:start(2000, 2000, vim.schedule_wrap(function()
    if vim.bo.filetype == "tex" then M.check() end
  end))
  -- :TexPages  いまの PDF をすぐ測り直す
  vim.api.nvim_create_user_command("TexPages", function()
    local b = vim.b.koh_texpages
    if b and b.pdf then cache[b.pdf] = nil end
    M.check()
    M.recount()
  end, { desc = "PDF のページ数を測り直す" })
end

return M
