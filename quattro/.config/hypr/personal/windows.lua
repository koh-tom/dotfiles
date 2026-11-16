-- 移植元: hypr/.config/hypr/windows.conf
-- PDFビューア(Evince)はOmarchy既定で floating-window タグが付くので外してタイル表示にする
--   windowrule = tag -floating-window, match:class org.gnome.Evince

o.window("org.gnome.Evince", { tag = "-floating-window" })
