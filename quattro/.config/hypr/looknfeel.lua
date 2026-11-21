-- 移植元: ~/.config/hypr/looknfeel.conf (Omarchy 既定のままで上書きゼロだった)
-- 2026-11-18: 角が真四角・隙間が広いのを見直し、角丸を付けて隙間を詰めた。
--   Omarchy 既定: rounding 0 / gaps_in 5 / gaps_out 10
hl.config({
  general = {
    gaps_in = 2, -- ウィンドウ同士の隙間
    gaps_out = 4, -- 画面端・バーとの隙間
  },
  decoration = {
    rounding = 8,
  },
})
