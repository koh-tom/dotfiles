local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

local RECOMMENDED_SCHEMES = {
  "Solarized Dark Higher Contrast",
  "Catppuccin Mocha",
  "Gruvbox Dark",
  "Nord",
  "Tokyo Night",
  "Nightfox",
  "OneHalfDark",
}

function module.apply_to_config(config)
  table.insert(config.keys, {
    key = "t",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local all_schemes = wezterm.get_builtin_color_schemes()
      local choices = {}
      
      for _, name in ipairs(RECOMMENDED_SCHEMES) do
        table.insert(choices, { label = "⭐ " .. name, id = name })
      end
      
      local sorted_names = {}
      for name, _ in pairs(all_schemes) do table.insert(sorted_names, name) end
      table.sort(sorted_names)
      
      for _, name in ipairs(sorted_names) do
        local is_recommended = false
        for _, rec in ipairs(RECOMMENDED_SCHEMES) do if rec == name then is_recommended = true; break end end
        if not is_recommended then
          table.insert(choices, { label = "  " .. name, id = name })
        end
      end

      window:perform_action(act.InputSelector({
        action = wezterm.action_callback(function(win, _, id, label)
          if id or label then
            local scheme = id or label:gsub("^⭐%s+", ""):gsub("^%s+", "")
            local overrides = win:get_config_overrides() or {}
            overrides.color_scheme = scheme
            win:set_config_overrides(overrides)
            win:toast_notification("Color Scheme", "Applied: " .. scheme, nil, 1500)
          end
        end),
        title = "Select Color Scheme",
        choices = choices,
        fuzzy = true,
      }), pane)
    end),
  })
end

return module
