-- Pond / niri 風のスクロール配置。
-- ウィンドウを横に長い帯の上に「列」として並べ、新しいウィンドウを開いても他を縮めない。
-- 新しいワークスペースの既定にする (ワークスペースごとの切り替えは Omarchy 標準の SUPER+ALT+L のまま)。
hl.config({
  general = {
    layout = "scrolling",
  },
  scrolling = {
    column_width = 0.5,
    -- SUPER+R で 1/3 → 1/2 → 2/3 → 全幅 を順に切り替える
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    -- 13インチでは1枚だけのときは全幅の方が使いやすい
    fullscreen_on_one_column = true,
    focus_fit_method = 1,
  },
})

o.bind("SUPER + R", "Cycle column width (1/3, 1/2, 2/3, full)", hl.dsp.layout("colresize +conf"))
o.bind("SUPER + bracketleft", "Narrow column", hl.dsp.layout("colresize -0.1"))
o.bind("SUPER + bracketright", "Widen column", hl.dsp.layout("colresize +0.1"))
o.bind("SUPER + period", "Scroll so the focused column fits", hl.dsp.layout("fit active"))
