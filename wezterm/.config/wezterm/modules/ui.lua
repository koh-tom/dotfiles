-- ヘッダー (cheatbar) とフッター (タブバー・ステータス) で共有する見た目の部品。
-- 角の丸いピル型にそろえ、色はすべて Omarchy の現在テーマ (colors.toml) から作る。
local wezterm = require("wezterm")
local palette = require("omarchy_theme").get_palette()
local M = {}

-- ピルの左右の丸い端 (Nerd Font の powerline 半円)
M.CAP_L = "\u{e0b6}"
M.CAP_R = "\u{e0b4}"

local function hex_to_rgb(hex)
  hex = (hex or "#000000"):gsub("#", "")
  return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
end

-- a と b を t (0..1) で混ぜた色
function M.blend(a, b, t)
  local r1, g1, b1 = hex_to_rgb(a)
  local r2, g2, b2 = hex_to_rgb(b)
  local function mix(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return string.format("#%02x%02x%02x", mix(r1, r2), mix(g1, g2), mix(b1, b2))
end

-- 背景より一段・二段明るい面 (Catppuccin の surface0 / surface1 相当)
M.surface0 = M.blend(palette.background, palette.color0, 0.5)
M.surface1 = palette.color0
M.text = palette.foreground
M.subtext = palette.color7
M.muted = palette.color8

-- 色付きの頭 (アイコン・番号) + 面の上の本文、の2段ピル。
-- 返り値: format 要素の配列, 表示幅
function M.pill(head_bg, head_fg, head, body_bg, body_fg, body, opts)
  opts = opts or {}
  local items = {
    { Background = { Color = "transparent" } },
    { Foreground = { Color = head_bg } },
    { Text = M.CAP_L },
    { Background = { Color = head_bg } },
    { Foreground = { Color = head_fg } },
    { Attribute = { Intensity = opts.head_bold and "Bold" or "Normal" } },
    { Text = head },
    { Attribute = { Intensity = "Normal" } },
  }
  local width = 1 + wezterm.column_width(head) + 1
  if body and body ~= "" then
    items[#items + 1] = { Background = { Color = body_bg } }
    items[#items + 1] = { Foreground = { Color = body_fg } }
    items[#items + 1] = { Attribute = { Intensity = opts.body_bold and "Bold" or "Normal" } }
    items[#items + 1] = { Text = body }
    items[#items + 1] = { Attribute = { Intensity = "Normal" } }
    width = width + wezterm.column_width(body)
  end
  local tail_bg = (body and body ~= "") and body_bg or head_bg
  items[#items + 1] = { Background = { Color = "transparent" } }
  items[#items + 1] = { Foreground = { Color = tail_bg } }
  items[#items + 1] = { Text = M.CAP_R }
  return items, width
end

return M
