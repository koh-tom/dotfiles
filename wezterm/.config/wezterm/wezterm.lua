local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- =============================================================================
-- 一般設定
-- =============================================================================

-- 設定変更を自動リロード
config.automatically_reload_config = true

-- Omarchyの現在フォントを使用し、取得できない場合はNerd Fontへフォールバック
config.font_size = 12.0
local font_name = "JetBrainsMono Nerd Font"
local font_ok, font_stdout = wezterm.run_child_process({ "omarchy", "font", "current" })
if font_ok and font_stdout and font_stdout:match("%S") then
	font_name = font_stdout:gsub("%s+$", "")
end
config.font = wezterm.font_with_fallback({ font_name, "JetBrainsMono Nerd Font", "JetBrains Mono" })

-- 斜体 (コメント等) だけ手書き風の Monaspace Radon にする。未インストールなら通常の斜体のまま
-- (pacman -S otf-monaspace)。require内ではrun_child_processが使えないのでここで判定する
local radon_ok, radon_out = wezterm.run_child_process({ "fc-list", "Monaspace Radon" })
if radon_ok and radon_out:match("%S") then
	config.font_rules = {
		{
			italic = true,
			intensity = "Normal",
			font = wezterm.font_with_fallback({
				{ family = "Monaspace Radon", style = "Italic" },
				{ family = font_name, style = "Italic" },
			}),
		},
		{
			italic = true,
			intensity = "Bold",
			font = wezterm.font_with_fallback({
				{ family = "Monaspace Radon", weight = "Bold", style = "Italic" },
				{ family = font_name, weight = "Bold", style = "Italic" },
			}),
		},
	}
end

-- 描画: GPU (WebGpu) で高リフレッシュレートに追従させ、スクロールやアニメーションを滑らかにする
config.front_end = "WebGpu"
config.webgpu_power_preference = "LowPower" -- ノートの内蔵GPUで十分。電池優先
config.max_fps = 120
config.animation_fps = 60
config.cursor_blink_ease_in = "EaseOut"
config.cursor_blink_ease_out = "EaseOut"

-- Linux環境設定
-- wezterm 20240203 (安定版) はHyprlandのWaylandでウィンドウが表示されない既知問題がある。
-- バージョンから自動判定し、nightly (wezterm-nightly-bin) ならWaylandネイティブで起動する
local wez_build_date = tonumber(wezterm.version:match("^(%d+)")) or 0
config.enable_wayland = wez_build_date > 20240203
config.use_ime = true

-- 透明度 (設定モードで後で可変にするがデフォルトは0.9前後を目標)
-- 非フォーカス時の透過度
config.window_background_opacity = 0.82 -- 実際は modules/opacity.lua (背景レイヤー) が決める

-- ステータスバー更新間隔 (1500msに変更して効率化)
config.status_update_interval = 1500

-- =============================================================================
-- $PATH 同期 (mise shims + local bin) — ベストプラクティス構成
-- =============================================================================
local home = wezterm.home_dir
config.set_environment_variables = {
	PATH = table.concat({
		home .. "/.local/share/mise/shims",
		home .. "/.local/bin",
		"/usr/local/bin",
		"/usr/bin",
		"/bin",
		os.getenv("PATH") or "",
	}, ":"),
}

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
require("omarchy_theme").apply_to_config(config)
require("tab").apply_to_config(config)
require("statusbar").apply_to_config(config)
require("keymaps").apply_to_config(config)
require("workspace").apply_to_config(config)

-- 拡張モジュールの読み込み
require("modules.opacity").apply_to_config(config)
require("modules.claude_session").apply_to_config(config)
require("modules.project_cockpit").apply_to_config(config)
local function has_command(name)
	local ok = wezterm.run_child_process({ "sh", "-lc", "command -v " .. wezterm.shell_quote_arg(name) })
	return ok
end

if has_command("aws") then
	require("modules.aws_profile").apply_to_config(config)
end
if has_command("plamo-translate") then
	require("modules.translate").apply_to_config(config)
end
require("modules.colorscheme").apply_to_config(config)
require("modules.smart_open").apply_to_config(config)
require("modules.cheatbar").apply_to_config(config)
require("modules.background").apply_to_config(config)
-- ドロップダウン端末 (scripts/wezterm-dropdown) は別プロセスなので、
-- セッション復元でタブが全部開いたり、メインのセッションを上書きしたりしないよう外す
if not os.getenv("WEZTERM_DROPDOWN") then
	require("modules.session").apply_to_config(config)
end
require("modules.notify").apply_to_config(config)
require("modules.hyperlinks").apply_to_config(config)
-- config.keys を参照するので最後に読む
require("modules.palette").apply_to_config(config)

return config
