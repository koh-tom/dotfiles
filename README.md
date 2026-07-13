# koh's Omarchy dotfiles

Omarchyを母艦にした、ターミナル中心の個人用dotfilesです。GNU Stowで設定を配置し、miseで開発ツールとメンテナンスタスクを管理します。

## 特徴

- Omarchyの現在テーマ／フォントとWezTerm・Starshipを同期
- WezTermのworkspace、Project Cockpit、Claudeセッション切替、Smart Open
- XDG準拠のZsh履歴・キャッシュ管理
- SpursロゴのfastfetchとカスタムOmarchyテーマ
- ホスト別モニタープロファイル
- `mise run doctor` による一括診断

## Stowパッケージ

| パッケージ | 対象 |
|---|---|
| `git` | Git / delta |
| `mise` | CLIツール、環境変数、タスク、lockfile |
| `starship` | フォールバック用プロンプト設定 |
| `wezterm` | ターミナル、workspace、各種モジュール |
| `zsh` | Zsh、Sheldon、補完、エイリアス |
| `fastfetch` | Spursロゴ付きシステム表示 |
| `omarchy` | テーマテンプレート、フック、メニュー拡張 |
| `waybar` | 日付、CPU、メモリ、音量、バッテリーを表示する上部バー |
| `xdg-terminal` | WezTermを既定端末にする設定 |

## Omarchyでの初回セットアップ

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap-omarchy
```

既存のOmarchy設定と競合するファイルは、同じディレクトリへタイムスタンプ付きでバックアップしてからStowします。`~/.local/share/omarchy/` は変更しません。

セットアップ後に診断します。

```bash
mise install
mise run doctor
```

## 日常の操作

```bash
mise run doctor          # 全設定の診断
mise run apply           # 全Stowパッケージを再適用
mise run update          # Omarchyとシステムを更新
mise run update-tools    # mise管理ツールを更新
mise run apply-profile   # 現在ホストのモニター設定を適用
mise run install-spurs   # Spursテーマを実体ディレクトリへ配置
```

Omarchyメニューの `Setup → Config → Dotfiles` からも、編集、Lazygit、Doctor、再適用、Spurs Modeへアクセスできます。

## WezTerm

主な操作は `CTRL + q` をLEADERとして使います。

| キー | 動作 |
|---|---|
| `LEADER g` | zoxideからProject Cockpitを開く |
| `LEADER l` | Lazygit / Neovim / Yazi / Claudeランチャー |
| `LEADER c` | 実行中のClaude Codeセッション切替 |
| `LEADER w` | workspace選択 |
| `LEADER r/d` | ペイン分割 |
| `LEADER s` | ペインリサイズモード |
| `LEADER o` | URL・ファイル・Git hashをSmart Open |
| `LEADER z` | 直前コマンドと出力をコピー |

詳細は [WezTerm完全ガイド](wezterm/docs/wezterm.md) を参照してください。

## テーマ連携

WezTermは `~/.config/omarchy/current/theme/colors.toml` と `omarchy font current` を直接参照します。Starshipは `omarchy/.config/omarchy/themed/starship.toml.tpl` からテーマ変更時に生成されます。

```bash
omarchy theme set Rainynight
omarchy theme set Spurs
```

テーマ／フォント変更フックはWezTerm設定を自動リロードします。Spursテーマのソースは `themes/spurs/`、インストール先は `~/.config/omarchy/themes/spurs/` です。

## ホスト固有設定

共有しにくいモニター配置は `profiles/<hostname>/hypr/monitors.conf` に分離します。現在は `profiles/omarchy/` が登録されています。

`apply-host-profile` は既存の `~/.config/hypr/monitors.conf` をバックアップし、適用後に `hyprctl reload` と `hyprctl configerrors` を実行します。

## ディレクトリ方針

- 設定ソース: このリポジトリ
- キャッシュ: `$XDG_CACHE_HOME`
- 履歴・診断ログ: `$XDG_STATE_HOME`
- Omarchyカスタムテーマ: `~/.config/omarchy/themes/`
- Omarchy本体: `~/.local/share/omarchy/`。読み取りのみで編集禁止

Windows / WSL向けの旧ローダーとMoonScriptビルドは互換用に残していますが、現在の主対象はOmarchyです。
