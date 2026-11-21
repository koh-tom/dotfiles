-- koh's personal layer — Omarchy標準のLazyVim設定と共存するstowパッケージ。
--
-- Omarchyは ~/.config/nvim をLazyVimで初期化するが、lua/plugins/ 配下の
-- 追加specはlazy.nvimが自動で読むので、このファイルだけをdotfilesから
-- symlinkすれば本体を汚さず自分の層を積める。
-- 大きくなったら koh-editor.lua / koh-lang.lua のように分割する。
--
-- テーマはOmarchyの omarchy-theme-hotreload が面倒を見るのでここでは触らない。

return {
  -- 日本語入力向けの小さな調整
  {
    "LazyVim/LazyVim",
    keys = {
      -- 日本語入力の取り回し: jjでインサート脱出
      { "jj", "<Esc>", mode = "i", desc = "Escape insert mode" },
    },
  },
}
