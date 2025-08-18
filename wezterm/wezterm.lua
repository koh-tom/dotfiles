local wezterm = require 'wezterm'
local DISTRO = 'Ubuntu-24.04'

local wsl_entry = string.format(
  "\\\\wsl$\\%s\\home\\ktoml\\dotfiles\\wezterm\\wezterm.lua",
  DISTRO
)

local ok, config = pcall(dofile, wsl_entry)

if not ok then
  wezterm.log_error(config)
  return {
    default_domain = 'WSL:' .. DISTRO,
    default_prog = { "wsl.exe", "-d", DISTRO },
  }
end

return config
