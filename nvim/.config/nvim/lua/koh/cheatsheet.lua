-- nvim の操作の早見表 (日本語)。F1 で開く・閉じる (q / Esc でも閉じる)。
-- 載せているのは LazyVim の既定のキーと、dotfiles で足したキー (jj, <Space>a…)。
-- キーを足したらここにも書く。Space を押して待つと出る一覧 (which-key) は全部のキーが出る。
local M = {}

-- { 見出し, { { キー, 説明 }, ... } }
local SECTIONS = {
  { "モード", {
    { "i / a", "カーソルの前 / 後ろから入力" },
    { "o / O", "下 / 上に行を作って入力" },
    { "Esc / jj", "入力をやめる (ノーマルモードへ)" },
    { "v / V", "文字 / 行を選ぶ" },
    { "Ctrl+v", "四角く選ぶ (複数行に同時入力は I)" },
    { ":", "コマンドを打つ" },
  } },
  { "移動", {
    { "h j k l", "← ↓ ↑ →" },
    { "w / b / e", "次の単語 / 前の単語 / 単語の終わり" },
    { "0 / ^ / $", "行頭 / 最初の文字 / 行末" },
    { "gg / G", "ファイルの先頭 / 最後" },
    { "数字 G", "その行へ (例: 42G)" },
    { "Ctrl+d / u", "半画面 下 / 上" },
    { "f 文字", "その文字まで右へ (; で次)" },
    { "%", "対応する括弧へ" },
    { "s", "画面のどこへでも跳ぶ (flash)" },
  } },
  { "編集", {
    { "x", "1 文字消す" },
    { "dd / yy", "行を切り取る / コピー" },
    { "p / P", "後ろ / 前に貼る" },
    { "u / Ctrl+r", "元に戻す / やり直す" },
    { ".", "直前の操作をもう一度" },
    { "ciw", "単語を消して入力 (ci\" で \"…\" の中)" },
    { "> / <", "選んだ行をずらす (ノーマルでは >>)" },
    { "gcc", "行をコメントにする / 戻す (選んで gc)" },
  } },
  { "検索・置換", {
    { "/ 文字", "下へ検索 (n 次 / N 前)" },
    { "*", "カーソルの単語を検索" },
    { ":%s/a/b/g", "ファイル全体の a を b に" },
    { "Space s r", "複数ファイルで検索・置換" },
    { "Esc", "検索の色を消す" },
  } },
  { "ファイル", {
    { "Space Space", "ファイルを名前で探して開く" },
    { "Space /", "全ファイルから文字を探す" },
    { "Space e", "ファイルの一覧 (左)" },
    { "Space f r", "最近開いたファイル" },
    { "H / L", "前 / 次のタブ (バッファ)" },
    { "Space b d", "今のタブを閉じる" },
    { ":w / Ctrl+s", "保存" },
    { "Space q q", "全部閉じて終わる" },
  } },
  { "画面の分割", {
    { "Space |", "左右に分ける" },
    { "Space -", "上下に分ける" },
    { "Ctrl+h j k l", "分けた画面の間を移動" },
    { "Space w d", "今の画面を閉じる" },
  } },
  { "コード", {
    { "gd", "定義へ跳ぶ (Ctrl+o で戻る)" },
    { "gr", "使っている場所の一覧" },
    { "K", "説明を出す" },
    { "Space c a", "直し方の候補 (コードアクション)" },
    { "Space c r", "名前を全部まとめて変える" },
    { "Space c f", "整形する" },
    { "] d / [ d", "次 / 前のエラー・警告" },
    { "Space x x", "エラーの一覧" },
  } },
  { "Git", {
    { "Space g g", "lazygit を開く" },
    { "] h / [ h", "次 / 前の変更箇所" },
    { "Space g b", "この行を書いた人と日時" },
  } },
  { "Claude (dotfiles で追加)", {
    { "Space a c", "Claude を開く / 閉じる" },
    { "Space a s", "選んだ部分を Claude に送る" },
    { "Space a b", "このファイルを Claude に渡す" },
    { "Space a a / a d", "Claude の変更を受け入れる / 断る" },
    { "Space a v", "変更をまとめて見る (CodeDiff)" },
  } },
  { "困ったとき", {
    { "F1", "この早見表" },
    { "Space (待つ)", "使えるキーの一覧が出る" },
    { "Space s k", "全部のキーから探す" },
    { "Space l", "プラグインの管理 (Lazy)" },
    { ":q!", "保存せずに閉じる" },
  } },
}

local KEY_W = 16 -- キーの欄の幅 (表示幅)
local GAP = 4 -- 段の間

local function pad(s, w)
  return s .. string.rep(" ", math.max(0, w - vim.fn.strdisplaywidth(s)))
end

-- 見出しごとの塊を作る: 行の文字列と、色を付ける範囲
local function block(section, width)
  local lines = { { text = section[1], hl = "Title" } }
  for _, item in ipairs(section[2]) do
    lines[#lines + 1] = { text = pad(item[1], KEY_W) .. item[2], key_len = #item[1] }
  end
  lines[#lines + 1] = { text = "" }
  for _, l in ipairs(lines) do l.text = pad(l.text, width) end
  return lines
end

-- 画面の幅に合わせて 1〜3 段に並べる
local function layout(max_w)
  local col_w = 0
  for _, s in ipairs(SECTIONS) do
    col_w = math.max(col_w, vim.fn.strdisplaywidth(s[1]))
    for _, item in ipairs(s[2]) do
      col_w = math.max(col_w, KEY_W + vim.fn.strdisplaywidth(item[2]))
    end
  end
  local ncol = math.max(1, math.min(3, math.floor((max_w + GAP) / (col_w + GAP))))

  -- 行数がそろうように、上から順に段へ詰める
  local blocks, total = {}, 0
  for _, s in ipairs(SECTIONS) do
    local b = block(s, col_w)
    blocks[#blocks + 1] = b
    total = total + #b
  end
  local target = math.ceil(total / ncol)
  local columns, cur = { {} }, {}
  columns[1] = cur
  for _, b in ipairs(blocks) do
    if #cur > 0 and #cur + #b > target and #columns < ncol then
      cur = {}
      columns[#columns + 1] = cur
    end
    for _, l in ipairs(b) do cur[#cur + 1] = l end
  end

  local height = 0
  for _, c in ipairs(columns) do height = math.max(height, #c) end
  local out, marks = {}, {}
  for row = 1, height do
    local parts, byte = {}, 0
    for ci, c in ipairs(columns) do
      local l = c[row] or { text = pad("", col_w) }
      if l.hl then marks[#marks + 1] = { row - 1, byte, byte + #l.text, l.hl } end
      if l.key_len then marks[#marks + 1] = { row - 1, byte, byte + l.key_len, "Special" } end
      parts[#parts + 1] = l.text
      byte = byte + #l.text
      if ci < #columns then
        parts[#parts + 1] = string.rep(" ", GAP)
        byte = byte + GAP
      end
    end
    out[#out + 1] = (table.concat(parts):gsub("%s+$", ""))
  end
  return out, marks, ncol * col_w + (ncol - 1) * GAP
end

local state = { win = nil }

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.open()
  local lines, marks, width = layout(vim.o.columns - 6)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ns = vim.api.nvim_create_namespace("koh_cheatsheet")
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = math.min(m[3], #lines[m[1] + 1]), hl_group = m[4] })
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local height = math.min(#lines, vim.o.lines - 4)
  state.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(width, vim.o.columns - 4),
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " nvim 早見表 ",
    title_pos = "center",
    footer = " F1 / q / Esc で閉じる   j k でスクロール ",
    footer_pos = "center",
  })
  vim.wo[state.win].wrap = false
  for _, key in ipairs({ "q", "<Esc>", "<F1>" }) do
    vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true, silent = true })
  end
  -- ほかの窓へ移ったら閉じる
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = M.close })
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  else
    if vim.fn.mode() ~= "n" then vim.cmd("stopinsert") end
    vim.schedule(M.open)
  end
end

return M
