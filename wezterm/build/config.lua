local wezterm = require('wezterm')
wezterm.on('format-window-title', function()
  return '🐧 MoonScript WezTerm'
end)
return {
  font_size = 15
}
