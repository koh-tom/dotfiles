-- 研究室などのマシンを WezTerm の SSH ドメインとして開く。
--   LEADER + h: 一覧から選ぶと、そのマシンのシェルが新しいタブで開く (タブ名・ステータス表示も効く)
-- 一覧は設定の読み込み時に `tailscale status` から作る (Linux のピア) + ~/.ssh/config の Host。
-- ホスト名はこのリポジトリ (公開) には書かない。リモート側に wezterm は要らない (multiplexing = "None")。
local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

local function tailscale_peers()
  local p = io.popen("tailscale status --json 2>/dev/null")
  if not p then return {} end
  local out = p:read("a")
  p:close()
  local ok, data = pcall(wezterm.json_parse, out or "")
  if not ok or type(data) ~= "table" or type(data.Peer) ~= "table" then return {} end
  local peers = {}
  for _, peer in pairs(data.Peer) do
    if peer.OS == "linux" and peer.HostName and peer.HostName ~= "" then
      table.insert(peers, { name = peer.HostName, online = peer.Online == true })
    end
  end
  table.sort(peers, function(a, b) return a.name < b.name end)
  return peers
end

function module.apply_to_config(config)
  local domains = {}
  for _, peer in ipairs(tailscale_peers()) do
    table.insert(domains, {
      name = "ts:" .. peer.name,
      remote_address = peer.name, -- Tailscale の MagicDNS で引ける
      multiplexing = "None",
      assume_shell = "Posix",
    })
  end
  -- ~/.ssh/config の Host も (SSH: / SSHMUX: の2種類が作られる。使うのは SSH: の方)
  for _, d in ipairs(wezterm.default_ssh_domains()) do
    if d.name:match("^SSH:") and not d.name:match("%*") then
      d.multiplexing = "None"
      table.insert(domains, d)
    end
  end
  config.ssh_domains = domains

  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = "h",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local choices = {}
      for _, d in ipairs(domains) do
        table.insert(choices, { id = d.name, label = d.name })
      end
      if #choices == 0 then
        window:toast_notification("SSH", "開けるマシンがありません (tailscale / ~/.ssh/config)", nil, 3000)
        return
      end
      window:perform_action(act.InputSelector({
        title = "SSH: どのマシンを開く?",
        choices = choices,
        fuzzy = true,
        action = wezterm.action_callback(function(w, p, id)
          if id then
            w:perform_action(act.SpawnCommandInNewTab({ domain = { DomainName = id } }), p)
          end
        end),
      }), pane)
    end),
  })
end

return module
