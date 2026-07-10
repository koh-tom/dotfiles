# dotfiles

このディレクトリは、開発環境を構築するための各種設定ファイル（dotfiles）を管理しています。`stow` や `mise` を活用し、各ツールの設定をモジュール化して管理しやすい構成になっています。

## 管理されているツール
- **Zsh**: 基本シェル (`zsh` ディレクトリ)
- **WezTerm**: 高機能ターミナルエミュレータ (`wezterm` ディレクトリ、Windows用フォールバックあり)
- **Mise**: 開発環境・各種CLIツールのバージョンマネージャー (`mise` ディレクトリ)
- **Starship**: プロンプト (`starship` ディレクトリ)
- **Sheldon**: Zshプラグインマネージャー (Mise経由でインストール、Zsh設定から呼び出し)
- **Git**: Git設定 (`git` ディレクトリ)

---

## 🚀 セットアップ手順（初期環境向け）

新しくクローンした環境でセットアップを行うための手順です。

### 1. 必須要件のインストール

設定ファイル群の展開に必要なベースツールと、ターミナル環境をインストールします。お使いのOSに合わせて実行してください。

#### Ubuntu / Debian系の場合
```bash
# 基本ツールのインストール
sudo apt update
sudo apt install -y git curl stow zsh build-essential

# WezTerm のインストール
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update
sudo apt install -y wezterm fonts-jetbrains-mono
```

#### Arch Linux (yayを使用) の場合
```bash
# 基本ツールとWezTerm・フォントのインストール
yay -Syu git curl stow zsh base-devel wezterm ttf-jetbrains-mono-nerd
```

### 2. dotfiles のクローン

ホームディレクトリ直下にクローンします。

```bash
git clone <本リポジトリのURL> ~/dotfiles
cd ~/dotfiles
```

### 3. 設定ファイルの配置 (GNU Stow)

`stow` コマンドを使用して、各ツールのディレクトリから `~/.config` 等の適切な場所へシンボリックリンクを貼ります。

```bash
cd ~/dotfiles

# 各種設定ファイルをホームディレクトリに展開
stow -v git
stow -v mise
stow -v starship
stow -v wezterm
stow -v zsh
```

> **注意 (コンフリクトが発生した場合):**
> もし `WARNING! stowing <package> would cause conflicts:` のようなエラーが出た場合は、すでに環境内に既存の設定ファイルが存在しています。
> 既存のファイルをリネームして退避させてから再度実行してください。
> 例: `mv ~/.config/git/config ~/.config/git/config.bak`

**【Windows / WSL 連携を使っている場合】**
Windows側の WezTerm から WSL へ接続する構成にするため、リポジトリ直下の `.wezterm.lua` は Windows側のホームディレクトリ（`C:\Users\<ユーザ名>\`）にコピーまたはシンボリックリンクを作成してください。
※ 連携機能を使用する場合は、事前に `moonscript` をインストール（Ubuntu: `sudo apt install moonscript`, Arch: `yay -S moonscript`）し、`cd wezterm && make build` で Lua へのコンパイルが必要です。

### 4. Mise による各種ツールのインストール

このリポジトリでは `mise` を使って Node.js, Python, Neovim, Sheldon, Starship などの主要CLIツールを一括管理しています。

```bash
# mise 本体のインストール
curl https://mise.run | sh

# パスを通す（現在のシェルに一時的に）
export PATH="$HOME/.local/bin:$PATH"

# dotfiles に定義されたツールを一括インストール
cd ~/dotfiles
mise install
```
※ `mise/config.toml` に定義された各種ツール（AIツール、TUIユーティリティなど）がインストールされます。

### 5. デフォルトシェルの変更

デフォルトのログインシェルを Zsh に変更します。

```bash
chsh -s $(which zsh)
```

### 6. 環境の初期化

一度ログアウトしてから再ログインするか、ターミナルを再起動して Zsh を起動します。

```bash
zsh
```
初回起動時に `Sheldon` が Zsh プラグインのダウンロードを行い、`Mise` や `Starship` が自動的にロードされてターミナル環境の構築が完了します。

---

## 🛠 ディレクトリ構成

- `zsh/`: Zshの設定 (`.zshenv`, `.config/zsh/`)。Zeno、zsh-defer、fzf-tab等の連携設定を含みます。
- `wezterm/`: WezTermの設定群 (`.config/wezterm/`)。設定がLuaモジュールに分割されています。詳細は `wezterm/docs/wezterm.md` を参照してください。
- `mise/`: 各種言語・TUIツールの構成とエイリアスタスクの設定 (`config.toml`)
- `starship/`: プロンプトのカスタマイズ設定
- `git/`: グローバルな Git 設定

## 💡 更新とメンテナンス

ツール類を一括アップデートするには、以下の `mise` タスクを実行します。
```bash
mise run update
```
※ `mise/config.toml` に設定された `mise run update` タスクにより、`mise` ツールおよびシステムのパッケージアップデートが一括実行されます。
（初期設定では `apt` コマンドが記述されています。Arch Linux をお使いの場合は、`mise/config.toml` 内のタスクを `sudo apt update && sudo apt upgrade -y` から `yay -Syu` 等へ適宜書き換えてご使用ください。）
