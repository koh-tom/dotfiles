-- resurrect.wezterm (MLFlexer) でワークスペースを自動保存し、あとから選んで戻せるようにする。
--   - 15分ごとに全ワークスペースを自動保存 (画面の文字も各ペイン最大 2000 行まで)
--   - LEADER + Shift+R: 保存済みのワークスペース / ウィンドウ / タブを一覧から選んで復元
-- 起動時の自動復元は今までどおり modules/session.lua (LEADER + Shift+S で手動保存) が担当する。
-- プラグインは初回読み込み時に GitHub から ~/.local/share/wezterm/plugins/ へ取得される
-- (更新は wezterm.plugin.update_all())。取得できない環境では何もしない。
local wezterm = require("wezterm")
local module = {}

function module.apply_to_config(config)
  local ok, resurrect = pcall(wezterm.plugin.require, "https://github.com/MLFlexer/resurrect.wezterm")
  if not ok or not resurrect then
    wezterm.log_warn("resurrect.wezterm を読み込めませんでした: " .. tostring(resurrect))
    return
  end

  resurrect.state_manager.set_max_nlines(2000)
  resurrect.state_manager.periodic_save({
    interval_seconds = 15 * 60,
    save_workspaces = true,
    save_windows = true,
    save_tabs = false,
  })

  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = "R",
    mods = "LEADER|SHIFT",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, _)
        local kind = string.match(id, "^([^/]+)")
        id = string.match(id, "([^/]+)$")
        id = string.match(id, "(.+)%..+$")
        local opts = {
          relative = true,
          restore_text = true,
          on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        }
        if kind == "workspace" then
          resurrect.workspace_state.restore_workspace(resurrect.state_manager.load_state(id, "workspace"), opts)
        elseif kind == "window" then
          resurrect.window_state.restore_window(pane:window(), resurrect.state_manager.load_state(id, "window"), opts)
        elseif kind == "tab" then
          resurrect.tab_state.restore_tab(pane:tab(), resurrect.state_manager.load_state(id, "tab"), opts)
        end
      end)
    end),
  })
end

return module
