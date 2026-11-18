-- Veryl (ハードウェア記述言語) のサポート。
--   - 拡張子 .veryl を filetype "veryl" にする (Neovim 本体は未対応)
--   - nvim-treesitter に公式 tree-sitter-veryl を登録 → シンタックスハイライト
--   - veryl-ls (veryl に同梱、~/.local/bin) を LSP として有効化 → 診断・補完・定義ジャンプ
--
-- tree-sitter-veryl は nvim-treesitter の標準リストに無いので、TSUpdate イベントで追加する。
-- このイベントは nvim-treesitter の setup 中に発火するため、登録は init (setup より前) で行う。

vim.filetype.add({ extension = { veryl = "veryl" } })

return {
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          require("nvim-treesitter.parsers").veryl = {
            install_info = {
              url = "https://github.com/veryl-lang/tree-sitter-veryl",
              revision = "f38156e6fa97e7386cdfbcbcc537dc970a13c3ce",
              queries = "queries",
            },
            tier = 3,
          }
        end,
      })
    end,
    opts = { ensure_installed = { "veryl" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Mason 版ではなく、veryl 本体と同じ版の ~/.local/bin/veryl-ls を使う
        veryl_ls = { mason = false },
      },
    },
  },
}
