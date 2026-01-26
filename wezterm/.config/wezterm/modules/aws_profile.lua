local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

-- Profile取得関数（aws CLI + configファイル）
local function get_aws_profiles()
  local profiles = {}
  -- CLI経由
  local handle = io.popen("aws configure list-profiles 2>/dev/null")
  if handle then
    for line in handle:read("*a"):gmatch("[^\r\n]+") do table.insert(profiles, line) end
    handle:close()
  end
  -- Configファイル直接（バックアップ）
  if #profiles == 0 then
    local home = os.getenv("HOME")
    local handle_cfg = io.popen(string.format("grep '^\\[profile' %s/.aws/config 2>/dev/null", home))
    if handle_cfg then
      for line in handle_cfg:read("*a"):gmatch("%[profile%s+(.+)%]") do table.insert(profiles, line) end
      handle_cfg:close()
    end
  end
  return profiles
end

function module.apply_to_config(config)
  table.insert(config.keys, {
    key = "p",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local profiles = get_aws_profiles()
      if #profiles == 0 then
        window:toast_notification("AWS Profile", "No profiles found in ~/.aws/config", nil, 4000)
        return
      end
      local choices = {}
      for _, p in ipairs(profiles) do table.insert(choices, { label = p, id = p }) end

      window:perform_action(act.InputSelector({
        action = wezterm.action_callback(function(_, input_pane, id)
          if id then input_pane:send_text("export AWS_PROFILE=" .. id .. "\n") end
        end),
        title = "Select AWS Profile",
        choices = choices,
        fuzzy = true,
      }), pane)
    end),
  })
end

return module
