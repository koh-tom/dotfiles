-- tex を開いているとき、PDF にした長さを下のバー (lualine) に出す。例: 󰈙 6.8/8p 85%
-- 測り方とページ制限の書き方は lua/koh/texpages.lua。PDF を作るのは今までどおり (latexmk など何でもよい)。
-- poppler (pdfinfo / pdftotext) が無いマシンでは何もしない。
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local tex = require("koh.texpages")
      tex.setup()
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}
      table.insert(opts.sections.lualine_x, 1, {
        tex.status,
        cond = function() return vim.bo.filetype == "tex" end,
        color = tex.color,
      })
    end,
  },
}
