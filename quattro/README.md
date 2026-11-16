# quattro — Omarchy 4 (Quattro) 用の移植版設定

Omarchy 3.8.1 (Hyprland `.conf` + Waybar) で使っている個人設定を、Omarchy 4 の構成
(Hyprland Lua + Quickshell バー) に移植したもの。**移植元の `.conf` 群は消さずに残す**。
今の 3.x 環境には一切適用されない (`apply-dotfiles` は Omarchy 4 を検出したときだけ stow する)。

## 移行手順

```
scripts/migrate-to-quattro pre --apply    # 3.x で: ベースライン確認・同等性検査・スナップショット・Hyprland 固定解除
# Omarchy メニュー: Update > Omarchy → Update > Omarchy to Quattro
scripts/migrate-to-quattro post --apply   # 再起動の前に: HYPRLAND_CONFIG 解除・既定 Lua 退避・stow
# 再起動
scripts/migrate-to-quattro verify         # 実機の hyprctl binds と移行前ベースラインを比較
```

`--apply` を付けなければ確認だけで、何も変更しない。

## 対応表

| 移植元 (3.x) | 移植先 (4.x) | 備考 |
|---|---|---|
| `~/.config/hypr/hyprland.conf` | `.config/hypr/hyprland.lua` | 既定バインドから `applications.lua` を外す。3.x はアプリ起動を全部個人の bindings が持っていたため、そのままだと二重起動になる |
| `~/.config/hypr/bindings.conf` | `.config/hypr/bindings.lua` | コマンド文字列は一字一句同じ。既定に「追加」する意味も同じ (`o.bind`) |
| `~/.config/hypr/input.conf` | `.config/hypr/input.lua` | |
| `~/.config/hypr/looknfeel.conf` / `autostart.conf` | 同名 `.lua` | どちらも中身が全部コメントで、上書きは無し |
| `~/.config/hypr/monitors.conf` | `seed/hypr/monitors.lua` | ホスト固有ファイルなので stow しない。`post` でコピーする |
| `hyprland.conf` 直書きの cliphist | `personal/clipboard-history.lua` | Walker が無くなったら標準のクリップボードパネルを開く |
| `hypr/.config/hypr/dropdown.conf` | `personal/dropdown.lua` | Quattro 既定の SUPER+` (Quake コンソール) は置き換える |
| `hypr/.config/hypr/clip-presets.conf` | `personal/clip-presets.lua` | |
| `hypr/.config/hypr/windows.conf` | `personal/windows.lua` | |
| `hypr/.config/hypr/gestures.conf` | `personal/gestures.lua` | |
| 3.x の既定で、4.x で消えるキー | `personal/legacy-defaults.lua` | 電卓キー、SUPER+ミュートキー |
| `~/.config/hypr/env.conf` | (移植しない) | どこからも source されておらず、今も効いていない (実機で確認済み) |
| `hypridle.conf` / `hyprlock.conf` | `.config/omarchy/shell.json` の `idle` | Omarchy 既定のままだった。アイドル時間 150/152 秒を引き継ぐ |
| Waybar `config.jsonc` + `style.css` | `.config/omarchy/shell.json` の `bar` | 並び順はそのまま。custom/* は下の `DotfilesPill.qml` |
| Waybar のピル表示と状態ごとの色 | `.config/omarchy/bar/modules/DotfilesPill.qml` | Waybar 形式 JSON をそのまま読む汎用モジュール |
| Waybar 内蔵の cpu / memory | `scripts/bar-cpu`, `scripts/bar-memory` | Waybar と同じ書式・同じ計算方法 |
| `hyprctl dispatch <旧書式>` | `scripts/hypr-dispatch` | Lua 構成では書式が変わるため。両方の構成で動く |
| `themes/spurs/hyprland.conf` | `themes/spurs/hyprland.lua` | `tools/build_theme.py` で同じ colors.toml から生成 |
| 現在テーマのパス `~/.config/omarchy/current` | `~/.local/state/omarchy/current` を優先 | 4.x の移行スクリプトは旧パスを削除し、互換リンクも作らない。WezTerm・starship・zsh・generate-cli-theme・doctor を両対応にした |
| `omarchy/.config/omarchy/extensions/menu.sh` | `.config/omarchy/extensions/omarchy-menu.jsonc` | Setup > Config > Dotfiles の5項目。Hypridle・Walker 等の編集項目は、ツール自体が無くなるので移植しない |
| `scripts/clip-presets` の `walker --dmenu` | `omarchy-menu-select` / `omarchy-menu-input` | Walker があれば今までどおり Walker を使う |
| `~/.config/hypr/*.conf` (dotfiles 管理外) | `legacy-conf/hypr/` に保管 | `migrate-to-quattro pre` がコピーする。Omarchy の移行スクリプトが書き換え・退避するため |

## 検証

`tests/quattro-parity/` が、移行前の実効状態 (`baseline/`、3.x の `hyprctl` から取得) と、
移植版を Omarchy 4 の既定ごと評価した結果を突き合わせる。詳しくはそのディレクトリの README を参照。

```
mise run parity           # = tests/quattro-parity/run
tests/quattro-parity/run -v
```

## 自動では検証できないこと

- **バーの見た目**: ピルの角丸・余白・色の再現は、設定値 (style.css との対応) までは検査する。
  実際の描画は Quickshell が必要なので、移行後に目で確認する
- **Omarchy 標準ウィジェットへの置き換え**: 天気・更新・録画中・通知停止・Bluetooth・
  ネットワーク・音量・バッテリーは、Omarchy 4 の標準ウィジェットになる。機能は同等だが、
  クリックの割り当てや見た目は Omarchy 4 の仕様に従う (`known-diffs.json` に理由を記載)
- **Bluetooth からバッテリーまでを1本につなげたピル**: 標準ウィジェットを使うため再現しない
