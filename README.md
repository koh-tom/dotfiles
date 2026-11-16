# koh's Omarchy dotfiles

Omarchyを母艦にした、ターミナル中心の個人用dotfilesです。GNU Stowで設定を配置し、miseで開発ツールとメンテナンスタスクを管理します。

## 特徴

- Omarchyの現在テーマ／フォントとWezTerm・Starship・fzf・bat・deltaを同期
- `colors.toml` 1枚からOmarchyテーマ一式を生成する `tools/build_theme.py`
- WezTermのworkspace、Project Cockpit (Dev Layout / `.cockpit.lua`)、Smart Open
- Claude Code連携: タブ色が状態(working/waiting/attention)に追従、fzfセッション切替、Waybarセッション数
- Starshipバッジと統一したピル型Waybar (+ dotfilesドリフト表示)
- zenoスニペット、czgコミットフロー、XDG準拠のZsh履歴・キャッシュ管理
- セッション自動保存とペイン分割復元、ホスト別モニタープロファイル
- `mise run doctor` による一括診断とGitHub Actionsの静的チェック

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
| `waybar` | ピル型上部バー (Claudeセッション数、dotfilesドリフト、Spurs次戦付き) |
| `xdg-terminal` | WezTermを既定端末にする設定 |
| `ssh` | 1Password SSH agent優先のSSH設定 |
| `nvim` | Omarchy LazyVimに重ねる自分用プラグイン層 |

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
mise run build-theme     # Spursテーマをcolors.tomlから再生成
mise run install-spurs   # Spursテーマを生成して実体ディレクトリへ配置
mise run commit          # czgで対話式conventional commit
mise run setup-signing   # 1Password SSH agentでコミット署名を有効化
./scripts/install-packages  # packages/*.txt のpacman/AURパッケージを導入
cheat                    # 全キーバインド/スニペット/タスクのfzfチートシート (WezTermではLEADER+/)
```

Omarchyメニューの `Setup → Config → Dotfiles` からも、編集、Lazygit、Doctor、再適用、Spurs Modeへアクセスできます。

## Ubuntu / Debianでの移植セットアップ

Hyprland・Waybar・Omarchyのテーマ連携はOmarchy(Arch)本体が前提の機能なので対象外ですが、**ツール群**(WezTerm・zsh・mise管理ツール・git・fastfetch・nvim層・Spurs静的配色)はUbuntu/Debianへそのまま移植できます。各設定ファイルはOmarchy CLIが無い環境では自動的にデフォルト値へフォールバックする設計です。

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap-ubuntu
```

`bootstrap-ubuntu` は以下を順に行います: `packages/apt.txt` のパッケージ導入(WezTerm/GitHub CLIは公式apt repoを追加)、mise本体のインストール、JetBrainsMono Nerd Fontの導入、`git mise starship wezterm zsh fastfetch ssh nvim` のみをStow、`mise install` でCLIツール一式を導入。セットアップ後は同じく `mise run doctor` で診断できます(Arch/Omarchy専用チェックは自動でスキップされます)。

日常操作は `mise run apply-ubuntu`(縮小Stowセットの再適用)以外は上記と共通です。

## WezTerm

主な操作は `CTRL + q` をLEADERとして使います。

| キー | 動作 |
|---|---|
| `LEADER g` | zoxideからProject Cockpit (Dev Layout等のレシピ選択) |
| `LEADER l` | Lazygit / Neovim / Yazi / Claudeランチャー |
| `LEADER c` | 実行中のClaude Codeセッション切替 (状態・プレビュー付き) |
| `LEADER w` | workspace選択 |
| `LEADER r/d` | ペイン分割 |
| `LEADER s` | ペインリサイズモード |
| `LEADER o` | URL・path:line・owner/repo・Git hashをSmart Open |
| `LEADER i` | Omarchy壁紙を背景に敷くトグル |
| `LEADER z` | 直前コマンドと出力をコピー |
| `LEADER S/D` | セッション手動保存 / リセット (5分毎に自動保存) |

詳細は [WezTerm完全ガイド](wezterm/docs/wezterm.md) を参照してください。

## テーマ連携

WezTermは `~/.config/omarchy/current/theme/colors.toml` と `omarchy font current` を直接参照します。Starshipは `omarchy/.config/omarchy/themed/starship.toml.tpl` からテーマ変更時に生成されます。

さらに `scripts/generate-cli-theme` がテーマ変更のたびに fzf / zsh-autosuggestions の配色を再生成し、bat / delta は `ansi` テーマで端末パレットに自動追従します。テーマを替えるとプロンプト・ターミナル・CLIツールが一斉に染まります。

```bash
omarchy theme set Rainynight
omarchy theme set Spurs
```

テーマ／フォント変更フックはWezTerm設定を自動リロードします。Spursテーマは `themes/spurs/colors.toml` が唯一のソースで、残りのファイルは `mise run build-theme` (`tools/build_theme.py`) が生成します。インストール先は `~/.config/omarchy/themes/spurs/` です。

## Claude Code連携

`claude/hooks.example.json` を `~/.claude/settings.json` にマージすると、Claude Codeのhooksが `scripts/claude-wezterm-state` 経由でWezTermへ状態を通知し、タブアイコン色が working(橙) / waiting(黄) / attention(赤) に変わります。`LEADER c` のセッション切替には画面プレビューと状態が表示され、Waybarには稼働セッション数が出ます。

## ホスト固有設定

共有しにくいモニター配置は `profiles/<hostname>/hypr/monitors.conf` に分離します。現在は `profiles/omarchy/` が登録されています。

`apply-host-profile` は既存の `~/.config/hypr/monitors.conf` をバックアップし、適用後に `hyprctl reload` と `hyprctl configerrors` を実行します。

## HHKB Studio (keyd)

Bluetooth/USBで繋ぐHHKB Studio (日本語配列) を、keydでThinkPad X13 Gen1 (日本語配列) と同じ物理配置にします。対象はHHKBだけで、本体キーボードには影響しません。設定は `system/keyd/hhkb-studio.conf` です。

| HHKBのキー | 送るキー (ThinkPadの同じ位置) |
|---|---|
| 左上 `Esc` | 半角/全角 |
| Aの左 `Control` | Caps (`compose:caps` でCompose) |
| 最下段の左から2番目 `半角/全角` | Ctrl |
| `Fn`+`Esc` (本来は電源) | Esc (ThinkPadで半角/全角の真上) |

それ以外のキー (◇・Alt・無変換・変換・かな・矢印・記号) は元々同じコードなので触りません。`Fn` はキーボード内部で処理されるため、keydでは変えられません。

```bash
./scripts/install-packages  # keyd を導入
./scripts/install-keyd      # /etc/keyd/ へ配置して keyd を有効化・再読込
```

## ディレクトリ方針

- 設定ソース: このリポジトリ
- キャッシュ: `$XDG_CACHE_HOME`
- 履歴・診断ログ: `$XDG_STATE_HOME`
- Omarchyカスタムテーマ: `~/.config/omarchy/themes/`
- Omarchy本体: `~/.local/share/omarchy/`。読み取りのみで編集禁止

## OS依存の切り分け

| 層 | Arch / Omarchy | Ubuntu / Debian |
|---|---|---|
| ツール群 (WezTerm・zsh・mise管理ツール・git・fastfetch・nvim層・Spurs静的配色) | ✅ フル対応 | ✅ `bootstrap-ubuntu` で移植 |
| テーマ連携パイプライン (`omarchy theme set` → colors.toml → 各ツール) | ✅ | ❌ Omarchy本体が必要 |
| Hyprland / Waybar / `omarchy-*` ヘルパー | ✅ | ❌ 対象外 (要Omarchy) |
| HHKB Studioのキー配置 (keyd) | ✅ `install-keyd` | ❌ 未対応 |
| パッケージ管理 | `packages/pacman.txt` / `aur.txt` | `packages/apt.txt` |
| 診断 | `mise run doctor` (フルチェック) | `mise run doctor` (ツール群のみ自動判定) |
