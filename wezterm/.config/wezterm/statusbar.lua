local wezterm = require("wezterm")
local module = {}

-- =============================================================================
-- 定数
-- =============================================================================

local WORKSPACE_COLORS = {
  default = "#b4a7d6",    -- 通常モード（既存パレット尊重）
  copy_mode = "#ffd700",  -- コピーモード
  setting_mode = "#39FF14", -- 設定モード（後で作るリサイズモード用）
}

-- 前回の色を記録
local last_color = nil

-- =============================================================================
-- メイン処理
-- =============================================================================

function module.apply_to_config(_)
  -- ステータスバー更新（ワークスペース名表示 & カーソル色変更）
  wezterm.on("update-status", function(window, pane)
    local workspace = window:active_workspace()
    local key_table = window:active_key_table()
    local color = WORKSPACE_COLORS[key_table] or WORKSPACE_COLORS.default

    -- ワークスペース名を左ステータスに表示 (Ubuntu/Archで映えるデザイン)
    window:set_left_status(wezterm.format({
      { Background = { Color = "transparent" } },
      { Foreground = { Color = color } },
      { Text = "  " .. workspace .. "  " },
    }))

    -- カーソル色変更（OSCエスケープシーケンス）
    if last_color ~= color then
      last_color = color
      -- OSC 12 でカーソル色を動的に変更
      pane:inject_output("\x1b]12;" .. color .. "\x1b\\")
    end
  end)
end

return module
