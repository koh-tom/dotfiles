local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- =============================================================================
-- 一般設定
-- =============================================================================

-- 設定変更を自動リロード
config.automatically_reload_config = true

-- フォント設定 (Ubuntu/ArchでJetBrains MonoまたはNF推奨)
config.font_size = 12.0
config.font = wezterm.font("JetBrains Mono")

-- Linux環境設定
config.enable_wayland = false -- X11環境を優先する場合

-- 透明度 (設定モードで後で可変にするがデフォルトは0.9前後を目標)
-- 非フォーカス時の透過度
config.window_background_opacity = 0.9

-- ステータスバー更新間隔 (1500msに変更して効率化)
config.status_update_interval = 1500

-- =============================================================================
-- QuickSelect patterns (SUPER + Space等で利用)
-- =============================================================================
config.disable_default_quick_select_patterns = true
config.quick_select_patterns = {
  -- URL
  "\\bhttps?://[\\w\\-._~:/?#@!$&'()*+,;=%]+",
  -- AWS ARN
  "\\barn:[\\w\\-]+:[\\w\\-]+:[\\w\\-]*:[0-9]*:[\\w\\-/:]+",
  -- ファイルパス: スペース・記号の後にあるもののみ（プロンプト除外）
  "(?<=[\\s:=(\"'`])(?:~|/)[/\\w\\-.@~]+",
  -- ファイルパス: 行頭かつ行末まで（pwd出力など）
  "(?m)^(?:~|/)[/\\w\\-.@~]+(?=\\s*$)",
  -- Git commit hash (7-40 chars)
  "\\b[0-9a-f]{7,40}\\b",
  -- IP address
  "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
}

-- =============================================================================
-- モジュール読み込み
-- =============================================================================

require("appearance").apply_to_config(config)
require("tab").apply_to_config(config)
require("statusbar").apply_to_config(config)

-- Phase 2で keymaps や workspace をここに追加します

return config
