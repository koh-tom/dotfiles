local palette = require("omarchy_theme").get_palette()

-- ワークスペース名 → アクセント色。今どのワークスペースにいるかを色で分かるようにする。
-- default はテーマのアクセント色、それ以外は名前のハッシュでパレットから固定的に選ぶ
-- (赤 color1 は LEADER / SSH 表示と被るので使わない)。
local CHOICES = { palette.color5, palette.color2, palette.color6, palette.color3, palette.color4 }

return function(name)
  if not name or name == "" or name == "default" then return palette.accent end
  local h = 0
  for i = 1, #name do h = (h * 31 + name:byte(i)) % 2147483647 end
  return CHOICES[h % #CHOICES + 1]
end
