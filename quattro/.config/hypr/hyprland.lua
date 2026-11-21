-- Omarchy 4 (Quattro) 用 Hyprland 設定のエントリポイント (dotfiles: quattro/)
--
-- 移植元: ~/.config/hypr/hyprland.conf (Omarchy 3.8.1 / Hyprland 0.56 の .conf 構成)。
-- .conf 側は消さずに残してある。対応表と検証は tests/quattro-parity/ を参照。
--
-- 構造は上流テンプレート (config/hypr/hyprland.lua @ v4.5.0) と同じ並び。
-- .conf の source 順 (defaults → monitors → input → bindings → looknfeel → autostart
-- → toggles → 個人ファイル) を保つ。

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Load Omarchy defaults.
--
-- 3.8.1 の hyprland.conf はアプリ起動系の既定バインドを読み込まず、アプリ起動は
-- 全部 ~/.config/hypr/bindings.conf が持っていた (既定ファイルのコピーを編集する方式)。
-- Quattro は default/hypr/bindings/applications.lua を自動で読み込むため、そのままだと
-- bindings.lua と二重登録になり SUPER+RETURN でターミナルが2つ開く等が起きる
-- (tests/quattro-parity が検出)。そこで既定バインドを一旦切り、applications 以外を
-- omarchy.lua と同じ順で読み込む。Omarchy が新しいバインドモジュールを足した場合は
-- tests/quattro-parity の「4.x で増えるキー / 失われるキー」に出る。
omarchy_default_bindings = false
require("default.hypr.omarchy")
for _, module in ipairs({ "media", "clipboard", "input-method", "jis", "tiling", "utilities", "dictation" }) do
  require("default.hypr.bindings." .. module)
end

-- 個人設定 (.conf の source 順に対応)
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- hyprland.conf 末尾に直書きしていた分と、dotfiles 管理の個人ファイル群
require("hypr.personal.clipboard-history") -- exec-once cliphist + SUPER+V
require("hypr.personal.dropdown")          -- dropdown.conf
require("hypr.personal.clip-presets")      -- clip-presets.conf
require("hypr.personal.windows")           -- windows.conf
require("hypr.personal.gestures")          -- gestures.conf
require("hypr.personal.legacy-defaults")   -- 3.8.1 既定のうち Quattro で消えるキーの復元
require("hypr.personal.overview")          -- ワークスペース一覧 (Mission Control 風)
require("hypr.personal.manual")            -- SUPER+SHIFT+K で dotfiles のマニュアル
