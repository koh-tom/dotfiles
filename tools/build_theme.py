#!/usr/bin/env python3
"""Omarchyテーマビルダー: colors.toml 1枚から各アプリのテーマファイルを生成する。

使い方:
    python3 -B tools/build_theme.py [themes/spurs]            # 実機の Omarchy に合わせて自動判定
    python3 -B tools/build_theme.py --legacy [themes/spurs]   # Omarchy 3.x 用の全ファイル
    python3 -B tools/build_theme.py --quattro [themes/spurs]  # Omarchy 4 (Quattro) 用
    python3 -B tools/build_theme.py --list [--legacy|--quattro]  # 生成されるべきファイル名を表示

colors.toml (と backgrounds/) だけ手で書けば、残りを機械生成する。

- Omarchy 4 (Quattro): omarchy-theme-set-templates は「テーマが同名ファイルを同梱していない
  ときだけ」テンプレートから各アプリ設定を生成する。同梱テーマ (/usr/share/omarchy/themes/*)
  と同じく icons.theme / neovim.lua / preview.png だけを出し、alacritty・btop・hyprland・
  chromium 等はテンプレート生成に任せる。3.x 用の生成物が残っていると生成を塞ぐので消す。
  vscode.json も出さない (あると拡張指定とみなされ、テンプレート生成の VS Code テーマが使われない)。
- Omarchy 3.x (--legacy): btop / neovim / hyprland.conf / hyprland.lua / hyprlock / mako /
  swayosd / waybar / alacritty / wofi / cava / chromium / vscode / icons / preview.png を全部出す。

生成物はテーマディレクトリ直下に置かれ、`mise run install-spurs` で Omarchy へリンクされる。
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUATTRO_MARKER = Path("/usr/share/omarchy/default/hypr/bootstrap.lua")

# Quattro の同梱テーマに倣って生成するファイル (colors.toml と backgrounds/ は手書きのソース)
QUATTRO_FILES = ["icons.theme", "neovim.lua", "preview.png"]
# 3.x でだけ生成するファイル。Quattro ではテンプレート生成を塞ぐので消す対象
LEGACY_ONLY_FILES = [
    "alacritty.toml", "btop.theme", "hyprland.conf", "hyprland.lua", "hyprlock.conf",
    "mako.ini", "swayosd.css", "waybar.css", "wofi.css", "cava_theme", "chromium.theme",
    "vscode.json",
]
LEGACY_FILES = QUATTRO_FILES + LEGACY_ONLY_FILES


def is_quattro() -> bool:
    return QUATTRO_MARKER.exists()


def parse_colors(path: Path) -> dict:
    palette = {}
    for line in path.read_text().splitlines():
        m = re.match(r'^\s*([\w]+)\s*=\s*["\'](#[0-9a-fA-F]{6})["\']', line)
        if m:
            palette[m.group(1)] = m.group(2).lower()
    required = ["background", "foreground", "accent"] + [f"color{i}" for i in range(16)]
    missing = [k for k in required if k not in palette]
    if missing:
        sys.exit(f"colors.toml に不足キー: {missing}")
    return palette


def rgba(hex_color: str, alpha: float = 1.0) -> str:
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


def build(theme_dir: Path, quattro: bool) -> None:
    p = parse_colors(theme_dir / "colors.toml")
    sel_bg = p.get("selection_background", p["color0"])
    name = theme_dir.name

    files = {}

    files["alacritty.toml"] = f"""[colors]
[colors.primary]
background = "{p['background']}"
foreground = "{p['foreground']}"

[colors.normal]
black   = "{p['color0']}"
red     = "{p['color1']}"
green   = "{p['color2']}"
yellow  = "{p['color3']}"
blue    = "{p['color4']}"
magenta = "{p['color5']}"
cyan    = "{p['color6']}"
white   = "{p['color7']}"

[colors.bright]
black   = "{p['color8']}"
red     = "{p['color9']}"
green   = "{p['color10']}"
yellow  = "{p['color11']}"
blue    = "{p['color12']}"
magenta = "{p['color13']}"
cyan    = "{p['color14']}"
white   = "{p['color15']}"

[colors.cursor]
text   = "{p['background']}"
cursor = "{p.get('cursor', p['foreground'])}"
"""

    grad = {"start": p["color8"], "mid": p["color4"], "end": p["color3"]}
    graph_sections = "\n".join(
        "\n".join(
            f'theme[{sec}_{pos}]="{col}"' for pos, col in grad.items()
        )
        for sec in ["temp", "cpu", "free", "cached", "available", "used", "download", "upload"]
    )
    files["btop.theme"] = f"""# Generated from {name}/colors.toml by tools/build_theme.py
theme[main_bg]="{p['background']}"
theme[main_fg]="{p['foreground']}"
theme[title]="{p['color15']}"
theme[hi_fg]="{p['accent']}"
theme[selected_bg]="{sel_bg}"
theme[selected_fg]="{p['color15']}"
theme[inactive_fg]="{p['color8']}"
theme[proc_misc]="{p['color7']}"
theme[cpu_box]="{p['color0']}"
theme[mem_box]="{p['color0']}"
theme[net_box]="{p['color0']}"
theme[proc_box]="{p['color0']}"
theme[div_line]="{p['color0']}"
{graph_sections}
"""

    files["hyprland.conf"] = f"""# Generated from {name}/colors.toml by tools/build_theme.py
general {{
    col.active_border = rgb({p['accent'].lstrip('#')})
    col.inactive_border = rgb({p['color0'].lstrip('#')})
}}
"""

    # Omarchy 4 (Quattro) はテーマの hyprland.lua を読む (hyprland.conf は 3.x 用に残す)
    files["hyprland.lua"] = f"""-- Generated from {name}/colors.toml by tools/build_theme.py
hl.config({{
  general = {{
    col = {{
      active_border = "rgb({p['accent'].lstrip('#')})",
      inactive_border = "rgb({p['color0'].lstrip('#')})",
    }},
  }},
}})
"""

    files["hyprlock.conf"] = f"""$color = {rgba(p['background'])}
$inner_color = {rgba(p['background'], 0.66)}
$outer_color = {rgba(p['accent'])}
$font_color = {rgba(p['foreground'])}
$placeholder_color = {rgba(p['foreground'], 0.7)}
$check_color = {rgba(p['color6'])}
"""

    files["mako.ini"] = f"""text-color={p['foreground']}
border-color={p['accent']}
background-color={p['background']}cc
default-timeout=4000
width=360
height=80
padding=8
margin=8
border-size=2
border-radius=12
outer-margin=10
anchor=top-right
layer=overlay
max-icon-size=25

[app-name=Spotify]
invisible=1

[mode=do-not-disturb]
invisible=true

[mode=do-not-disturb app-name=notify-send]
invisible=false
"""

    files["swayosd.css"] = f"""@define-color background-color {p['background']};
@define-color border-color     {p['accent']};
@define-color label            {p['foreground']};
@define-color image            {p['foreground']};
@define-color progress         {p['color3']};

window {{
    background-color: transparent;
    border: none;
    border-radius: 999px;
    padding: 0;
    box-shadow: none;
}}

.osd,
osd {{
    background-color: alpha(@background-color, 0.6);
    border: 1px solid @border-color;
    border-radius: 9999px;
}}

image {{
    color: @image;
    margin: 0 16px 0 0;
}}

label {{
    color: @label;
    font-size: 8px;
}}

progressbar {{
    border-radius: 999px;
    padding-bottom: 8px;
    margin: 8px 0 0 0;
}}

progress {{
    background-color: @progress;
}}
"""

    files["waybar.css"] = f"""@define-color foreground {p['foreground']};
@define-color background {p['background']};
"""

    files["wofi.css"] = f"""@define-color bg {p['background']};
@define-color fg {p['foreground']};
@define-color gray1 {p['accent']};
@define-color gray2 {p['color0']};
@define-color gray3 {p['color8']};
@define-color gray4 {p['color3']};
@define-color gray5 {p['color5']};
@define-color fg_bright {p['color15']};

window {{
    background-color: @bg;
    border: 2px solid @gray3;
}}

input {{
    background-color: @bg;
    color: @fg;
    border: 1px solid @gray2;
}}

input:selected {{
    background-color: @gray1;
    color: @fg_bright;
}}

#entry:selected {{
    background-color: @gray1;
    color: @fg_bright;
}}

#text {{
    color: @fg;
}}

#text:selected {{
    color: @fg_bright;
}}
"""

    files["neovim.lua"] = f"""return {{
	{{
		"RRethy/base16-nvim",
		priority = 1000,
	}},
	{{
		"LazyVim/LazyVim",
		opts = {{
			colorscheme = function()
				require("base16-colorscheme").setup({{
					base00 = "{p['background']}",
					base01 = "{p['color0']}",
					base02 = "{sel_bg}",
					base03 = "{p['color8']}",
					base04 = "{p['color7']}",
					base05 = "{p['foreground']}",
					base06 = "{p['color15']}",
					base07 = "#ffffff",
					base08 = "{p['color1']}",
					base09 = "{p['color9']}",
					base0A = "{p['color3']}",
					base0B = "{p['color2']}",
					base0C = "{p['color6']}",
					base0D = "{p['color4']}",
					base0E = "{p['color5']}",
					base0F = "{p.get('cursor', p['color3'])}",
				}})
			end,
		}},
	}},
}}
"""

    files["icons.theme"] = "Yaru-blue\n"

    # cava (オーディオビジュアライザ): ネイビー→白→イエローのグラデーション
    grad_colors = [p["color4"], p["color12"], p["color7"], p["color15"],
                   p["color11"], p["color3"], p["color11"], p["color15"]]
    cava_lines = "\n".join(
        f"gradient_color_{i + 1} = '{c}'" for i, c in enumerate(grad_colors)
    )
    files["cava_theme"] = f"""[color]
gradient = 1
gradient_count = {len(grad_colors)}
{cava_lines}
"""

    # chromium.theme: ブラウザのフレーム色 (R, G, B)
    bg = p["background"].lstrip("#")
    files["chromium.theme"] = f"{int(bg[0:2], 16)}, {int(bg[2:4], 16)}, {int(bg[4:6], 16)}\n"

    # vscode.json: 専用テーマ拡張が無いため空定義 (存在だけ期待される)
    files["vscode.json"] = "{}\n"

    if quattro:
        files = {k: v for k, v in files.items() if k in QUATTRO_FILES}
        for filename in LEGACY_ONLY_FILES:
            stale = theme_dir / filename
            if stale.is_file():
                stale.unlink()
                print(f"  removed {filename} (Quattro ではテンプレート生成に任せる)")

    for filename, content in files.items():
        (theme_dir / filename).write_text(content)
        print(f"  wrote {filename}")

    try:
        generate_preview(theme_dir, p)
        print("  wrote preview.png")
    except ImportError:
        print("  skip preview.png (Pillow未インストール)")


def generate_preview(theme_dir: Path, p: dict) -> None:
    from PIL import Image, ImageDraw

    w, h = 800, 500
    img = Image.new("RGB", (w, h), p["background"])
    draw = ImageDraw.Draw(img)

    # アクセントのヘッダーバンドと疑似ウィンドウ
    draw.rounded_rectangle([40, 40, w - 40, h - 40], radius=16, fill=p["color0"])
    draw.rounded_rectangle([40, 40, w - 40, 90], radius=16, fill=p["accent"])
    for i, cx in enumerate([70, 95, 120]):
        draw.ellipse([cx - 8, 57, cx + 8, 73], fill=[p["color1"], p["color3"], p["color2"]][i])

    # パレットスウォッチ 2段
    swatches = [p[f"color{i}"] for i in range(16)]
    size, gap, x0, y0 = 80, 8, 64, 130
    for i, color in enumerate(swatches):
        row, col = divmod(i, 8)
        x = x0 + col * (size + gap)
        y = y0 + row * (size + gap)
        draw.rounded_rectangle([x, y, x + size, y + size], radius=10, fill=color)

    # 疑似プロンプト
    y = y0 + 2 * (size + gap) + 30
    draw.text((x0, y), "~/dotfiles ❯", fill=p["accent"])
    draw.text((x0 + 110, y), "omarchy theme set " + theme_dir.name, fill=p["foreground"])
    draw.text((x0, y + 30), "COYS", fill=p["color3"])

    img.save(theme_dir / "preview.png")


def main() -> None:
    parser = argparse.ArgumentParser(description="colors.toml から Omarchy テーマファイルを生成する")
    parser.add_argument("theme_dir", nargs="?", default="themes/spurs")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--legacy", action="store_true", help="Omarchy 3.x 用の全ファイルを生成")
    mode.add_argument("--quattro", action="store_true", help="Omarchy 4 (Quattro) 用だけを生成")
    parser.add_argument("--list", action="store_true", help="生成されるべきファイル名を表示して終了")
    args = parser.parse_args()

    quattro = args.quattro or (not args.legacy and is_quattro())
    expected = ["colors.toml"] + (QUATTRO_FILES if quattro else LEGACY_FILES)
    if args.list:
        print("\n".join(expected))
        return

    target = Path(args.theme_dir)
    if not target.is_absolute():
        target = ROOT / target
    print(f"Building theme: {target} ({'Omarchy 4 / Quattro' if quattro else 'Omarchy 3.x'})")
    build(target, quattro)
    print("Done. `mise run install-spurs` で配置できます。")


if __name__ == "__main__":
    main()
