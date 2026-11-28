-- 画面が 1 つも点いていない状態を作らない安全装置。
--   nwg-displays などで「内蔵画面 (eDP-1) を切って外部モニターだけ」の配置を保存したあと、
--   外部モニター無しで起動するとロック解除後に真っ黒になる (2026-11-28 に実際に起きた)。
--
-- しくみ: hl.monitor は実行中に呼んでも反映されず、設定の読み直し (hyprctl reload) でだけ効く。そこで
--   1. 起動・モニターを抜いた・配置が変わったときに、使える画面が 0 なら印のファイルを置いて読み直す
--   2. 読み直しのとき (このファイルは monitors.lua の後に読む)、印があれば内蔵画面を点ける規則を足す (後の規則が勝つ)
--   3. 外部モニターをつないだら印を消して読み直す (保存した配置 = monitors.lua に戻る)
--   読み直しても 0 のままなら、繰り返さずに通知だけ出す。monitors.lua の中身は変えない。
local INTERNAL = "eDP-1"
local FLAG = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/omarchy/monitor-guard-internal"

local function flag_set()
  local f = io.open(FLAG, "r")
  if f then f:close() end
  return f ~= nil
end

local function set_flag(on)
  if on then
    os.execute("mkdir -p '" .. FLAG:match("^(.*)/") .. "'")
    local f = io.open(FLAG, "w")
    if f then f:write(os.date("%F %T"), "\n"); f:close() end
  else
    os.remove(FLAG)
  end
end

-- 2. 印があれば、保存した配置で切られていても内蔵画面を点ける
if flag_set() then
  hl.monitor({ output = INTERNAL, mode = "preferred", position = "auto", scale = 1.5 })
end

-- Hyprland が画面の無いときに作る仮の出力は数えない
local function real_monitors()
  local names = {}
  for _, m in ipairs(hl.get_monitors() or {}) do
    local name = m.name or ""
    if not name:match("^HEADLESS") and not name:match("^FALLBACK") then
      names[#names + 1] = name
    end
  end
  return names
end

local function check()
  local names = real_monitors()
  if #names == 0 then
    if flag_set() then
      -- 内蔵画面を点ける規則が入っているのに 0: 繰り返さない
      hl.exec_cmd("notify-send -u critical '画面が点きません' '外部モニターをつなぐか、~/dotfiles/scripts/apply-host-profile を実行してください'")
      return
    end
    set_flag(true) -- 1.
    hl.exec_cmd("hyprctl reload")
    hl.exec_cmd("notify-send -u critical '画面がありませんでした' '内蔵画面を点けました (保存した配置は外部モニターをつなぐと戻ります)'")
    return
  end
  -- 3. 外部モニターがつながったら、保存した配置に戻す
  if flag_set() then
    for _, name in ipairs(names) do
      if name ~= INTERNAL then
        set_flag(false)
        hl.exec_cmd("hyprctl reload")
        return
      end
    end
  end
end

-- 画面の抜き差しや設定の適用が落ち着いてから調べる (ミリ秒)
local function check_soon()
  hl.timer(check, { type = "oneshot", timeout = 1500 })
end

hl.on("hyprland.start", check_soon)
hl.on("monitor.removed", check_soon)
hl.on("monitor.added", check_soon)
hl.on("monitor.layout_changed", check_soon)

return { check = check, real_monitors = real_monitors, flag = FLAG }
