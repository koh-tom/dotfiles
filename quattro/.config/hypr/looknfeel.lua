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

