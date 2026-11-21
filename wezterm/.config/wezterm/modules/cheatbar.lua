local wezterm = require("wezterm")
local module = {}
local palette = require("omarchy_theme").get_palette()

-- ウィンドウ上端に「よく使うキー」を並べる帯。
-- WezTermはタブバー以外に文字を描けないので、テーマ色でSVG→PNGを生成して
-- backgroundレイヤーとして上端に敷き、window_padding.top でその分ターミナルを下げる。
-- 文字サイズは端末のセル寸法から決めるので、下のタブバーと同様に Ctrl+-/= に連動する。
-- backgroundを使うと window_background_opacity / window_background_image が無視されるため、
-- 透過度・壁紙・カラースキームの切替はすべて module.refresh 経由で背景レイヤーを組み直す。

-- =============================================================================
-- 表示内容 (key, label)。先頭ほど優先され、幅が足りないと末尾から省かれる
-- 増やしたら dotfiles-cheatsheet の desc にも足すこと
-- =============================================================================

local LEADER = "^Q"
local COMMANDS = {
  { LEADER .. " g", "project" },
  { LEADER .. " l", "launch" },
  { LEADER .. " c", "claude" },
  { LEADER .. " r/d", "split" },
  { LEADER .. " f", "zoom" },
  { LEADER .. " w", "workspace" },
  { LEADER .. " z", "copy last" },
  { "^⇧HJKL", "pane" },
  { "^R", "history" },
  { "^T", "tv" },
  { "⌘`", "dropdown" },
  { "⌘Space", "quick select" },
  { "⌘F", "search" },
  { "^⇧X", "copy mode" },
  { LEADER .. " ,", "rename" },
  { "^⇧P", "palette" },
  { LEADER .. " /", "cheatsheet" },
}

local FONT_FAMILY = "JetBrainsMono Nerd Font"
local LINE_HEIGHT_RATIO = 1.32 -- JetBrains Mono のセル高 / em
local MARGIN_X = 12
local BAND_PAD = 4 -- 帯の下余白 (この下端に境界線を引く)
local LINE_PX = 2 -- 境界線の太さ (HiDPI 1.5倍で約1pt)

-- =============================================================================
-- 画像生成 (セル寸法 → SVG → PNG)
-- =============================================================================

local function xml_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- cell_w/cell_h: 端末1セルの物理px。max_w: 帯に使える幅
local function build_svg(cell_w, cell_h, max_w)
  local font_px = math.floor(cell_h / LINE_HEIGHT_RATIO + 0.5)
  local pad = math.floor(cell_w * 0.6 + 0.5)
  local gap_key_label = math.floor(cell_w * 0.6 + 0.5)
  local gap_item = cell_w * 2
  local pill_h = math.min(cell_h - 4, font_px + 8)
  local pill_y = (cell_h - pill_h) / 2
  local baseline = cell_h / 2 + font_px * 0.36

  local parts = {}
  local x = 2
  for i, item in ipairs(COMMANDS) do
    local key, label = item[1], item[2]
    local kw = wezterm.column_width(key) * cell_w + pad * 2
    local lw = wezterm.column_width(label) * cell_w
    local sep = (i > 1) and gap_item or 0
    if x + sep + kw + gap_key_label + lw > max_w then break end

    if i > 1 then
      parts[#parts + 1] = string.format('<text x="%.1f" y="%.1f" fill="%s">·</text>',
        x + gap_item / 2 - cell_w / 2, baseline, palette.color8)
      x = x + gap_item
    end
    parts[#parts + 1] = string.format(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%d" fill="%s" fill-opacity="0.55"/>',
      x, pill_y, kw, pill_h, math.floor(pill_h / 5), palette.color0)
    parts[#parts + 1] = string.format('<text x="%.1f" y="%.1f" fill="%s" font-weight="bold">%s</text>',
      x + pad, baseline, palette.accent, xml_escape(key))
    x = x + kw + gap_key_label
    parts[#parts + 1] = string.format('<text x="%.1f" y="%.1f" fill="%s">%s</text>',
      x, baseline, palette.color7, xml_escape(label))
    x = x + lw
  end

  local width = math.max(math.ceil(x + 2), 1)
  local svg = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="%s" font-size="%d">%s</svg>',
    width, cell_h, FONT_FAMILY, font_px, table.concat(parts))
  return svg, width
end

-- 内容・寸法・テーマ色が変わったときだけ再生成する
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return string.format("%08x", h)
end

local CACHE_DIR = wezterm.home_dir .. "/.cache/wezterm"

-- run_child_process はconfig overrides再評価時に "yield across a C-call boundary" で落ちるので os.execute を使う
local function svg_to_png(svg, width, cell_h)
  local png = string.format("%s/cheatbar-%s.png", CACHE_DIR, hash(svg))

  local f = io.open(png, "rb")
  if f then
    f:close()
    return { path = png, width = width, height = cell_h }
  end

  os.execute("mkdir -p " .. wezterm.shell_quote_arg(CACHE_DIR))
  local svg_path = CACHE_DIR .. "/cheatbar.svg"
  local out = io.open(svg_path, "w")
  if not out then return nil end
  out:write(svg)
  out:close()

  if not os.execute("rsvg-convert -o " .. wezterm.shell_quote_arg(png) .. " " .. wezterm.shell_quote_arg(svg_path)) then
    wezterm.log_warn("cheatbar: rsvg-convert failed")
    return nil
  end
  return { path = png, width = width, height = cell_h }
end

local function render(cell_w, cell_h, max_w)
  local svg, width = build_svg(cell_w, cell_h, max_w)
  return svg_to_png(svg, width, cell_h)
end

-- =============================================================================
-- tips (右側に5分ごとに巡回表示。中身は ~/dotfiles/tips/tips.tsv)
-- =============================================================================

local TIPS_FILE = wezterm.home_dir .. "/dotfiles/tips/tips.tsv"
local TIP_ROTATE_SEC = 300
local TIP_AREA_RATIO = 1 / 3 -- 帯の右何割を tip に使うか

local function load_tips()
  local tips = {}
  local f = io.open(TIPS_FILE, "r")
  if not f then return tips end
  for line in f:lines() do
    if not line:match("^#") and line:match("%S") then
      local cat, key, desc = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
      if cat then tips[#tips + 1] = { cat = cat, key = key, desc = desc } end
    end
  end
  f:close()
  return tips
end

local tips = load_tips()
local tip_offset = 0 -- LEADER n で進める分

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

-- カテゴリ順に偏らないよう「slot * step mod 件数」で散らして巡回する
local function current_tip()
  local n = #tips
  if n == 0 then return nil end
  local step = 17
  while gcd(step, n) ~= 1 do step = step + 1 end
  local slot = math.floor(os.time() / TIP_ROTATE_SEC) + tip_offset
  return tips[(slot * step) % n + 1]
end

local function build_tip_svg(tip, cell_w, cell_h, max_w)
  local font_px = math.floor(cell_h / LINE_HEIGHT_RATIO + 0.5)
  local baseline = cell_h / 2 + font_px * 0.36
  local max_cols = math.floor(max_w / cell_w)
  local icon = "󰛨 "
  local key = tip.key .. "  "
  local desc_cols = max_cols - wezterm.column_width(icon) - wezterm.column_width(key)
  if desc_cols < 4 then return nil end
  local desc = tip.desc
  if wezterm.column_width(desc) > desc_cols then
    desc = wezterm.truncate_right(desc, desc_cols - 1) .. "…"
  end

  local x1 = wezterm.column_width(icon) * cell_w
  local x2 = x1 + wezterm.column_width(key) * cell_w
  local width = math.ceil(x2 + wezterm.column_width(desc) * cell_w + 2)
  local svg = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="%s" font-size="%d">'
      .. '<text x="0" y="%.1f" fill="%s">%s</text>'
      .. '<text x="%.1f" y="%.1f" fill="%s" font-weight="bold">%s</text>'
      .. '<text x="%.1f" y="%.1f" fill="%s" fill-opacity="0.85">%s</text></svg>',
    width, cell_h, FONT_FAMILY, font_px,
    baseline, palette.color3, xml_escape(icon),
    x1, baseline, palette.accent, xml_escape(tip.key),
    x2, baseline, palette.color7, xml_escape(desc))
  return svg, width
end

local function render_tip(cell_w, cell_h, max_w)
  local tip = current_tip()
  if not tip then return nil end
  local svg, width = build_tip_svg(tip, cell_w, cell_h, max_w)
  if not svg then return nil end
  return svg_to_png(svg, width, cell_h)
end

-- 起動直後 (セル寸法が分かる前) の仮サイズ: 12pt @ 1.5倍スケール相当
local DEFAULT_CELL_W, DEFAULT_CELL_H = 14, 32
local default_image = render(DEFAULT_CELL_W, DEFAULT_CELL_H, 1800)

-- =============================================================================
-- 背景レイヤー
-- =============================================================================

local DEFAULT_OPACITY = 0.82 -- modules/opacity.lua の FOCUSED と揃える
local WALLPAPER = require("omarchy_theme").current_dir() .. "/background"

-- window_id -> { opacity, wallpaper, image, tip, win_w, win_h, cell_h, metrics }
local states = {}

local function state_of(window)
  local id = window:window_id()
  states[id] = states[id] or { opacity = DEFAULT_OPACITY, wallpaper = false, image = default_image }
  return states[id]
end

local function scheme_background(scheme)
  if not scheme then return palette.background end
  local s = wezterm.get_builtin_color_schemes()[scheme]
  return (s and s.background) or palette.background
end

local function build_layers(opts)
  local layers = {
    {
      source = { Color = scheme_background(opts.scheme) },
      width = "100%",
      height = "100%",
      opacity = opts.opacity,
    },
  }
  if opts.wallpaper then
    layers[#layers + 1] = {
      source = { File = WALLPAPER },
      width = "Cover",
      height = "Cover",
      vertical_align = "Middle",
      horizontal_align = "Center",
      opacity = opts.opacity,
      -- 文字が読める明るさまで落とす
      hsb = { brightness = 0.06, saturation = 0.9 },
    }
  end
  -- 本文との境界: 帯をうっすら塗り、下端とタブバー上端に線を引く
  local function line(y)
    return {
      source = { Color = palette.color8 },
      width = "100%",
      height = LINE_PX .. "px",
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      vertical_align = "Top",
      vertical_offset = y .. "px",
      opacity = 0.9,
    }
  end
  if opts.image then
    local band_h = opts.image.height + BAND_PAD
    layers[#layers + 1] = {
      source = { Color = palette.color0 },
      width = "100%",
      height = band_h .. "px",
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      vertical_align = "Top",
      opacity = 0.35,
    }
    layers[#layers + 1] = line(band_h - LINE_PX)
  end
  -- retroタブバーの高さは1セル分。ウィンドウ高さが分かってから引く
  if opts.win_h and opts.cell_h then
    layers[#layers + 1] = line(opts.win_h - opts.cell_h - LINE_PX)
  end
  if opts.image then
    layers[#layers + 1] = {
      source = { File = opts.image.path },
      width = opts.image.width .. "px",
      height = opts.image.height .. "px",
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      vertical_align = "Top",
      horizontal_align = "Left",
      horizontal_offset = MARGIN_X .. "px",
      vertical_offset = "2px",
    }
  end
  if opts.tip and opts.win_w then
    layers[#layers + 1] = {
      source = { File = opts.tip.path },
      width = opts.tip.width .. "px",
      height = opts.tip.height .. "px",
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      vertical_align = "Top",
      horizontal_align = "Left",
      horizontal_offset = (opts.win_w - opts.tip.width - MARGIN_X) .. "px",
      vertical_offset = "2px",
    }
  end
  return layers
end

local function padding_top(image)
  -- 境界線の下に本文が密着しないよう少し空ける
  return (image and (image.height + BAND_PAD + 6) or 0) .. "px"
end

-- changes: { opacity = number?, wallpaper = bool?, image = table? }
function module.refresh(window, changes)
  local st = state_of(window)
  for k, v in pairs(changes or {}) do st[k] = v end
  local overrides = window:get_config_overrides() or {}
  overrides.background = build_layers({
    opacity = st.opacity,
    wallpaper = st.wallpaper,
    image = st.image,
    tip = st.tip,
    win_w = st.win_w,
    win_h = st.win_h,
    cell_h = st.cell_h,
    scheme = overrides.color_scheme,
  })
  local wp = overrides.window_padding or {}
  wp.top = padding_top(st.image)
  overrides.window_padding = wp
  window:set_config_overrides(overrides)
end

function module.wallpaper_enabled(window)
  return state_of(window).wallpaper
end

-- アクティブペインからセル寸法を測り、フォントサイズ/ウィンドウ幅が変わっていたら帯を作り直す
local function sync_metrics(window, pane)
  if not pane then return end
  local d = pane:get_dimensions()
  if not d or d.cols == 0 or d.viewport_rows == 0 then return end
  local cell_w = math.floor(d.pixel_width / d.cols + 0.5)
  local cell_h = math.floor(d.pixel_height / d.viewport_rows + 0.5)
  local win = window:get_dimensions()
  local inner_w = win.pixel_width - MARGIN_X * 2
  -- 右 1/3 を tip、残りをキー一覧に割り当てる (間に2セル空ける)
  local tip_w = math.floor(inner_w * TIP_AREA_RATIO)
  local cmd_w = inner_w - tip_w - cell_w * 2

  local slot = math.floor(os.time() / TIP_ROTATE_SEC) + tip_offset
  local key = string.format("%d:%d:%d:%d:%d", cell_w, cell_h, inner_w, win.pixel_height, slot)
  local st = state_of(window)
  if st.metrics == key then return end
  st.metrics = key
  module.refresh(window, {
    image = render(cell_w, cell_h, cmd_w),
    tip = render_tip(cell_w, cell_h, tip_w),
    win_w = win.pixel_width,
    win_h = win.pixel_height,
    cell_h = cell_h,
  })
end

-- LEADER n: 次の tip へ進め、全文を通知でも出す
local function next_tip(window, pane)
  tip_offset = tip_offset + 1
  sync_metrics(window, pane)
  local tip = current_tip()
  if tip then
    window:toast_notification("Tip [" .. tip.cat .. "] " .. tip.key, tip.desc, nil, 6000)
  end
end

function module.apply_to_config(config)
  if not default_image then return end
  config.background = build_layers({ opacity = DEFAULT_OPACITY, wallpaper = false, image = default_image })
  config.window_padding = config.window_padding or {}
  config.window_padding.top = padding_top(default_image)

  wezterm.on("window-resized", sync_metrics)
  wezterm.on("update-status", sync_metrics)

  config.keys = config.keys or {}
  table.insert(config.keys, { key = "n", mods = "LEADER", action = wezterm.action_callback(next_tip) })
end

return module
