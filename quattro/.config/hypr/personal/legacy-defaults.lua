-- Omarchy 3.8.1 の「既定」バインドのうち、Quattro で消える/別キーに移るものを復元する。
-- (個人設定ではないが「現状と同じ操作で使える」を優先。不要になったら hyprland.lua の
--  require を消すだけでよい。対象の洗い出しは tests/quattro-parity の
--  「3.x にあって 4.x に無いキー」)
--
-- 復元するもの:
--   XF86Calculator        3.x: gnome-calculator / 4.x: applications.lua の omacalc
--                         (applications.lua は二重起動回避のため読み込んでいない)
--   SUPER + XF86AudioMute 3.x: 音声出力の切替 / 4.x: SHIFT + XF86AudioMute に移動
--
-- 復元しないもの (Quattro 側に同等機能があるか、現状でも使えていないため):
--   SUPER (+ALT) + code:61 (/ キー) のモニタ拡大率サイクル
--       → 4.x は同じ物理キー SUPER (+ALT) + SLASH に「拡大/縮小」として割当済み。
--         旧コマンド omarchy-hyprland-monitor-scaling-cycle は 4.x に存在しない
--   CTRL + SUPER + X / F9 (voxtype の音声入力)
--       → voxtype 自体が未インストールで、現状でも押しても何も起きない。
--         4.x では音声入力を入れると ALT + SPACE 等が自動で割り当てられる

local calculator = o.cmd_present("gnome-calculator") and "gnome-calculator" or "omacalc"
o.bind("XF86Calculator", "Calculator", calculator)

o.bind("SUPER + XF86AudioMute", "Switch audio output", "omarchy-audio-output-switch", { locked = true })
