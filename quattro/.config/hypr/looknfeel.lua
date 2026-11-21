-- 移植元: ~/.config/hypr/looknfeel.conf (Omarchy 既定のままで上書きゼロだった)
-- 2026-11-18: 見た目を自分好みに調整 (Omarchy 既定との差分だけ書く)
--   - 角丸を付けて隙間を詰めた (既定: rounding 0 / gaps_in 5 / gaps_out 10)
--   - 影を付けた (既定: 無し)
--   - ワークスペース切り替えをスライドにした (既定: アニメーション無し)
--   すりガラス (Glassy) は Omarchy のトグル (~/.local/state/omarchy/toggles/hypr/) が担当
hl.config({
  general = {
    gaps_in = 2, -- ウィンドウ同士の隙間
    gaps_out = 4, -- 画面端・バーとの隙間
  },
  decoration = {
    rounding = 8,
    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      offset = { 0, 4 },
      color = "rgba(00000070)",
      color_inactive = "rgba(00000040)",
    },
  },
})

-- 少しだけ行き過ぎて戻る曲線。ウィンドウが開くときに「ぽんっ」と出る
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.08 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "overshot", style = "popin 80%" })
-- 3本指スワイプと同じ向きに、左右へスライドしながらフェード
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade 15%" })
-- ドロップダウン端末などの special workspace は縦に出入り
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidevert" })

-- Hyprland 0.56 の新機能 (プラグイン不要)
--   glow: フォーカス中のウィンドウの内側をテーマのアクセント色でうっすら光らせる (非フォーカスは無し)
--   motion_blur: ウィンドウを動かす・リサイズするときだけ残像をつける (内蔵 GPU なので sample は控えめ)
-- 色はテーマの colors.toml の accent から取る (テーマを変えると hyprctl reload で追従する)
local function theme_color(name)
  local home = os.getenv("HOME") or ""
  local f = io.open(home .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text:match(name .. '%s*=%s*"#(%x%x%x%x%x%x)"')
end

local accent = theme_color("accent") or "89b4fa"
hl.config({
  decoration = {
    glow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(" .. accent .. "66)",
      color_inactive = "rgba(00000000)",
    },
    motion_blur = {
      enabled = true,
      samples = 5,
    },
  },
})

-- Pond 風の控えめな縁取り: 1px のグレーだけにして、フォーカスは上の glow (アクセント色) で示す。
-- テーマの hyprland.lua (アクセント色の 2px 枠) より後に読まれるので上書きになる
local gray = theme_color("color8") or "585b70"
hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = "rgba(" .. gray .. "ff)",
      inactive_border = "rgba(" .. gray .. "66)",
    },
  },
})
