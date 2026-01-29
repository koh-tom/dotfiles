-- =============================================================================
-- modules/notify.lua (Desktop Notification Integration)
-- =============================================================================

local wezterm = require("wezterm")
local module = {}

-- ---------------------------------------------------------------------------
-- 設定
-- ---------------------------------------------------------------------------
local cmd_start_times = {}
local LONG_COMMAND_THRESHOLD = 30 -- 30秒以上を実質的な「長時間」とみなす

-- ---------------------------------------------------------------------------
-- ユーティリティ: 通知の送信
-- ---------------------------------------------------------------------------
function module.send_notification(window, title, msg, icon)
  window:toast_notification(title or "WezTerm", msg, icon, 4000)
end

-- ---------------------------------------------------------------------------
-- コマンド終了検知 (User Vars を利用)
-- ---------------------------------------------------------------------------
-- シェル統合 (OSC 133 等) が有効な場合、コマンドの開始/終了を検知できる場合があります。
-- ここでは簡易的に、プロセスの変化やベルを監視します。

-- ベルが鳴った時にデスクトップ通知を出す
wezterm.on("bell", function(window, pane)
  module.send_notification(window, "Bell Triggered", "A bell was rung in: " .. (pane:get_title() or "a pane"), nil)
end)

-- ---------------------------------------------------------------------------
-- apply_to_config
-- ---------------------------------------------------------------------------
function module.apply_to_config(config)
  -- 特殊なイベント「SEND_NOTIFICATION」を登録 (他モジュールから呼び出し可能に)
  wezterm.on("user-defined-notify", function(window, pane, title, msg)
    module.send_notification(window, title, msg)
  end)

  -- ステータス更新時に、コマンドの実行時間を計測するロジック (簡易版)
  wezterm.on("update-status", function(window, pane)
    local pane_id = pane:pane_id()
    local user_vars = pane:get_user_vars()
    
    -- シェルから送信されるプロンプト状態をチェック (OSC 133)
    -- WEZTERM_PROMPT は プロンプト表示中に "1" になることがある
    -- ここでは、フォアグラウンドプロセスの変化で簡易的に検知します
    local current_prog = pane:get_foreground_process_name()
    if not current_prog then return end
    
    -- シェルのプロセス（zsh, bash等）以外が走っている時間を計測
    local shell_names = { zsh = true, bash = true, fish = true, sh = true }
    local prog_base = current_prog:match("([^/]+)$") or ""
    
    if not shell_names[prog_base] then
      -- コマンド実行開始
      if not cmd_start_times[pane_id] then
        cmd_start_times[pane_id] = {
          name = prog_base,
          start = os.time()
        }
      end
    else
      -- シェルに戻っている場合、直前まで長時間コマンドが走っていたか確認
      local last_cmd = cmd_start_times[pane_id]
      if last_cmd then
        local duration = os.difftime(os.time(), last_cmd.start)
        
        -- 一定時間以上かかっていて、かつウィンドウがフォーカスされていない場合に通知
        if duration >= LONG_COMMAND_THRESHOLD then
          if not window:is_focused() then
              module.send_notification(window, 
                "Command Finished", 
                string.format("'%s' completed in %d seconds", last_cmd.name, duration),
                nil)
          end
        end
        cmd_start_times[pane_id] = nil
      end
    end
  end)
end

return module
