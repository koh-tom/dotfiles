-- 見た目・動きの演出。
-- smear-cursor: カーソルが移動するとき、残像が尾を引くように動く (LazyVim extras ui.smear-cursor と同じ内容)。
-- lazyvim.json は dotfiles 管理外なので、extras を有効化する代わりにここで spec を直接書く。
return {
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    cond = vim.g.neovide == nil,
    opts = {
      hide_target_hack = true,
      cursor_color = "none",
    },
  },

  -- tiny-inline-diagnostic: 診断メッセージを行末に吹き出し風で表示する。
  -- 長いメッセージは折り返し、カーソル行のものだけ詳しく出す。
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    opts = {},
  },
  -- 標準の virtual_text と二重表示にならないよう切る。
  -- LazyVim は nvim-lspconfig の opts.diagnostics を vim.diagnostic.config() に渡すので、
  -- README の LazyVim 向け手順どおりここで上書きする。
  {
    "neovim/nvim-lspconfig",
    opts = { diagnostics = { virtual_text = false } },
  },
}
