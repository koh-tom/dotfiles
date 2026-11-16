# quattro-parity — Omarchy 3.x → 4 移植の同等性検査

「移植前と全く同じ機能か」を機械的に確かめるための仕組み。

```
mise run parity                  # FAIL が無ければ終了コード 0
tests/quattro-parity/run -v      # PASS も全部表示
tests/quattro-parity/run --report /tmp/parity.md   # Markdown 表で出力
tests/quattro-parity/run --live  # 移行後: 実機の hyprctl binds とも比較 (+ Hyprland --verify-config)
```

## 仕組み

1. **ベースライン** (`baseline/`, `capture-baseline`)
   移行前の 3.x セッションで、実際に効いている状態を記録する。
   - `binds.json`: `hyprctl binds -j` (Omarchy 既定と個人設定を合わせた全キーバインド)
   - `options.json`: 個人設定が触るオプションの実効値 (`hyprctl getoption`)
   - `monitors.json`: `hyprctl monitors all -j`
   - `conf-intent.json`: 個人 `.conf` から抽出した意図。windowrule / gesture / exec-once / env
     は hyprctl で取り出せないので、`conf_intent.py` が source を辿って構造化する
   - `waybar*.json`, `waybar-style.css`: バーの構成、スタイル、custom モジュールの出力
   - `hypridle.conf`, `hyprlock.conf`: 中身と、Omarchy 既定との差分の有無

   **移行後は取り直せない**ので、取得した時点で git にコミットする。

2. **移植版の評価** (`lua-harness.lua`)
   `quattro/` を stow 後と同じ形に並べた仮ホームを作り、Omarchy 4 の既定
   (`/usr/share/omarchy`、移行前は上流 v4.5.0 の参照クローン) ごと `hyprland.lua` を評価する。
   Hyprland の Lua API (`hl.*`) を記録用モックに差し替え、登録内容を呼び出し元ファイル付きで
   JSON にする。呼び出し元が仮ホームなら「個人設定」、Omarchy 配下なら「既定」と判定する。
   評価はサンドボックス内で行う (`io.popen` / `os.execute` / 書き込みは実行せず記録だけ)。

3. **突き合わせ** (`compare.py`)

| 区分 | 判定方法 |
|---|---|
| キーバインド (個人設定) | `.conf` の各 bind が、同じキー・同じコマンド・同じ説明文で移植版にあるか。ベースラインの `hyprctl` で実際に効いていたかも確認する |
| キーバインド (個人キーの実効動作) | 個人設定が使うキーについて、既定分も含めた「押したら起きること」の集合が 3.x と完全一致するか。二重起動や既定の上書き漏れを検出する |
| オプション | 移植版の `hl.config` の値が `.conf` の値と同じか、実効値とも一致するか |
| ウィンドウルール / ジェスチャ / exec-once / env / モニタ | 構造化して完全一致を見る |
| バー | Waybar の各モジュールに移植先があるか、並び順、exec・interval・クリック時のコマンド、style.css の色・余白・ピル背景 |
| バー出力 | 移植先のコマンドを実際に実行し、Waybar 形式として読めるか、Waybar 時と同じ形か |
| アイドル・ロック | hypridle の秒数と `shell.json` の `idle`、hyprlock が既定のままか |
| dotfiles スクリプト | 旧書式の `hyprctl dispatch` を直接使っていないか (Lua 構成では書式が変わる) |
| テーマ | dotfiles 管理テーマの `hyprland.conf` と `hyprland.lua` で枠線色が同じか |
| dotfiles 全体の Omarchy 4 互換 | 現在テーマを旧パス固定で参照していないか、Walker 等の消えるツールを存在確認なしで呼んでいないか、呼んでいる omarchy-* コマンドが 4.x にあるか、メニュー拡張の移植、hook が呼ばれるか |
| 静的検査 | Lua 構文、JSON 構文、QML 構文 (qmllint がある場合) |
| 実効・既定込み (INFO) | 全キーの比較。Omarchy 4 の既定変更で増えるキー・消えるキーの一覧 |

判定結果は `PASS` / `FAIL` / `KNOWN` / `INFO` / `SKIP` の5種類。`KNOWN` は、Quattro の仕様上1対1に再現できない差分で、`known-diffs.json` に理由付きで登録したもの。

## 検証の検証

移植版のコピーにわざと誤りを入れて、検出できることを確認した。入れた誤りは、コマンドの書き間違い、ウィンドウルールの欠落、`repeat_rate` の値、ロック時間、SUPER+` の既定との二重実行、バーの色、更新間隔の7種類。7種類とも FAIL になり、終了コードは1だった。
加えて、Walker の無条件呼び出しと、テーマパスの旧パス固定も検出できることを確認した。テーマパスは当初、コメント中の新パスに引っかかって見逃していたため、判定を修正している。

## 限界

- モックは「何を登録したか」を見る。オプション名やディスパッチャ名が Hyprland 0.57 で正しいかは、
  `run --live` の `Hyprland --verify-config` と、移行後の実機比較で確かめる
- バーの描画 (ピルの見た目) は Quickshell 上でしか確認できない
- サンドボックスでは「コマンドがあるか」で分岐する既定 (`o.shell_succeeds`、音声入力など) が
  常に「無い」側で評価される
