-- HDL (SystemVerilog / Verilog) のサポート。Veryl は koh-veryl.lua 側。
--   - slang-server (Hudson River Trading 製、slang ベースの SystemVerilog LSP) を有効化
--     → 診断・補完・定義ジャンプ・ホバー・階層表示など
--
-- バイナリは GitHub releases のビルド済み版を ~/.local/bin/slang-server に置いている
-- (Mason 経由にしないので mason = false)。
-- バイナリが無いマシンでは spec ごと無効化して、起動時のエラーを出さない。
--
-- nvim-lspconfig は新しい版なら lsp/slang_server.lua を同梱しているが、
-- ロック中の版にはまだ無いので cmd/filetypes/root_markers をここで定義する
-- (中身は upstream の lsp/slang_server.lua と同じ)。
-- プロジェクト単位の設定 (インクルードパス、define、トップモジュールなど) は
-- リポジトリ直下の .slang/server.json に書く。
--   https://hudson-trading.github.io/slang-server/start/config/

local has_slang = vim.fn.executable("slang-server") == 1

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        slang_server = has_slang and {
          mason = false,
          cmd = { "slang-server" },
          filetypes = { "systemverilog", "verilog" },
          -- .git と .slang は同じ優先度で探す (nvim 0.11.3 以降の入れ子 root_markers)
          root_markers = { { ".git", ".slang" } },
        } or nil,
      },
    },
  },
}
