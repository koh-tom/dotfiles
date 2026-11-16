local wezterm = require("wezterm")

local module = {}

-- Omarchy の現在テーマの場所。4.x (Quattro) は ~/.local/state/omarchy/current、
-- 3.x は ~/.config/omarchy/current。存在する方を使う (両対応)。
function module.current_dir()
  local state = (os.getenv("XDG_STATE_HOME") or (wezterm.home_dir .. "/.local/state")) .. "/omarchy/current"
  local probe = io.open(state .. "/theme/colors.toml", "r")
  if probe then
    probe:close()
    return state
  end
  return wezterm.home_dir .. "/.config/omarchy/current"
end

local defaults = {
  accent = "#89b4fa",
  cursor = "#cdd6f4",
  foreground = "#cdd6f4",
  background = "#1e1e2e",
  selection_foreground = "#e8f1ff",
  selection_background = "#292b3b",
  color0 = "#45475a",
  color1 = "#f38ba8",
  color2 = "#a6e3a1",
  color3 = "#f9e2af",
  color4 = "#89b4fa",
  color5 = "#cba6f7",
  color6 = "#94e2d5",
  color7 = "#bac2de",
  color8 = "#585b70",
  color9 = "#f38ba8",
  color10 = "#a6e3a1",
  color11 = "#f9e2af",
  color12 = "#89b4fa",
  color13 = "#cba6f7",
  color14 = "#94e2d5",
  color15 = "#cdd6f4",
}

local cached_palette = nil

local function read_palette()
  local palette = {}
  for key, value in pairs(defaults) do palette[key] = value end

  local path = module.current_dir() .. "/theme/colors.toml"
  local file = io.open(path, "r")
  if not file then return palette end

  for line in file:lines() do
    local key, value = line:match('^%s*([%w_]+)%s*=%s*["\'](#[%x]+)["\']')
    if key and value then palette[key] = value end
  end
  file:close()

  return palette
end

function module.get_palette()
  if not cached_palette then cached_palette = read_palette() end
  return cached_palette
end

function module.apply_to_config(config)
  local p = module.get_palette()

  config.color_schemes = config.color_schemes or {}
  config.color_schemes["Omarchy Current"] = {
    foreground = p.foreground,
    background = p.background,
    cursor_bg = p.cursor,
    cursor_fg = p.background,
    cursor_border = p.cursor,
    selection_bg = p.selection_background,
    selection_fg = p.selection_foreground,
    -- ペイン分割線。非アクティブ側を暗くするのと合わせて境界をはっきりさせる
    split = p.accent,
    ansi = { p.color0, p.color1, p.color2, p.color3, p.color4, p.color5, p.color6, p.color7 },
    brights = { p.color8, p.color9, p.color10, p.color11, p.color12, p.color13, p.color14, p.color15 },
  }
  config.color_scheme = "Omarchy Current"

  return p
end

return module
