---
name: claude-hub
description: このユーザーの Claude Code の「母艦」(常時起動の研究室マシンの tmux で Claude を動かし続け、ラップトップ・自宅 PC・スマホから同じセッションにつなぐ仕組み) と、Claude のセッション・記憶がどこにありどう引き継ぐかの説明。母艦・hub・claude-hub・SUPER+ALT+H・tmux -L hub・Remote Control・スマホから操作・別の端末で続き・セッションの移行や --resume・母艦のディスクの話が出たとき、または今どのマシンで動いているか分からないときに使う。
---

# Claude の母艦 (claude-hub)

会話のコンテキストを端末ごとに散らさず、常時起動のマシン1台 (以下「母艦」) に集めるための仕組み。
ラップトップ・自宅の PC (Windows / Ubuntu)・スマホのどれから触っても、母艦で動いている同じ Claude の続きになる。

```
母艦 (常時起動の Linux マシン)
  tmux (専用ソケット -L hub, セッション名 claude)  ← systemd --user の claude-hub.service が起動時に立てる
    window 1 "rc"      : claude remote-control --name hub  (作業場所 ~/hub。スマホから新しいセッションを始める待ち受け)
    window 2.. 各作業  : claude (プロジェクトごと。Remote Control が自動で有効)
ラップトップ (Omarchy) ─ ssh ─┐   SUPER+ALT+H または claude-hub
自宅 Windows / Ubuntu ─ ssh ──┘   ssh -t <母艦> '~/.local/bin/tmux -L hub -f ~/.config/dotfiles/claude-hub-tmux.conf new -A -s claude'
スマホ ── Claude アプリの Code タブ (Remote Control。確認待ちはプッシュ通知)
```

## 秘密にすること

- 母艦のホスト名・IP・tailnet 名は**公開リポジトリ (koh-tom/dotfiles など) に絶対に書かない**。
  ホスト名はラップトップの `~/.config/dotfiles/claude-hub` (1行) にだけある。必要ならそこから読む。
- GitHub の多重アカウント用の `zsh/.config/zsh/rc/functions/ghpush` はコミットしない。

## いまどこで動いているかの見分け方

```bash
systemctl --user is-enabled claude-hub.service 2>/dev/null   # enabled なら母艦の上
[[ $TMUX == */hub,* ]] && echo "母艦の tmux の中"
cat ~/.config/dotfiles/claude-hub 2>/dev/null                # あればラップトップ (中身が母艦の名前)
```

## コマンド (dotfiles の scripts/claude-hub)

| | |
|---|---|
| `claude-hub` / SUPER+ALT+H | 母艦の tmux につなぐ (無ければ作る) |
| `claude-hub new <dir>` | 母艦の `<dir>` で新しい Claude を開いてつなぐ (`~` は母艦の home) |
| `claude-hub ls` | 母艦で動いている窓の一覧 |
| `claude-hub setup` | 母艦の準備。何度実行してもよい (下記) |

tmux の操作 (prefix は Ctrl+b。ラップトップの WezTerm の LEADER は Ctrl+q なので重ならない):
数字で窓の切り替え、`C` でディレクトリを聞いて新しい Claude、`d` で切断 (Claude は動いたまま)、`r` で設定の読み直し。
設定は `scripts/claude-hub-tmux.conf` → 母艦の `~/.config/dotfiles/claude-hub-tmux.conf`。

`setup` がやること: mise で tmux を入れて `~/.local/bin/tmux` にリンク (sudo 不要)、
`~/.claude/settings.json` に `"remoteControlAtStartup": true`、`~/hub` を作って信頼済みにする、
`claude-hub.service` を有効化、このスキルを母艦の `~/.claude/skills/` にも配る。

## 母艦の注意点

- **`claude` と打つと壊れた古い版が起動する** (母艦の mise に npm 版 claude があり PATH で先に来る)。
  必ず `~/.local/bin/claude` を使う。claude-hub と service はそうしている。
- **母艦の `~/dotfiles` は触らない** (stow で母艦の設定に使われていて、未コミットの変更がある)。
  dotfiles の作業は母艦の `~/hub/dotfiles` (別のクローン) で行う。
- **母艦からラップトップには入れない** (ラップトップに SSH サーバーが無い。スリープもする)。
  ラップトップの Hyprland の再読み込み・omarchy-shell・パリティテスト (`tests/quattro-parity/run`)・スクリーンショットは
  母艦ではできない。母艦では編集・コミット・push まで行い、反映と確認はラップトップで `git pull` してから行う。
- Remote Control の待ち受け (`claude remote-control`) は home では動かない (信頼を保存できないため)。だから `~/hub` で動かす。
  初回は rc 窓で `Enable Remote Control? (y/n)` に y が要る (ユーザーが押す)。
- 母艦への ssh で `Tailscale SSH requires an additional check` と URL が出たら、ユーザーにその URL を開いてもらう。

## セッションと記憶の仕組み (Claude Code)

- 会話の記録はマシンごと: `~/.claude/projects/<作業ディレクトリの / などを - にしたもの>/<セッションID>.jsonl`。
  **公式の同期は無い**。`--resume` / `--continue` は同じマシン・同じ作業ディレクトリの記録しか探さない。
- 記憶 (auto memory) も作業ディレクトリごと: `~/.claude/projects/<同上>/memory/` (MEMORY.md が索引)。
  別のパスでクローンすると別のプロジェクト扱いになる (例: 母艦の `~/hub/dotfiles` は `-home-koh-hub-dotfiles`)。
- **セッションを別のマシンへ移す手順** (2026-11-24 にラップトップの dotfiles の会話を母艦へ移したときの方法):
  1. 移し先の Claude を同じ版にそろえる (`~/.local/bin/claude update`)
  2. `<id>.jsonl` と同名のディレクトリ、`memory/` を、移し先の作業ディレクトリに対応する `~/.claude/projects/<key>/` へ rsync
  3. 移し先の作業ディレクトリで `~/.local/bin/claude --resume <id>`
  4. 元の端末のその会話はそこで止める (両方で続けるとまたずれる)
- Remote Control 中の会話は Anthropic のサーバーにも保存される (claude.ai と同じ扱い)。外に出したくない内容の作業は母艦でも
  `--remote-control` を付けない形で始める判断もありうる。ユーザーに確認すること。
- 母艦の外の選択肢: `claude --cloud` (Anthropic の VM。GitHub のリポジトリが要る。母艦のデータには届かない) と `--teleport`。

## 非公開のメモ

このスキルは公開リポジトリにあるので、母艦固有のこと (ディスク構成・移したフォルダ・作業中のプロジェクト名など) は書かない。
それらは `~/.config/dotfiles/claude-hub.local.md` にある (ラップトップと母艦の両方。`claude-hub setup` が母艦へ配る)。
母艦のディスクや作業場所の話になったら、まずそれを読む。新しく分かった母艦固有のことも、こちらではなくそのファイルに書く。

- 母艦そのもの (Claude 本体・会話の記録・tmux) は 1GB 程度。空きは 50GB 以上を目安にする。
- git で管理しているフォルダをリンクに置き換えて別のディスクへ移すと git が壊れる。移すのは git の管理外の部分だけ。
