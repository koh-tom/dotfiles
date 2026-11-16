-- 移植元: hypr/.config/hypr/gestures.conf
-- Mac風: 3本指の左右スワイプでワークスペース切替 (指に追従してスライド)
--   gesture = 3, horizontal, workspace
--   gestures { workspace_swipe_create_new = false }

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.config({
  gestures = {
    -- 端のワークスペースを越えてスワイプしても空のワークスペースを作らない
    workspace_swipe_create_new = false,
  },
})
