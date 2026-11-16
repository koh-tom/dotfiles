local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

-- 端末上のテキストをクリックで開けるリンクにする (標準のURL/メール検出に追加)
--   owner/repo#123  → GitHub の Issue/PR
--   #123            → 今いるリポジトリの Issue/PR (gh browse)
--   path/file.ext:120 → Neovim で該当行 (ペインのcwd基準。存在しないパスは無視)

local SCHEME_GH_REF = "gh-ref:"
local SCHEME_FILE_LINE = "file-line:"

local function extra_rules()
  return {
    -- owner/repo#123 (GitHubはissues/ → pull/ へ自動リダイレクトする)
    {
      regex = [[\b([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#(\d+)\b]],
      format = "https://github.com/$1/issues/$2",
    },
    -- #123 単体。直前が英数字や/なら対象外 (\B)。6桁以上はカラーコード等とみなして除外
    {
      regex = [[\B#(\d{1,5})\b]],
      format = SCHEME_GH_REF .. "$1",
    },
    -- path:line (拡張子付きファイルのみ)
    {
      regex = [[\b((?:[\w.-]+/)*[\w-][\w.-]*\.[A-Za-z][\w]*):(\d+)\b]],
      format = SCHEME_FILE_LINE .. "$1:$2",
    },
  }
end

local function pane_cwd(pane)
  local url = pane:get_current_working_dir()
  return url and url.file_path or wezterm.home_dir
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function module.apply_to_config(config)
  local rules = wezterm.default_hyperlink_rules()
  for _, rule in ipairs(extra_rules()) do table.insert(rules, rule) end
  config.hyperlink_rules = rules

  wezterm.on("open-uri", function(window, pane, uri)
    if uri:sub(1, #SCHEME_GH_REF) == SCHEME_GH_REF then
      local num = uri:sub(#SCHEME_GH_REF + 1)
      -- gh browse はカレントのgitリモートから解決するので、ペインのcwdで実行する
      wezterm.background_child_process({
        "sh", "-c", "cd " .. wezterm.shell_quote_arg(pane_cwd(pane)) .. " && gh browse " .. num,
      })
      return false
    end

    if uri:sub(1, #SCHEME_FILE_LINE) == SCHEME_FILE_LINE then
      local path, line = uri:sub(#SCHEME_FILE_LINE + 1):match("^(.*):(%d+)$")
      if not path then return false end
      if path:sub(1, 1) ~= "/" then path = pane_cwd(pane) .. "/" .. path end
      if not file_exists(path) then
        window:toast_notification("Open", "File not found: " .. path, nil, 2000)
        return false
      end
      local new_pane = pane:split({ direction = "Bottom", size = 1.0, args = { "nvim", "+" .. line, "--", path } })
      window:perform_action(act.TogglePaneZoomState, new_pane)
      return false
    end
  end)
end

return module
