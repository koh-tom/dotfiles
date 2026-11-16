#!/usr/bin/env python3
"""Omarchy 3.x (.conf + Waybar) のベースラインと、Omarchy 4 (Lua + Quickshell) 移植版を突き合わせる。

判定:
  PASS   一致
  FAIL   不一致 (移植漏れ・誤り)。1件でもあれば終了コード 1
  KNOWN  既知の差分 (known-diffs.json に理由つきで登録済み。Quattro 側の仕様で再現不能など)
  INFO   参考情報 (Omarchy 4 の既定が変わったことによる差。個人設定の移植とは無関係)
  SKIP   この環境では検査できない (ツール不在など)

入力:
  --baseline DIR   capture-baseline の出力
  --lua JSON       lua-harness.lua の出力 (Omarchy 4 既定 + 移植版の評価結果)
  --quattro DIR    dotfiles/quattro パッケージ
  --live-binds F   (移行後) Lua 構成で動いている Hyprland の `hyprctl binds -j`
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOTFILES = HERE.parent.parent

MOD_BITS = {1: "SHIFT", 4: "CTRL", 8: "ALT", 64: "SUPER", 2: "CAPS", 16: "MOD2", 32: "MOD3", 128: "MOD5"}
MOD_ALIAS = {"CONTROL": "CTRL", "MOD1": "ALT", "MOD4": "SUPER", "WIN": "SUPER", "LOGO": "SUPER", "META": "SUPER"}


# ---------------------------------------------------------------- report

class Report:
    def __init__(self, known: dict) -> None:
        self.rows: list[tuple[str, str, str, str]] = []
        self.known = known

    def add(self, status: str, area: str, item: str, detail: str = "") -> None:
        if status == "FAIL" and f"{area}:{item}" in self.known:
            status, detail = "KNOWN", f"{self.known[f'{area}:{item}']}  [{detail}]" if detail else self.known[f"{area}:{item}"]
        self.rows.append((status, area, item, detail))

    def counts(self) -> dict:
        c: dict[str, int] = defaultdict(int)
        for s, *_ in self.rows:
            c[s] += 1
        return dict(c)

    def render(self, verbose: bool) -> str:
        color = {"PASS": "32", "FAIL": "31", "KNOWN": "33", "INFO": "36", "SKIP": "90"}
        tty = os.isatty(1)
        lines, area_now = [], None
        for status, area, item, detail in self.rows:
            if status in ("PASS", "INFO") and not verbose and status != "INFO":
                continue
            if area != area_now:
                lines.append(f"\n== {area}")
                area_now = area
            tag = f"\033[{color[status]}m{status:5}\033[0m" if tty else f"{status:5}"
            lines.append(f"  {tag} {item}" + (f"\n         {detail}" if detail else ""))
        c = self.counts()
        lines.append("\n" + "  ".join(f"{k}={c.get(k, 0)}" for k in ("PASS", "FAIL", "KNOWN", "INFO", "SKIP")))
        return "\n".join(lines)

    def markdown(self) -> str:
        out = ["| 判定 | 区分 | 項目 | 詳細 |", "|---|---|---|---|"]
        for status, area, item, detail in self.rows:
            esc = lambda s: s.replace("|", "\\|").replace("\n", "<br>")
            out.append(f"| {status} | {esc(area)} | {esc(item)} | {esc(detail)} |")
        return "\n".join(out)


# ---------------------------------------------------------------- normalize

def norm_mods(mods) -> tuple:
    if isinstance(mods, int):
        return tuple(sorted(name for bit, name in MOD_BITS.items() if mods & bit))
    tokens = re.split(r"[\s+_]+", str(mods).upper().strip())
    return tuple(sorted({MOD_ALIAS.get(t, t) for t in tokens if t}))


def norm_key(key: str) -> str:
    return str(key).strip().lower()


def lua_keys(spec: str) -> tuple:
    parts = [p.strip() for p in spec.split("+")]
    return norm_mods(" ".join(parts[:-1])), norm_key(parts[-1])


def norm_action(dispatcher: str, arg: str) -> tuple:
    """legacy dispatcher/arg を比較用の (種類, 値) に。"""
    d = dispatcher.strip().lower()
    return (d, arg.strip())


DSP_EQUIV = {
    # Lua dsp → 旧 dispatcher
    "focus.workspace": "workspace",
    "workspace.toggle_special": "togglespecialworkspace",
}


def lua_action(dispatcher: dict) -> tuple:
    kind = dispatcher.get("kind")
    if kind == "exec":
        return ("exec", dispatcher.get("cmd", ""))
    if kind == "function":
        return ("exec", dispatcher["cmd"]) if dispatcher.get("cmd") else ("lua-function", "")
    if kind == "dsp":
        name, args = dispatcher.get("dsp", ""), dispatcher.get("args")
        if name == "focus" and isinstance(args, dict) and "workspace" in args:
            return ("workspace", str(args["workspace"]))
        if name == "workspace.toggle_special":
            return ("togglespecialworkspace", str(args))
        if name == "global":
            return ("global", str(args))
        return (name, json.dumps(args, ensure_ascii=False, sort_keys=True))
    return (str(kind), "")


def canonical(action: tuple, desc: str = "") -> tuple:
    """3.x の dispatcher と 4.x の hl.dsp を同じ表現に寄せる (実効動作の比較用)。"""
    kind, val = action
    if desc == "Universal paste" or (kind == "sendshortcut" and "Insert" in val):
        return ("universal-paste", "")
    if kind == "window.move":
        args = json.loads(val) if val.startswith("{") else {}
        if "into_group" in args:
            return ("moveintogroup", args["into_group"])
    if kind == "window.float" and '"toggle"' in val:
        return ("togglefloating", "")
    return (kind, val)


def lua_effective(lua: dict) -> dict:
    """bind / unbind を登録順に適用した、キーごとの実効動作集合。"""
    events = [("bind", b) for b in lua["binds"]] + [("unbind", u) for u in lua.get("unbinds", [])]
    events.sort(key=lambda e: e[1].get("seq", 0))
    d: dict[tuple, set] = defaultdict(set)
    for kind, ev in events:
        k = lua_keys(ev["keys"])
        if kind == "unbind":
            d.pop(k, None)
        else:
            desc = ev["opts"].get("description", "") if isinstance(ev["opts"], dict) else ""
            d[k].add(canonical(lua_action(ev["dispatcher"]), desc))
    return d


def live_effective(live: list) -> dict:
    d: dict[tuple, set] = defaultdict(set)
    for b in live:
        key = norm_key(b["key"]) if b["key"] else f"code:{b['keycode']}"
        d[(norm_mods(b["modmask"]), key)].add(canonical(norm_action(b["dispatcher"], b["arg"]), b.get("description", "")))
    return d


def check_user_keys_effective(rep: Report, live: list, lua: dict) -> None:
    """個人設定が触るキーは、既定分も含めた実効動作の集合が 3.x と完全一致すること (厳密)。"""
    area = "キーバインド (個人キーの実効動作)"
    before, after = live_effective(live), lua_effective(lua)
    user_keys = {lua_keys(b["keys"]) for b in lua["binds"] if is_user(b["origin"])}
    user_keys |= {lua_keys(u["keys"]) for u in lua.get("unbinds", []) if is_user(u["origin"])}
    for k in sorted(user_keys):
        label = "+".join(k[0] + (k[1],))
        b, a = before.get(k, set()), after.get(k, set())
        if a == b:
            rep.add("PASS", area, label, f"{len(a)}動作" + (" (既定+個人の同時実行も現状どおり)" if len(a) > 1 else ""))
        else:
            rep.add("FAIL", area, label, f"4.x だけ: {sorted(a - b)}\n         3.x だけ: {sorted(b - a)}")


def is_user(origin: dict) -> bool:
    return origin.get("kind") == "user"


# ---------------------------------------------------------------- checks

def check_binds(rep: Report, intent: dict, live: list, lua: dict) -> None:
    area = "キーバインド (個人設定)"
    live_index: dict[tuple, list] = defaultdict(list)
    for b in live:
        key = norm_key(b["key"]) if b["key"] else f"code:{b['keycode']}"
        live_index[(norm_mods(b["modmask"]), key)].append(b)

    lua_user: dict[tuple, list] = defaultdict(list)
    for b in lua["binds"]:
        if is_user(b["origin"]):
            lua_user[lua_keys(b["keys"])].append(b)

    expected_keys = set()
    for b in intent["binds"]:
        k = (norm_mods(b["mods"]), norm_key(b["key"]))
        expected_keys.add(k)
        label = f"{'+'.join(k[0] + (k[1],))}  {b['description'] or b['dispatcher'] + ' ' + b['arg']}"
        want = norm_action(b["dispatcher"], b["arg"])

        # ベースライン自体の健全性: 実際に効いていたか
        live_hit = [x for x in live_index.get(k, []) if norm_action(x["dispatcher"], x["arg"]) == want]
        if not live_hit:
            rep.add("FAIL", area, label, "ベースラインの hyprctl binds に見当たらない (取得時に未反映?)")
            continue

        got = [x for x in lua_user.get(k, []) if lua_action(x["dispatcher"]) == want]
        if not got:
            have = [lua_action(x["dispatcher"]) for x in lua_user.get(k, [])]
            rep.add("FAIL", area, label, f"移植版に無い。期待 {want} / 移植版 {have or 'なし'}")
            continue
        desc = got[0]["opts"].get("description", "") if isinstance(got[0]["opts"], dict) else ""
        if desc != b["description"]:
            rep.add("FAIL", area, label, f"説明文が違う: {desc!r} != {b['description']!r}")
            continue
        rep.add("PASS", area, label)

    before, after = live_effective(live), lua_effective(lua)
    for k, items in lua_user.items():
        if k in expected_keys:
            continue
        label = "+".join(k[0] + (k[1],))
        acts = [lua_action(i['dispatcher']) for i in items]
        if before.get(k) and before.get(k) == after.get(k):
            rep.add("PASS", area, label, f"3.x 既定の復元 (実効動作が 3.x と一致): {acts}")
        else:
            rep.add("FAIL", area, label, f"移植版にだけある個人バインド: {acts}")

    if intent["unbinds"]:
        for u in intent["unbinds"]:
            rep.add("FAIL", area, f"unbind {u['mods']} {u['key']}", "unbind の移植チェックは未実装")


def check_effective_binds(rep: Report, live: list, lua: dict) -> None:
    """キーごとの実効動作の集合を比べる。Omarchy 4 既定の変化も含む全体像 (INFO)。"""
    area = "キーバインド (実効・既定込み)"
    def live_set():
        return live_effective(live)

    before = live_set()
    after = lua_effective(lua)
    user_keys = {lua_keys(b["keys"]) for b in lua["binds"] if is_user(b["origin"])}

    only_before = sorted(set(before) - set(after))
    only_after = sorted(set(after) - set(before))
    multi_user = []
    for k in sorted(user_keys):
        if len(after.get(k, ())) > 1:
            multi_user.append(k)

    fmt = lambda k: "+".join(k[0] + (k[1],))
    rep.add("INFO", area, f"3.x にあって 4.x に無いキー: {len(only_before)}個",
            ", ".join(fmt(k) for k in only_before[:40]) + (" …" if len(only_before) > 40 else ""))
    rep.add("INFO", area, f"4.x で増えるキー: {len(only_after)}個",
            ", ".join(fmt(k) for k in only_after[:40]) + (" …" if len(only_after) > 40 else ""))
    for k in multi_user:
        acts = sorted(after[k])
        was = sorted(before.get(k, ()))
        same = "現状と同じく" if len(was) > 1 else "現状は単独だったが"
        rep.add("INFO", area, f"{fmt(k)}: 1キーで複数動作 ({same})",
                f"4.x: {acts}\n         3.x: {was}")


def check_options(rep: Report, intent: dict, live_opts: dict, lua: dict) -> None:
    area = "オプション"
    flat: dict[str, object] = {}
    def walk(prefix, v):
        if isinstance(v, dict):
            for k, vv in v.items():
                walk(f"{prefix}:{k}" if prefix else k, vv)
        else:
            flat[prefix] = v
    for call in lua.get("config_calls", []):
        if is_user(call["origin"]):
            walk("", call["values"])

    for name, info in intent["options"].items():
        want = info["value"]
        live = live_opts.get(name, {})
        live_val = next((live[k] for k in ("str", "int", "float", "bool", "custom") if k in live), None)
        if live_val is not None and not values_equal(live_val, want):
            rep.add("FAIL", area, name, f"ベースラインの実効値 {live_val!r} が .conf の {want!r} と違う")
            continue
        if name not in flat:
            rep.add("FAIL", area, name, f"移植版で未設定 (期待 {want!r})")
        elif not values_equal(flat[name], want):
            rep.add("FAIL", area, name, f"{flat[name]!r} != {want!r}")
        else:
            rep.add("PASS", area, f"{name} = {want!r}")
    for name in sorted(set(flat) - set(intent["options"])):
        rep.add("FAIL", area, name, f"移植版にだけある設定: {flat[name]!r}")


def values_equal(a, b) -> bool:
    if isinstance(a, bool) or isinstance(b, bool):
        truthy = lambda v: v in (True, 1, "1", "true", "on", "yes") if not isinstance(v, bool) else v
        return truthy(a) == truthy(b)
    try:
        return abs(float(a) - float(b)) < 1e-6
    except (TypeError, ValueError):
        return str(a).strip() == str(b).strip()


def check_window_rules(rep: Report, intent: dict, lua: dict) -> None:
    area = "ウィンドウルール"
    ported = []
    for r in lua["window_rules"]:
        if not is_user(r["origin"]):
            continue
        rule = dict(r["rule"])
        match = rule.pop("match", {}) or {}
        name = rule.pop("name", None)
        props = {}
        for k, v in rule.items():
            if isinstance(v, list):
                v = " ".join(str(x) for x in v)
            props[k] = v
        ported.append({"match": match, "props": props, "name": name})

    for want in intent["window_rules"]:
        label = f"{want.get('name') or ''} match={want['match']}".strip()
        hit = None
        for p in ported:
            if p["match"] == want["match"] and all(values_equal(p["props"].get(k), v) for k, v in want["props"].items()) \
                    and set(p["props"]) == set(want["props"]):
                hit = p
                break
        if hit:
            rep.add("PASS", area, label, json.dumps(want["props"], ensure_ascii=False))
            ported.remove(hit)
        else:
            rep.add("FAIL", area, label, f"移植版に一致するルールが無い: 期待 {want['props']}")
    for p in ported:
        rep.add("FAIL", area, f"match={p['match']}", f"移植版にだけあるルール: {p['props']}")


def check_misc(rep: Report, intent: dict, lua: dict, live_monitors: list) -> None:
    # ジェスチャ
    area = "ジェスチャ"
    lua_g = [g["gesture"] for g in lua["gestures"] if is_user(g["origin"])]
    for g in intent["gestures"]:
        want = {"fingers": g["fingers"], "direction": g["direction"], "action": g["action"]}
        if want in lua_g:
            rep.add("PASS", area, f"{g['fingers']}本指 {g['direction']} → {g['action']}")
            lua_g.remove(want)
        else:
            rep.add("FAIL", area, f"{g['fingers']}本指 {g['direction']} → {g['action']}", f"移植版: {lua_g}")
    for g in lua_g:
        rep.add("FAIL", area, str(g), "移植版にだけあるジェスチャ")

    # 起動時コマンド
    area = "起動時コマンド (exec-once)"
    lua_exec = [e["cmd"] for e in lua["on_start"] if is_user(e["origin"])]
    for e in intent["exec_once"]:
        if e["cmd"] in lua_exec:
            rep.add("PASS", area, e["cmd"])
            lua_exec.remove(e["cmd"])
        else:
            rep.add("FAIL", area, e["cmd"], "移植版に無い")
    for cmd in lua_exec:
        rep.add("FAIL", area, cmd, "移植版にだけある")

    # 環境変数
    area = "環境変数 (env)"
    lua_env = {e["key"]: e["value"] for e in lua["env"] if is_user(e["origin"])}
    for e in intent["env"]:
        if lua_env.get(e["key"]) == e["value"]:
            rep.add("PASS", area, f"{e['key']}={e['value']}")
        else:
            rep.add("FAIL", area, f"{e['key']}={e['value']}", "移植版に無い")
    if not intent["env"] and not lua_env:
        rep.add("PASS", area, "個人の env 指定なし (env.conf は hyprland.conf から source されておらず無効)")
    for k in set(lua_env) - {e["key"] for e in intent["env"]}:
        rep.add("FAIL", area, k, "移植版にだけある")

    # モニタ
    area = "モニタ"
    lua_mon = {m["monitor"]["output"]: m["monitor"] for m in lua["monitors"] if is_user(m["origin"])}
    for m in intent["monitors"]:
        parts = [p.strip() for p in m["spec"].split(",")]
        name, mode, pos, scale = parts[:4]
        extra = dict(zip(parts[4::2], parts[5::2]))
        got = lua_mon.pop(name, None)
        if not got:
            rep.add("FAIL", area, name, "移植版に無い")
            continue
        diffs = []
        if got.get("mode") != mode: diffs.append(f"mode {got.get('mode')} != {mode}")
        if got.get("position") != pos: diffs.append(f"position {got.get('position')} != {pos}")
        if not values_equal(got.get("scale"), scale): diffs.append(f"scale {got.get('scale')} != {scale}")
        for k, v in extra.items():
            if not values_equal(got.get(k), v): diffs.append(f"{k} {got.get(k)} != {v}")
        live = next((x for x in live_monitors if x.get("name") == name), None)
        if live is None:
            note = "(取得時に未接続)"
        else:
            note = f"(取得時の実効: {live['width']}x{live['height']}@{live['refreshRate']:.2f} {live['x']}x{live['y']} scale {live['scale']})"
        rep.add("FAIL" if diffs else "PASS", area, f"{name} {mode} {pos} x{scale}", "; ".join(diffs) or note)
    for name in lua_mon:
        rep.add("FAIL", area, name, "移植版にだけある")


# ---------------------------------------------------------------- bar

WAYBAR_TO_QUATTRO = {
    "custom/omarchy": "omarchy.menu",
    "hyprland/workspaces": "omarchy.workspaces",
    "clock": "omarchy.clock",
    "custom/spurs": "spurs",
    "custom/weather": "omarchy.weather",
    "custom/update": "omarchy.system-update",
    "custom/voxtype": "voxtype",
    "custom/screenrecording-indicator": "omarchy.indicators[ScreenRecording]",
    "custom/idle-indicator": "idle",
    "custom/notification-silencing-indicator": "omarchy.indicators[Dnd]",
    "custom/dotfiles": "dotfiles",
    "custom/claude": "claude",
    "group/tray-expander": "omarchy.tray",
    "bluetooth": "omarchy.bluetooth",
    "network": "omarchy.network",
    "pulseaudio": "omarchy.audio",
    "cpu": "cpu",
    "memory": "memory",
    "battery": "omarchy.power",
}

# 同じ動作とみなすコマンドの書き換え (Waybar → Quattro)
COMMAND_EQUIV = {
    "hyprctl dispatch focuswindow class:org.wezfurlong.wezterm":
        "$HOME/dotfiles/scripts/hypr-dispatch 'hl.dsp.focus({ window = \"class:org.wezfurlong.wezterm\" })' focuswindow class:org.wezfurlong.wezterm",
}


def entry_key(e: dict) -> str:
    if e.get("id") == "omarchy.indicators" and e.get("items"):
        return f"omarchy.indicators[{','.join(e['items'])}]"
    return e.get("id", "")


def strftime_to_qt(fmt: str) -> str:
    fmt = re.sub(r"^\{:L?|\}$", "", fmt)
    table = {"%m": "MM", "%d": "dd", "%a": "ddd", "%A": "dddd", "%H": "HH", "%M": "mm", "%B": "MMMM",
             "%b": "MMM", "%Y": "yyyy", "%y": "yy", "%V": "ww", "%S": "ss"}
    out, i = [], 0
    while i < len(fmt):
        tok = fmt[i:i + 2]
        if tok in table:
            out.append(table[tok]); i += 2
        elif fmt[i].isalpha():
            # Qt では英字がフォーマット記号になり得るので引用符で囲む
            j = i
            while j < len(fmt) and fmt[j].isalpha():
                j += 1
            out.append(f"'{fmt[i:j]}'"); i = j
        else:
            out.append(fmt[i]); i += 1
    return "".join(out)


def css_class_colors(css: str, selector: str) -> dict:
    """#custom-xxx.cls { color: ... } を拾う。"""
    colors = {}
    for m in re.finditer(r"#" + re.escape(selector) + r"\.([\w-]+)\s*\{([^}]*)\}", css):
        c = re.search(r"(?<![-\w])color:\s*([^;]+);", m.group(2))
        if c:
            colors[m.group(1)] = c.group(1).strip()
    return colors


def check_bar(rep: Report, base: Path, quattro: Path) -> None:
    area = "バー (Waybar → Quattro)"
    waybar = json.loads((base / "waybar.json").read_text())
    css = (base / "waybar-style.css").read_text()
    shell = json.loads((quattro / ".config/omarchy/shell.json").read_text())
    layout = shell["bar"]["layout"]
    flat = []
    for section in ("left", "centerBegin", "center", "centerEnd", "right"):
        for e in layout.get(section, []):
            flat.append((section, e))
    by_key = {entry_key(e): (s, e) for s, e in flat}

    section_map = {"modules-left": "left", "modules-center": "center", "modules-right": "right"}
    for wsec, qsec in section_map.items():
        wanted = [WAYBAR_TO_QUATTRO.get(m, f"?{m}") for m in waybar.get(wsec, [])]
        got = [entry_key(e) for s, e in flat if (s == qsec or (qsec == "center" and s.startswith("center")))]
        missing = [w for w in wanted if w not in by_key]
        order = [g for g in got if g in wanted]
        if missing:
            rep.add("FAIL", area, f"{wsec} のモジュール", f"移植先が無い: {missing}")
        elif order != wanted:
            rep.add("FAIL", area, f"{wsec} の並び順", f"期待 {wanted}\n         移植 {order}")
        else:
            rep.add("PASS", area, f"{wsec}: {len(wanted)}個・並び順一致", " → ".join(wanted))
        extra = [g for g in got if g not in wanted]
        if extra:
            rep.add("FAIL", area, f"{qsec} に余分なウィジェット", str(extra))

    # custom/* (exec あり) と cpu/memory は設定値まで比較
    for name, conf in waybar.items():
        if not isinstance(conf, dict):
            continue
        target = WAYBAR_TO_QUATTRO.get(name)
        if not target or target not in by_key:
            continue
        _, e = by_key[target]
        if e.get("type") != "qml":
            if name.startswith("custom/") and conf.get("exec"):
                rep.add("FAIL", area, f"{name} → {target}", "Omarchy 標準ウィジェットに置換 (exec の同一性は検査不能)")
            else:
                rep.add("PASS", area, f"{name} → {target}", "Omarchy 標準ウィジェット")
            if name == "clock":
                for wk, qk in (("format", "format"), ("format-alt", "formatAlt")):
                    want = strftime_to_qt(conf.get(wk, ""))
                    rep.add("PASS" if e.get(qk) == want else "FAIL", area, f"clock {wk}",
                            f"{conf.get(wk)} → {e.get(qk)!r}" + ("" if e.get(qk) == want else f" (期待 {want!r})"))
            continue

        checks = []
        if name in ("cpu", "memory"):
            want_exec = f"$HOME/dotfiles/scripts/bar-{name}"
            checks.append(("exec", e.get("exec"), want_exec))
        elif conf.get("exec"):
            checks.append(("exec", e.get("exec", "").replace("command -v voxtype >/dev/null && voxtype status --extended --format json", "omarchy-voxtype-status"), conf["exec"]))
        if "interval" in conf:
            checks.append(("interval", e.get("interval"), conf["interval"]))
        for wk, qk in (("on-click", "onClick"), ("on-click-right", "onRightClick"), ("on-click-middle", "onMiddleClick")):
            if wk in conf or qk in e:
                want = COMMAND_EQUIV.get(conf.get(wk, ""), conf.get(wk, ""))
                checks.append((wk, e.get(qk, ""), want))
        selector = name.replace("/", "-")
        for cls, color in css_class_colors(css, selector).items():
            if color.startswith("alpha("):
                op = re.search(r",\s*([\d.]+)\)", color)
                checks.append((f"css .{cls} opacity", (e.get("classOpacity") or {}).get(cls), float(op.group(1)) if op else None))
            else:
                checks.append((f"css .{cls} color", (e.get("classColors") or {}).get(cls), color))
        base_color = re.search(r"#" + re.escape(selector) + r"\s*\{([^}]*)\}", css)
        if base_color:
            body = base_color.group(1)
            c = re.search(r"(?<![-\w])color:\s*(#[0-9a-fA-F]{6})", body)
            if c:
                checks.append(("css color", e.get("color"), c.group(1)))
            bg = re.search(r"background:\s*alpha\(@foreground,\s*0\.12\)", body)
            checks.append(("css ピル背景", bool(e.get("pill")), bool(bg)))
            pad = re.search(r"padding:\s*0\s+(\d+)px", body)
            if pad:
                checks.append(("css padding", e.get("padding"), int(pad.group(1))))
        for cls, bgc in re.findall(r"#" + re.escape(selector) + r"\.([\w-]+)\s*\{[^}]*background:\s*(#[0-9a-fA-F]{6})", css):
            checks.append((f"css .{cls} background", (e.get("classBackgrounds") or {}).get(cls), bgc))
        if name == "custom/voxtype":
            checks.append(("format-icons", e.get("altText"), conf.get("format-icons")))

        bad = [f"{k}: {got!r} != {want!r}" for k, got, want in checks if not values_equal_loose(got, want)]
        rep.add("FAIL" if bad else "PASS", area, f"{name} → {target} (DotfilesPill)",
                "; ".join(bad) or f"{len(checks)}項目一致 ({', '.join(k for k, *_ in checks)})")


def values_equal_loose(a, b) -> bool:
    if isinstance(a, dict) or isinstance(b, dict):
        return a == b
    if a in (None, "") and b in (None, ""):
        return True
    return values_equal(a, b)


def check_bar_outputs(rep: Report, base: Path, quattro: Path) -> None:
    """DotfilesPill の exec を実際に走らせ、Waybar 形式として読めるか・Waybar 時と同じ形かを見る。"""
    area = "バー出力 (実行して確認)"
    shell = json.loads((quattro / ".config/omarchy/shell.json").read_text())
    baseline_out = json.loads((base / "waybar-outputs.json").read_text())
    rev = {v: k for k, v in WAYBAR_TO_QUATTRO.items()}
    patterns = {
        "cpu": r"^\uf4bc [ \d]\d%$|^\uf4bc 100%$",
        "memory": r"^\uefc5 [ \d]\d%$|^\uefc5 100%$",
    }
    for section in shell["bar"]["layout"].values():
        for e in section:
            if e.get("type") != "qml" or not e.get("exec"):
                continue
            if e["id"] == "voxtype" and not shutil.which("voxtype"):
                rep.add("SKIP", area, "voxtype", "voxtype 未インストール (Waybar 側も非表示だった)")
                continue
            try:
                r = subprocess.run(["bash", "-lc", e["exec"]], capture_output=True, text=True, timeout=30)
            except subprocess.TimeoutExpired:
                rep.add("FAIL", area, e["id"], "30秒でタイムアウト")
                continue
            text = r.stdout.strip()
            try:
                data = json.loads(text) if text else {}
            except json.JSONDecodeError:
                data = {"text": text}
            if e["id"] in patterns:
                ok = re.match(patterns[e["id"]], data.get("text", "")) is not None
                rep.add("PASS" if ok else "FAIL", area, f"{e['id']}: {data.get('text')!r}",
                        f"Waybar の format と同じ形か ({patterns[e['id']]}); tooltip={data.get('tooltip')!r}")
                continue
            prev = baseline_out.get(rev.get(e["id"], ""), {})
            try:
                prev_data = json.loads(prev.get("stdout") or "{}")
            except json.JSONDecodeError:
                prev_data = {"text": prev.get("stdout")}
            same_shape = set(data) == set(prev_data) or not prev
            rep.add("PASS" if same_shape else "FAIL", area, f"{e['id']}: {data.get('text')!r}",
                    f"キー {sorted(data)} (取得時 {sorted(prev_data)})")


# ---------------------------------------------------------------- idle / lock / scripts / static

def check_idle_lock(rep: Report, base: Path, quattro: Path) -> None:
    area = "アイドル・ロック"
    shell = json.loads((quattro / ".config/omarchy/shell.json").read_text())
    idle = shell.get("idle", {})
    conf = (base / "hypridle.conf").read_text()
    listeners = re.findall(r"listener\s*\{([^}]*)\}", conf)
    want = {}
    for body in listeners:
        t = re.search(r"timeout\s*=\s*(\d+)", body)
        cmd = re.search(r"on-timeout\s*=\s*(.+)", body)
        if not t or not cmd:
            continue
        if "screensaver" in cmd.group(1):
            want["screensaver"] = int(t.group(1))
        elif "lock" in cmd.group(1):
            want["lock"] = int(t.group(1))
    for k, v in want.items():
        rep.add("PASS" if idle.get(k) == v else "FAIL", area, f"{k} = {v}秒", f"shell.json idle.{k} = {idle.get(k)}")
    for f in ("hypridle.conf", "hyprlock.conf"):
        same = (base / f"{f}.vs-default").read_text().strip() == "same"
        rep.add("PASS" if same else "FAIL", area, f"{f} は Omarchy 3.x 既定のまま",
                "Quattro の idle/lock は旧既定の挙動・見た目を再現する設計 (上流 README)" if same
                else "個人変更あり: " + (base / f"{f}.vs-default").read_text()[:300])
    if "omarchy.dock" in shell.get("disabledPlugins", []):
        rep.add("PASS", area, "Quattro 新機能の Dock は無効 (3.x に無かったため)")


def check_scripts(rep: Report) -> None:
    area = "dotfiles スクリプト"
    offenders = []
    for path in sorted((DOTFILES / "scripts").iterdir()):
        if not path.is_file() or path.name == "hypr-dispatch":
            continue
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if re.search(r"hyprctl\s+(dispatch|keyword)\b", line) and not line.lstrip().startswith("#"):
                offenders.append(f"{path.name}:{n}: {line.strip()}")
    rep.add("FAIL" if offenders else "PASS", area, "旧書式の hyprctl dispatch/keyword を直接使っていない",
            "\n         ".join(offenders) or "Lua 構成では書式が変わるため scripts/hypr-dispatch 経由に統一")


def check_static(rep: Report, quattro: Path) -> None:
    area = "静的検査"
    luac = shutil.which("luac")
    lua_files = sorted(quattro.rglob("*.lua")) + sorted((DOTFILES / "profiles").rglob("*.lua"))
    if luac:
        bad = []
        for f in lua_files:
            r = subprocess.run([luac, "-p", str(f)], capture_output=True, text=True)
            if r.returncode:
                bad.append(r.stderr.strip())
        rep.add("FAIL" if bad else "PASS", area, f"Lua 構文 ({len(lua_files)}ファイル)", "\n".join(bad))
    else:
        rep.add("SKIP", area, "Lua 構文", "luac が無い")
    for f in sorted(quattro.rglob("*.json")):
        try:
            json.loads(f.read_text())
            rep.add("PASS", area, f"JSON 構文 {f.relative_to(quattro)}")
        except json.JSONDecodeError as e:
            rep.add("FAIL", area, f"JSON 構文 {f.relative_to(quattro)}", str(e))
    qmllint = shutil.which("qmllint") or shutil.which("qmllint6") or ("/usr/lib/qt6/bin/qmllint" if Path("/usr/lib/qt6/bin/qmllint").exists() else None)
    for f in sorted(quattro.rglob("*.qml")):
        if not qmllint:
            rep.add("SKIP", area, f"QML {f.name}", "qmllint が無い (qt6-declarative)。Quattro 移行後に run --live で実表示を確認")
            continue
        r = subprocess.run([qmllint, str(f)], capture_output=True, text=True)
        # Quickshell の import は解決できないので、構文エラーのみを失敗扱い
        syntax = [l for l in (r.stdout + r.stderr).splitlines() if "Syntax" in l or "Expected" in l]
        rep.add("FAIL" if syntax else "PASS", area, f"QML 構文 {f.name}", "\n".join(syntax))


def check_themes(rep: Report) -> None:
    """dotfiles 管理テーマの hyprland.conf (3.x) と hyprland.lua (4.x) の枠線色が同じか。"""
    area = "テーマ (dotfiles 管理)"
    for conf in sorted((DOTFILES / "themes").glob("*/hyprland.conf")):
        lua_file = conf.with_suffix(".lua")
        name = conf.parent.name
        want = dict(re.findall(r"col\.(\w+)\s*=\s*(\S+)", conf.read_text()))
        if not lua_file.exists():
            rep.add("FAIL", area, f"{name}/hyprland.lua", "Quattro 用の hyprland.lua が無い (tools/build_theme.py で生成)")
            continue
        got = dict(re.findall(r"(\w+)\s*=\s*\"(rgba?\([^)]*\))\"", lua_file.read_text()))
        bad = [f"{k}: {got.get(k)} != {v}" for k, v in want.items() if got.get(k) != v]
        rep.add("FAIL" if bad else "PASS", area, f"{name}: 枠線色 {want}", "; ".join(bad))


LEGACY_ONLY = ("waybar/", "omarchy/.config/omarchy/extensions/menu.sh", "quattro/legacy-conf/")


def dotfiles_files():
    skip_dirs = {".git", "tests", "node_modules", "__pycache__"}
    for path in DOTFILES.rglob("*"):
        if not path.is_file() or any(part in skip_dirs for part in path.relative_to(DOTFILES).parts):
            continue
        rel = str(path.relative_to(DOTFILES))
        if rel.startswith("themes/") or rel.endswith((".png", ".jpg", ".pyc", ".lock")) or rel.startswith(".claude/"):
            continue
        try:
            yield rel, path.read_text()
        except (UnicodeDecodeError, OSError):
            continue


def strip_comments(text: str) -> str:
    """行頭コメント (#, --, //) と Python の docstring 行を除く (コマンド呼び出しだけを見るため)。"""
    out, in_doc = [], False
    for line in text.splitlines():
        st = line.strip()
        if st.startswith(('"""', "'''")):
            if not (len(st) > 3 and st.endswith(('"""', "'''"))):
                in_doc = not in_doc
            out.append("")
            continue
        out.append("" if in_doc or st.startswith(("#", "--", "//")) else line)
    return "\n".join(out)


def check_dotfiles_compat(rep: Report, omarchy: Path) -> None:
    """Hyprland/バー以外で Omarchy 4 になると壊れる依存が無いか (dotfiles 全体を走査)。"""
    area = "dotfiles 全体の Omarchy 4 互換"
    files = dict(dotfiles_files())
    active = {k: v for k, v in files.items() if not k.startswith(LEGACY_ONLY) and k != "README.md" and not k.endswith(".md")}

    # 1. 現在テーマの場所 (4.x で ~/.config/omarchy/current は削除される)
    bad = []
    for rel, text in active.items():
        code = strip_comments(text)
        if "config/omarchy/current" not in code:
            continue
        if not re.search(r"local/state[^\n]*omarchy/current|XDG_STATE_HOME[^\n]*omarchy/current|OMARCHY_CURRENT_DIR|current_dir\(\)", code):
            bad.append(rel)
    rep.add("FAIL" if bad else "PASS", area, "現在テーマを旧パス固定で参照していない", ", ".join(bad) or "4.x の ~/.local/state/omarchy/current を優先し、無ければ旧パス")

    # 2. 4.x で無くなるツールを無条件に呼んでいない
    bad = []
    for rel, text in active.items():
        code = strip_comments(text).splitlines()
        for n, line in enumerate(code, 1):
            for tool in ("walker", "makoctl", "swayosd-client", "hyprlock", "hypridle"):
                # コマンドとして実行している形だけ (ファイル名 hyprlock.conf や文中の単語は除く)
                if re.search(rf"(^|[\s|;&(\"\']){tool}(\s+-|\s*$|\s*\||\s+[\"\'])", line) and "pgrep" not in line:
                    guard = "\n".join(code[max(0, n - 4):n])
                    if not re.search(rf"command -v {tool}|cmd_present\(\"{tool}\"\)|BACKEND|running\(\)", guard):
                        bad.append(f"{rel}:{n}: {line.strip()[:80]}")
    rep.add("FAIL" if bad else "PASS", area, "4.x で消えるツール (walker/mako/swayosd/hyprlock/hypridle) を無条件に呼んでいない",
            "\n         ".join(bad) or "使う箇所は存在確認で分岐している")

    # 3. 呼んでいる omarchy-* コマンドが 4.x に存在する
    bin_dir = omarchy / "bin"
    missing = {}
    for rel, text in active.items():
        for cmd in set(re.findall(r"\bomarchy-[a-z0-9-]+", strip_comments(text))):
            if cmd in ("omarchy-quattro", "omarchy-quattro-ref", "omarchy-upgrade-to-quattro", "omarchy-default-dictation", "omarchy-dictation"):
                continue
            if bin_dir.is_dir() and not (bin_dir / cmd).exists():
                missing.setdefault(cmd, []).append(rel)
    rep.add("FAIL" if missing else "PASS", area, f"呼んでいる omarchy-* コマンドが 4.x ({omarchy}) に存在する",
            "\n         ".join(f"{c}: {', '.join(v)}" for c, v in sorted(missing.items())) or "")

    # 4. 3.x のメニュー拡張 (menu.sh) の Dotfiles 項目が 4.x の JSONC に移植済み
    menu_sh = files.get("omarchy/.config/omarchy/extensions/menu.sh", "")
    jsonc_path = DOTFILES / "quattro/.config/omarchy/extensions/omarchy-menu.jsonc"
    if menu_sh and jsonc_path.exists():
        jsonc = json.loads(re.sub(r"^\s*//.*$", "", jsonc_path.read_text(), flags=re.M))
        m = re.search(r'show_dotfiles_menu\(\) \{\s*case \$\(menu "Dotfiles" "([^"]+)"', menu_sh)
        labels = [re.sub(r"^\S+\s+", "", item).strip() for item in m.group(1).split("\\n")] if m else []
        ported = {v.get("label") for k, v in jsonc.items() if k.startswith("setup.config.dotfiles.")}
        lost = [l for l in labels if l not in ported]
        rep.add("FAIL" if lost or not labels else "PASS", area, f"メニュー Setup > Config > Dotfiles ({len(labels)}項目)",
                f"未移植: {lost}" if lost else " / ".join(labels))
    elif menu_sh:
        rep.add("FAIL", area, "メニュー拡張", "quattro/.config/omarchy/extensions/omarchy-menu.jsonc が無い")

    # 5. Omarchy hook は 4.x でも同じ名前で呼ばれる
    hook_bin = (omarchy / "bin/omarchy-hook")
    hooks = sorted(p.name for p in (DOTFILES / "omarchy/.config/omarchy/hooks").iterdir() if p.is_file())
    if hook_bin.exists() and 'HOOK_PATH="$HOME/.config/omarchy/hooks/$1"' in hook_bin.read_text():
        called = [h for h in hooks if re.search(rf"omarchy-hook {re.escape(h)}\b", "".join(p.read_text(errors="ignore") for p in bin_dir.glob("omarchy-*") if p.is_file()))]
        unused = sorted(set(hooks) - set(called))
        rep.add("FAIL" if unused else "PASS", area, f"hook ({', '.join(hooks)}) が 4.x でも呼ばれる",
                f"4.x で呼ばれない hook: {unused}" if unused else "単一ファイル形式の hook も 4.x の omarchy-hook が実行する")


def check_live(rep: Report, base_binds: list, live_after: list, lua: dict) -> None:
    """移行後: 実際の Lua 構成 Hyprland の hyprctl binds と、移行前ベースラインを比べる。"""
    area = "実機 (移行後の hyprctl binds)"
    def index(binds):
        d = defaultdict(set)
        for b in binds:
            key = norm_key(b["key"]) if b["key"] else f"code:{b['keycode']}"
            arg = b.get("arg", "")
            d[(norm_mods(b["modmask"]), key)].add((b.get("dispatcher", ""), arg, b.get("description", "")))
        return d
    before, after = index(base_binds), index(live_after)
    user_keys = {lua_keys(b["keys"]) for b in lua["binds"] if is_user(b["origin"])}
    for k in sorted(user_keys):
        label = "+".join(k[0] + (k[1],))
        b_desc = {d for _, _, d in before.get(k, set())}
        a_desc = {d for _, _, d in after.get(k, set())}
        if not after.get(k):
            rep.add("FAIL", area, label, "移行後の Hyprland に登録されていない")
        elif not (b_desc & a_desc):
            rep.add("FAIL", area, label, f"説明文が一致しない: 移行前 {sorted(b_desc)} / 移行後 {sorted(a_desc)}")
        else:
            rep.add("PASS", area, label, f"{sorted(a_desc)}")


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", type=Path, default=HERE / "baseline")
    ap.add_argument("--lua", type=Path, required=True)
    ap.add_argument("--quattro", type=Path, default=DOTFILES / "quattro")
    ap.add_argument("--live-binds", type=Path)
    ap.add_argument("--omarchy", type=Path, default=Path("/usr/share/omarchy"), help="Omarchy 4 のツリー")
    ap.add_argument("--report", type=Path, help="Markdown で書き出す先")
    ap.add_argument("-v", "--verbose", action="store_true", help="PASS も表示")
    args = ap.parse_args()

    known = json.loads((HERE / "known-diffs.json").read_text()) if (HERE / "known-diffs.json").exists() else {}
    known = {k: v for k, v in known.items() if not k.startswith("_")}
    rep = Report(known)
    base = args.baseline
    intent = json.loads((base / "conf-intent.json").read_text())
    live_binds = json.loads((base / "binds.json").read_text())
    live_opts = json.loads((base / "options.json").read_text())
    live_mon = json.loads((base / "monitors.json").read_text())
    lua = json.loads(args.lua.read_text())

    if lua.get("errors"):
        for e in lua["errors"]:
            rep.add("FAIL", "Lua 評価", "hyprland.lua の評価中にエラー", e[:500])

    check_binds(rep, intent, live_binds, lua)
    check_user_keys_effective(rep, live_binds, lua)
    check_options(rep, intent, live_opts, lua)
    check_window_rules(rep, intent, lua)
    check_misc(rep, intent, lua, live_mon)
    check_bar(rep, base, args.quattro)
    check_bar_outputs(rep, base, args.quattro)
    check_idle_lock(rep, base, args.quattro)
    check_scripts(rep)
    check_static(rep, args.quattro)
    check_themes(rep)
    check_dotfiles_compat(rep, args.omarchy)
    if args.live_binds:
        check_live(rep, live_binds, json.loads(args.live_binds.read_text()), lua)
    check_effective_binds(rep, live_binds, lua)

    print(rep.render(args.verbose))
    if args.report:
        args.report.write_text(rep.markdown() + "\n")
    return 1 if rep.counts().get("FAIL") else 0


if __name__ == "__main__":
    raise SystemExit(main())
