#!/usr/bin/env python3
"""Hyprland .conf (Omarchy 3.x 構成) から「個人設定の意図」を抽出して JSON にする。

~/.config/hypr/hyprland.conf から source を辿り、ユーザーが持つファイル
(~/.config/hypr 配下と dotfiles へのリンク) だけを読む。Omarchy 既定
(~/.local/share/omarchy) やテーマ、toggles は対象外。
hyprctl では取り出せない windowrule / gesture / exec-once / env も含めて構造化する。
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys
from pathlib import Path

HOME = Path.home()
USER_ROOTS = [HOME / ".config/hypr", HOME / "dotfiles"]


def is_user_file(path: Path) -> bool:
    real = path.resolve()
    return any(str(real).startswith(str(root.resolve())) or str(path).startswith(str(root)) for root in USER_ROOTS) \
        and ".local/share/omarchy" not in str(real) and "/current/theme/" not in str(path)


def strip_comment(line: str) -> str:
    # '#' から行末までがコメント。'##' はリテラルの '#'
    out, i = [], 0
    while i < len(line):
        if line[i] == "#":
            if line[i:i + 2] == "##":
                out.append("#")
                i += 2
                continue
            break
        out.append(line[i])
        i += 1
    return "".join(out).strip()


def norm_value(v: str):
    v = v.strip()
    low = v.lower()
    if low in ("true", "on", "yes"):
        return True
    if low in ("false", "off", "no"):
        return False
    try:
        return int(v)
    except ValueError:
        pass
    try:
        return float(v)
    except ValueError:
        return v


BIND_RE = re.compile(r"^(bind[a-z]*)$")


class Parser:
    def __init__(self) -> None:
        self.intent = {
            "binds": [], "unbinds": [], "window_rules": [], "options": {}, "gestures": [],
            "exec_once": [], "env": [], "monitors": [], "files": [], "skipped_sources": [],
        }

    def parse_file(self, path: Path) -> None:
        if not path.exists():
            return
        self.intent["files"].append(str(path))
        stack: list[str] = []          # セクション名のスタック (input, touchpad, ...)
        block: dict | None = None      # windowrule { ... } ブロック
        for lineno, raw in enumerate(path.read_text().splitlines(), 1):
            line = strip_comment(raw)
            if not line:
                continue
            where = f"{path}:{lineno}"

            if block is not None:
                if line == "}":
                    self.intent["window_rules"].append(self._rule_from_block(block, where))
                    block = None
                    continue
                key, _, value = line.partition("=")
                block[key.strip()] = value.strip()
                continue

            m = re.match(r"^([\w:.-]+)\s*\{$", line)
            if m:
                if m.group(1) == "windowrule":
                    block = {}
                else:
                    stack.append(m.group(1))
                continue
            if line == "}":
                if stack:
                    stack.pop()
                continue

            key, sep, value = line.partition("=")
            if not sep:
                continue
            key, value = key.strip(), value.strip()

            if stack:
                self.intent["options"][":".join(stack + [key])] = {"value": norm_value(value), "where": where}
                continue

            if key == "source":
                self._source(value, where)
            elif BIND_RE.match(key):
                self._bind(key, value, where)
            elif key == "unbind":
                mods, _, k = value.partition(",")
                self.intent["unbinds"].append({"mods": mods.strip(), "key": k.strip(), "where": where})
            elif key == "windowrule":
                self.intent["window_rules"].append(self._rule_from_line(value, where))
            elif key == "gesture":
                parts = [p.strip() for p in value.split(",")]
                g = {"fingers": int(parts[0]), "direction": parts[1], "action": parts[2], "where": where}
                if len(parts) > 3:
                    g["args"] = parts[3:]
                self.intent["gestures"].append(g)
            elif key == "exec-once":
                self.intent["exec_once"].append({"cmd": value, "where": where})
            elif key == "env":
                k, _, v = value.partition(",")
                self.intent["env"].append({"key": k.strip(), "value": v.strip(), "where": where})
            elif key == "monitor":
                self.intent["monitors"].append({"spec": value, "where": where})
            else:
                self.intent["options"][key] = {"value": norm_value(value), "where": where}

    def _source(self, value: str, where: str) -> None:
        pattern = os.path.expanduser(value)
        for match in sorted(glob.glob(pattern)) or ([pattern] if "*" not in pattern else []):
            p = Path(match)
            if is_user_file(p):
                self.parse_file(p)
            else:
                self.intent["skipped_sources"].append({"source": value, "where": where})

    def _bind(self, kind: str, value: str, where: str) -> None:
        has_desc = "d" in kind[4:]
        n = 4 if has_desc else 3
        parts = [p.strip() for p in value.split(",", n)]
        while len(parts) < n + 1:
            parts.append("")
        if has_desc:
            mods, key, desc, dispatcher, arg = parts
        else:
            mods, key, dispatcher, arg = parts
            desc = ""
        self.intent["binds"].append({
            "flags": kind[4:], "mods": mods, "key": key, "description": desc,
            "dispatcher": dispatcher, "arg": arg, "where": where,
        })

    @staticmethod
    def _rule_from_line(value: str, where: str) -> dict:
        match, props = {}, {}
        for token in (t.strip() for t in value.split(",")):
            if token.startswith("match:"):
                k, _, v = token[len("match:"):].partition(" ")
                match[k] = v.strip()
            else:
                k, _, v = token.partition(" ")
                props[k] = norm_value(v) if v else True
        return {"match": match, "props": props, "where": where}

    @staticmethod
    def _rule_from_block(block: dict, where: str) -> dict:
        match, props, name = {}, {}, block.pop("name", None)
        for k, v in block.items():
            if k.startswith("match:"):
                match[k[len("match:"):]] = v
            else:
                props[k] = norm_value(v)
        rule = {"match": match, "props": props, "where": where}
        if name:
            rule["name"] = name
        return rule


def main() -> int:
    entry = Path(sys.argv[1]) if len(sys.argv) > 1 else HOME / ".config/hypr/hyprland.conf"
    parser = Parser()
    parser.parse_file(entry)
    json.dump(parser.intent, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
