-- Claude の母艦 (scripts/claude-hub) を WezTerm から開く。
--   LEADER + Shift + h: 母艦で動いている Claude と、母艦の git リポジトリの一覧から選ぶ
--     ● 動いている窓  → その Claude だけを新しいタブで開く (タブごとに別の Claude を表示できる)
--     ↻ リポジトリ    → そこでの前回の会話の続きから (claude --continue。窓が開いていない場所だけ)
--     ＋ リポジトリ    → 母艦のそこで新しい Claude を始めて、新しいタブで開く
--     󰚩 母艦全体      → 全部の窓を行き来できる形でつなぐ
-- 母艦のタブは tmux が付けるタイトル「󰚩 …」で見分けて、タブとヘッダーを母艦の色 (紫) にする (tab.lua / cheatbar.lua)。
-- 母艦のホスト名はこのリポジトリ (公開) には書かない (~/.config/dotfiles/claude-hub)。
local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

local SCRIPT = wezterm.home_dir .. "/dotfiles/scripts/claude-hub"
local ICON = "󰚩"

-- 母艦の窓のタイトルは tmux の set-titles-string で「󰚩 名前」になる
function module.is_hub_title(title)
  return title ~= nil and title:sub(1, #ICON) == ICON
end

local function spawn(window, pane, args)
  window:perform_action(act.SpawnCommandInNewTab({ args = args }), pane)
end

local function choose(window, pane)
  local ok, out, err = wezterm.run_child_process({ "timeout", "10", SCRIPT, "menu" })
  if not ok then
    local msg = (err or ""):match("[^\n]+") or "つなげませんでした"
    window:toast_notification("母艦", msg, nil, 5000)
    return
  end

  local choices = { { id = "attach", label = ICON .. "  母艦全体 (すべての窓を行き来する)" } }
  local open_paths = {}
  for line in (out or ""):gmatch("[^\n]+") do
    local kind, a, b, c = line:match("^(%w+)\t([^\t]*)\t?([^\t]*)\t?([^\t]*)$")
    if kind == "open" then
      open_paths[c] = true
      table.insert(choices, { id = "open:" .. a, label = string.format("●  %s  %s   %s", a, b, c) })
    end
  end
  -- 前回の会話の続き。すでに窓が開いている場所は出さない (同じ会話を2つで動かすとずれるので、● から開く)
  for line in (out or ""):gmatch("[^\n]+") do
    local dir = line:match("^cont\t(.+)$")
    if dir and not open_paths[dir] and dir ~= "~/dotfiles" then
      table.insert(choices, { id = "cont:" .. dir, label = "↻  " .. dir .. "  の前回の会話の続き" })
    end
  end
  for line in (out or ""):gmatch("[^\n]+") do
    local dir = line:match("^new\t(.+)$")
    -- 母艦自身の ~/dotfiles は母艦の設定そのもの (触らない)。dotfiles の作業は ~/hub/dotfiles
    if dir and not open_paths[dir] and dir ~= "~/dotfiles" then
      table.insert(choices, { id = "new:" .. dir, label = "＋  " .. dir .. "  で新しい Claude" })
    end
  end

  window:perform_action(act.InputSelector({
    title = ICON .. " 母艦: どれを開く?",
    choices = choices,
    fuzzy = true,
    action = wezterm.action_callback(function(w, p, id)
      if not id then return end
      if id == "attach" then
        spawn(w, p, { SCRIPT })
      elseif id:match("^open:") then
        spawn(w, p, { SCRIPT, "open", id:sub(6) })
      elseif id:match("^cont:") then
        spawn(w, p, { SCRIPT, "new", id:sub(6), "--continue" })
      elseif id:match("^new:") then
        spawn(w, p, { SCRIPT, "new", id:sub(5) })
      end
    end),
  }), pane)
end

function module.apply_to_config(config)
  config.keys = config.keys or {}
  table.insert(config.keys, { key = "H", mods = "LEADER|SHIFT", action = wezterm.action_callback(choose) })
end

return module
