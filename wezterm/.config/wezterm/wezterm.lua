local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- 設定変更を自動リロード
config.automatically_reload_config = true

-- フォント設定
config.font_size = 12.0
config.font = wezterm.font("JetBrains Mono")

-- hyprlad環境
config.enable_wayland = false

-- 透明度
config.window_background_opacity = 0.5

-- ステータスバー更新
config.status_update_interval = 1000

-- 各モジュールの読み込み
require("theme").apply_to_config(config)

return config
