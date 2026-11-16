-- 配置: stow せず、移行時に scripts/migrate-to-quattro が ~/.config/hypr/monitors.lua へ
-- 通常ファイルとしてコピーする (nwg-displays や apply-host-profile が上書きするホスト固有ファイルのため)。

-- 移植元: ~/.config/hypr/monitors.conf (nwg-displays が 2026-10-30 に生成)
--   monitor=eDP-1,1920x1080@60.03,3229x1741,1.5,vrr,0
--   monitor=HDMI-A-1,1920x1080@60.0,2883x661,1.0,vrr,0
-- 上流テンプレートの「未定義モニタは preferred/auto」行は 3.8.1 の既定 monitors.conf
-- にも無かったので入れない (nwg-displays 生成ファイルは2行のみ)。

hl.monitor({ output = "eDP-1", mode = "1920x1080@60.03", position = "3229x1741", scale = 1.5, vrr = 0 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.0", position = "2883x661", scale = 1.0, vrr = 0 })
