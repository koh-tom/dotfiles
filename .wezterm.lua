--[[
WezTerm Windows側設定ファイル
最小構成でローダーとして動作
フォールバックも対応
]]


local wezterm = require 'wezterm'

-- WSLディストリビューション設定
local DISTRO = 'Ubuntu-24.04'

-- Windowsユーザー名 (C:\Users\<name>)
local win_user = os.getenv('USERNAME')

-- WSL 側 dotfiles のパス
local wsl_config_path = string.format(
  "\\\\wsl$\\%s\\home\\%s\\dotfiles\\wezterm\\build\\config.lua",
  DISTRO,
  win_user
)

-- WSLのを読み込む
local ok, wsl_config = pcall(dofile, wsl_config_path)

if not ok then
  -- 読み込み失敗時のフォールバック
  wezterm.log_error("Failed to load WSL wezterm config:")
  wezterm.log_error(wsl_config)

  return {
    -- WSLを起動する
    default_prog = { "wsl.exe", "-d", DISTRO },

    -- 視覚的に分かる最低限設定
    font_size = 13.0,
  }
end

-- Windows 側で強制したい設定を合成
wsl_config.default_domain = 'WSL:' .. DISTRO

wsl_config.wsl_domains = {
  {
    name = 'WSL:' .. DISTRO,
    distribution = DISTRO,
    default_cwd = '~',
  },
}

-- WSL側にdefault_prog が無ければ補完
wsl_config.default_prog = wsl_config.default_prog
  or { "wsl.exe", "-d", DISTRO }

return wsl_config
