-- AI まわり。
--   - claudecode.nvim: Claude Code の IDE 連携 (VS Code 拡張と同じ WebSocket プロトコル)。
--     選択範囲・開いているファイルを Claude に渡し、Claude の編集提案を Neovim の diff で受け取る。
--   - codediff.nvim: VS Code 風の side-by-side diff。Claude が裏で書き換えた変更を
--     そのままレビューする用 (旧 vscode-diff.nvim)。
--
-- LazyVim extras ai.claudecode と同じキー配置にしてある。
-- lazyvim.json は dotfiles 管理外なので、extras を有効化する代わりにここで spec を直接書く。
--
-- Claude Code の起動先について:
--   普段 Claude Code は WezTerm の別タブで動かしているので、Neovim 内の分割ターミナル
--   (snacks/native) ではなく provider = "external" で WezTerm の新しいタブに起動する。
--   wezterm cli spawn で作ったペインは WezTerm (mux) 側のプロセスなので、Neovim の環境変数を
--   継承しない。接続に必要な CLAUDE_CODE_SSE_PORT などは env コマンドで明示的に渡す。
--   すでに別タブで動いている claude からは /ide でこの Neovim を選べば繋がる。
--   WezTerm の外 (他の端末や SSH 先) で開いた Neovim では従来どおり snacks の分割に出す。
--
-- /ide で見つけてもらうには WebSocket サーバが起動している (lock ファイルがある) 必要があるので、
-- キーやコマンドを待たずに VeryLazy で読み込む。

local in_wezterm = vim.env.WEZTERM_PANE ~= nil and vim.fn.executable("wezterm") == 1

--- claudecode の external provider から呼ばれ、WezTerm の新しいタブで claude を起動するコマンドを返す。
---@param cmd string claude のコマンド文字列 (terminal_cmd + 引数)
---@param env table<string, string> claude に渡す環境変数
---@return string[]
local function wezterm_spawn(cmd, env)
  local argv = { "wezterm", "cli", "spawn", "--cwd", vim.fn.getcwd(), "--", "env" }
  for k, v in pairs(env) do
    table.insert(argv, k .. "=" .. v)
  end
  -- cmd は "claude --resume" のような文字列なので sh に解釈させる
  vim.list_extend(argv, { "sh", "-c", "exec " .. cmd })
  return argv
end

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    event = "VeryLazy",
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSelectModel",
      "ClaudeCodeAdd",
      "ClaudeCodeSend",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
      "ClaudeCodeStart",
      "ClaudeCodeStop",
      "ClaudeCodeOpen",
      "ClaudeCodeClose",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
      "ClaudeCodeCloseAllDiffs",
    },
    opts = {
      -- ネイティブ版インストーラの置き場所 (PATH に依存しない)
      terminal_cmd = vim.fn.expand("~/.local/bin/claude"),
      terminal = in_wezterm and {
        provider = "external",
        provider_opts = { external_terminal_cmd = wezterm_spawn },
      } or {
        provider = "snacks",
      },
    },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      -- external provider では「トグル」= WezTerm に新しいタブを開く
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
      },
      -- Claude の編集提案 (diff) を受け入れる / 却下する
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },

  -- codediff: diff 計算は C ライブラリ (libvscode_diff) だが、README のとおり
  -- 初回使用時に GitHub releases からビルド済みを自動ダウンロードするので build は不要。
  -- 手動で入れ直すときは :CodeDiff install!
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    opts = {},
    keys = {
      -- Claude が書き換えた作業ツリーの変更をまとめてレビュー
      { "<leader>av", "<cmd>CodeDiff<cr>", desc = "Review changes (CodeDiff)" },
      { "<leader>aV", "<cmd>CodeDiff history %<cr>", desc = "File history (CodeDiff)" },
    },
  },
}
