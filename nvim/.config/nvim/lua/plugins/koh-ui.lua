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
}
