local wezterm = require("wezterm")
local module = {}

-- コマンドパレット (Ctrl+Shift+P) に自作操作を説明付きで追加する。
-- 動作は config.keys に登録済みの LEADER バインドをそのまま流用するので、
-- キー側を変えてもパレットが追従する。全モジュール読み込み後に apply すること。

local ENTRIES = {
  { key = "g", brief = "Project: プロジェクトを開く (zoxide → workspace)", icon = "md_folder_star" },
  { key = "c", brief = "Claude: セッション切替", icon = "md_robot" },
  { key = "l", brief = "Launch: Lazygit / Neovim / Yazi / btop ...", icon = "md_rocket_launch" },
  { key = "w", brief = "Workspace: 一覧から切替", icon = "md_view_dashboard" },
  { key = "z", brief = "Copy: 直前のコマンドと出力をコピー", icon = "md_content_copy" },
  { key = "b", brief = "Scrollback: Neovim で開く", icon = "md_text_box_search" },
  { key = "o", brief = "Smart Open: URL / パス / ハッシュを選んで開く", icon = "md_open_in_app" },
  { key = ",", brief = "Tab: 名前を変更", icon = "md_rename_box" },
  { key = "q", brief = "Tab: 閉じる (SUPER+W は Hyprland がウィンドウごと閉じる)", icon = "md_close_box" },
  { key = "i", brief = "Background: 壁紙を敷く/外す", icon = "md_image" },
  { key = "t", brief = "Color scheme: 一時的に切替", icon = "md_palette" },
  { key = "p", brief = "AWS: プロファイル選択", icon = "md_aws" },
  { key = "S", mods = "LEADER|SHIFT", brief = "Session: 手動保存", icon = "md_content_save" },
  { key = "n", brief = "Tip: 次の tip を表示", icon = "md_lightbulb_on" },
  { key = "/", brief = "Cheatsheet: キー・スニペット一覧", icon = "md_help_circle" },
  { key = "s", brief = "Resize mode: ペインサイズ調整", icon = "md_resize" },
}

local function find_action(keys, key, mods)
  for _, k in ipairs(keys or {}) do
    if k.key == key and k.mods == mods then return k.action end
  end
end

function module.apply_to_config(config)
  local commands = {}
  for _, e in ipairs(ENTRIES) do
    local action = find_action(config.keys, e.key, e.mods or "LEADER")
    if action then
      -- 存在しないnerdfont名を渡すとパレット描画でエラーになるので事前に確認する
      local ok, glyph = pcall(function() return wezterm.nerdfonts[e.icon] end)
      commands[#commands + 1] = {
        brief = e.brief .. "   (^Q " .. e.key .. ")",
        icon = (ok and glyph) and e.icon or nil,
        action = action,
      }
    end
  end

  wezterm.on("augment-command-palette", function()
    return commands
  end)
end

return module
