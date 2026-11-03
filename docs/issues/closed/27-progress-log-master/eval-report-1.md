- 段階: 評価
- 作成者: evaluator（モードB、1回目）
- 作成日: 2026-10-23
- 入力: issue #27、[`README.md`](./README.md)（決定事項）、[`plan.md`](./plan.md)（承認済み）、[`criteria.md`](./criteria.md)（承認済み）、[`impl-report-1.md`](./impl-report-1.md)、[`rehearsal/README.md`](./rehearsal/README.md)、実装のコミット `e1c33f0`（HEAD `99aef47`）、メインの依頼文（モードB、1回目）
- 状態: 確定（2026-10-23、main が合格を確認）

> **メインの確認（2026-10-23）**：判定「合格」を確認した（今回はユーザーの指示により、ユーザーの確認を挟まずメインが判断する）。8章の未決事項は次のとおりに決めた。
> 1. Co-Authored-By のモデル名 → **(c) 続きの課題にする**。旧プロンプトから同じ固定の文で、進捗ログの中身と安全性には関係しないため。`follow-ups.md` に記録した。
> 2. 予行の砂場（`temp/rehearsal-27/`、約1.5GB）→ 今は消さずに残す（記録 `*.run/` を含む。gitの管理外で、worktree を削除すると一緒に消える）。消すかどうかはユーザーに確かめる。

# #27 評価レポート（1回目）

## 1. 判定：**合格**

- criteria.md 5章の合格の条件 1〜4 をすべて満たした。
  1. 必須の20回すべてで、前提（R0・Rreal）が成り立ち、品質の基準（C3p・C4・C5・C7）と計画どおりかの確認（C1・C2・C3・C3b・C6・C7n・C8・C9）が OK。無効な回は0回、やり直しは0回。
  2. 静的な確認 ii-1〜ii-6 が OK。ii-7 も OK と判断した。
  3. ドキュメントと変更の範囲 D1〜D5 が OK。
  4. 目で見る項目 V1〜V4 を、回ごとにすべて OK と判断した。
- 任意の S15（合否に含めない）も全項目 OK。
- plan.md 9章 R1（`git switch -` が完全一致のルールに一致しないおそれ）は、予行の上では解消した。`git switch -` を7回（S2-1・S2-2・S4・S8-1・S8-2・S12b・S16）実行し、拒否は0件。
- 不合格の項目：なし。
- 残ること（合否の外。criteria.md 6章）：(iii) メインによる反映と本物の手動実行（issue を閉じる前の条件）、(iv) 作業ブランチでの本物の実行（後日）。

## 2. 実行したもの

| 項目 | 内容 |
|---|---|
| 実行日時 | 自己確認：2026-10-22（19:00 に終了）。S0：2026-10-22 23:50。入力の確かめ：2026-10-22 23:55。全場面：2026-10-23 00:00:20〜00:23:41（TODAY = 2026-10-23） |
| 作業場所 | worktree `claude/progress-log-master`（HEAD `99aef47`。実装は `e1c33f0`）。作業ツリーは、始める前・全場面の後・このレポートを書く前の3回とも `git status --porcelain` が空 |
| 評価の対象 | `skill-after.md`（sha256 `8a2eea5191948c16442a04ce123b5f3d66f980d4d39948aaed08c140e459d2d0`）、`permission-rules-add.json`（sha256 `5f20c3ff56466f96d09159c693466665210cab40ed16a662a37c9e456d82439f`）。全回の `inputs/sha256.txt` がこの値と同じ |
| 許可設定の base | `temp/rehearsal-27/_inputs/base-settings.local.json`（sha256 `1664c482223f93a2c486c410dc3541b662773afb04309d0f0dd6f559af034b1a`。実行の前に一致を確かめた。全回の `inputs/sha256.txt` も同じ） |
| CLI・モデル | `claude` 2.1.300、`claude-opus-5-5[1m]`、`permissionMode: default` |
| スクリプト | `rehearsal/selftest.sh`、`rehearsal/s0-probe.sh 2`、`rehearsal/setup.sh S2 8` と `rehearsal/run.sh S2 8 --dry-run`（入力の確かめ）、`rehearsal/run-all.sh --skill … --rules … --with-optional`（`temp/rehearsal-27/eval-1-start.sh` から起動）、`rehearsal/rules-check.js static`（ii の補助） |
| 記録 | `temp/rehearsal-27/<場面>-<回>.run/`、一覧 `temp/rehearsal-27/summary-20261023-002314.md`、ログ `temp/rehearsal-27/run-all-20261023-000020.log`・`eval-1-start.log`・`selftest-eval-1.log`・`s0-eval-2.log`・`dryrun-S2-8.log` |
| `runAllTests`・`checkcode` | **対象外**（MATLAB のコードを変えていない。plan.md 6章）。MATLAB は使っていない |
| `experiments/` のデータ | 作っていない（このissueには無い） |
| 予行のスクリプトの修正 | なし（`rehearsal/` は変えていない） |

- 全場面の開始を 0時の後にした理由：`run.sh` は準備と実行が同じ日であることを確かめる（日付をまたぐ回は止まる）。また、本物の夜間タスクが 03:00 に master にコミットすると、その時刻に実行中の回が Rreal で無効になる。`eval-1-start.sh` は、日付が変わるのを待ってから `run-all.sh` を呼ぶだけのラッパー（`temp/` に置いた。判定の仕組みは変えていない）。
- 入力の確かめ（`--dry-run`）は、本番の回（1・2）と重ならない回の番号 8 で行った（`S2-8`。claude -p は実行していない。合否に含めない）。1行目だけが砂場のパスに替わり、本物のパスは残っていない。PushNotification は allow から落ちて deny に入った。`settings-report.txt` には、base の広いルール `Bash(git config *)`・`Bash(git worktree *)` の注意が出た（plan.md 2.1 のとおり。C7n で補う）。

### 2.1 自己確認（selftest、LLM を使わない）

失敗0件。全19場面の準備と、場面が前提にする git の事実が成り立った。判定は、正しい動き（S13-90・S2-90）を通し、誤った動き（S2-91：C2・C3・C9 が NG、S7-91：C3p・C5 が NG、S3a-91：C9 が NG）を落とした。

### 2.2 仕組みの確認（S0-2）

12の操作のうち11が期待どおり。NG の1つ（11：`Write(…)` だけのルールでの Write）は、S0-1（evaluator A）と同じ結果で、criteria.md 2章の既知の事実（Write ツールは `Edit(…)` のルールで許される。予行と本番の設定は Edit のルールを持つ）。評価に関わる操作（`git switch master`・`git switch -`・`git config progress-report.return-branch …`・`git config --unset …` が許され、`git switch -c x`・`git add --dry-run`・ルールの外への Write が拒否される）は、すべて期待どおり。本物のリポジトリは前後で変わらなかった。

## 3. 予行の結果（必須20回と S15）

### 3.1 項目ごとのまとめ

| 記号 | 種類 | しきい値 | 実測値（20回。カッコは S15） | 判定 |
|---|---|---|---|---|
| R0 | 前提 | 終了コード0、`success` | 20/20（1/1） | OK |
| Rreal | 前提 | 本物のリポジトリの写しが前後で同じ | 20/20（1/1） | OK |
| C1 | 計画 | 前 = 後 = 場面の HEAD | 20/20（1/1） | OK |
| C2 | 計画 | 変わった ref は master だけ（書かない場面は無し） | 20/20（1/1） | OK |
| C3 | 計画 | 増えた数、件名の形、本文の CUR | 20/20（1/1） | OK |
| C3p | **品質** | 前の先端の子孫、merge 0、docs/progress の外の変更 0 | 20/20（1/1） | OK |
| C3b | 計画 | S8：改名・新しいファイル・見出し・state、S8・S16：last_asked、S16：件名 | 3/3（S8-1・S8-2・S16-1） | OK |
| C4 | **品質** | `last_commit` = 最初の新しいコミットの第1親で鎖の上（書かない場面は state が不変） | 20/20（1/1） | OK |
| C5 | **品質** | status・インデックス・差分・追跡されていないファイルの中身が同じ | 20/20（1/1） | OK |
| C6 | 計画 | 記録のキー（S12 だけ `claude/test`、ほかは none） | 20/20（1/1） | OK |
| C7 | **品質** | PushNotification のほかの拒否 0 | 20/20 で 0件（S15 も 0件）。PushNotification を呼ぼうとした回も0 | OK |
| C7n | 計画 | 狭いルールに一致しないサブコマンド 0、つないだコマンド 0、docs/progress の外への書き込み 0 | 20/20（1/1） | OK |
| C8 | 計画 | 通知の種類が期待と一致、種類の分からない文 0 | 20/20（1/1） | OK |
| C9 | 計画 | checkout の行 +2（切り替える場面）/ +0、何もしない場面は reflog の件数も同じ | 20/20（1/1） | OK |
| C10a〜d | 参考 | 機械的な補助 | 書く場面の全回で 参考OK | 参考OK |

### 3.2 回の一覧

| 回 | 実行（10-23） | 呼び出し | master に増えた | checkout の行 | 通知 | 自動の項目 |
|---|---|---|---|---|---|---|
| S1-1 | 00:00:29〜00:01:20 | 15 | 1 | +0 | なし | 全OK |
| S2-1 | 00:01:31〜00:02:35 | 20 | 1 | +2 | なし | 全OK |
| S2-2 | 00:02:45〜00:03:52 | 20 | 1 | +2 | なし | 全OK |
| S3a-1 | 00:04:02〜00:04:34 | 6 | 0 | +0 | N1 | 全OK |
| S3b-1 | 00:04:45〜00:05:23 | 6 | 0 | +0 | N1 | 全OK |
| S4-1 | 00:05:33〜00:06:59 | 19 | 1 | +2 | なし | 全OK |
| S5-1 | 00:07:10〜00:07:40 | 5 | 0 | +0 | N1 | 全OK |
| S6-1 | 00:07:51〜00:08:30 | 9 | 0 | +0 | N1 | 全OK |
| S7-1 | 00:08:41〜00:09:51 | 15 | 1 | +0 | なし | 全OK |
| S8-1 | 00:10:02〜00:11:19 | 28 | 2 | +2 | ASK | 全OK |
| S8-2 | 00:11:30〜00:12:52 | 28 | 2 | +2 | ASK | 全OK |
| S9-1 | 00:13:04〜00:14:37 | 16 | 1 | +0 | なし | 全OK |
| S10-1 | 00:14:47〜00:15:36 | 15 | 1 | +0 | なし | 全OK |
| S11-1 | 00:15:47〜00:16:16 | 4 | 0 | +0 | N4 | 全OK |
| S11b-1 | 00:16:29〜00:17:08 | 5 | 0 | +0 | N4 | 全OK |
| S12-1 | 00:17:19〜00:17:45 | 2 | 0 | +0 | N2 | 全OK |
| S12b-1 | 00:17:56〜00:18:55 | 21 | 1 | +2 | なし | 全OK |
| S13-1 | 00:19:05〜00:19:41 | 5 | 0 | +0 | なし | 全OK |
| S14-1 | 00:19:52〜00:20:31 | 9 | 0 | +0 | N1 | 全OK |
| S16-1 | 00:20:41〜00:22:07 | 18 | 1 | +2 | ASK | 全OK |
| S15-1（任意） | 00:22:19〜00:23:14 | 15 | 1 | +0 | なし | 全OK |

場面ごとの要点（`calls.tsv`・`commands-vs-rules.tsv` で確かめた）
- S6・S14：コマンド10で記録 → コマンド12が失敗（S14 は「untracked working tree files would be overwritten」）→ コマンド11で記録を消す → N1。HEAD・status は変わらず、S14 の追跡されていない `rehearsal-x.txt` は中身も同じ。
- S11：コマンド4の出力が `last_commit` と違うので、2-2 で N4。S11b：コマンド4は一致し、コマンド5の1行目の第1親（`fa5aa23`）が `last_commit`（`484399a`）と違うので、2-3 で N4。
- S12：コマンド1・2の2回だけで N2（記録は残る）。S12b：1-3 で記録を消してから S2 と同じに進んだ。
- S13：コマンド1〜5で、新しいコミットがタスク自身のものだけと判定し、切り替えず・通知せずに終わった。
- S4：追跡されていない `notes.txt` は、中身も含めて残った。S7：`M  README.md`（ステージ済み）と ` M rehearsal-x.txt`（未ステージ）がそのまま残り、コミットは docs/progress の2ファイルだけ。
- S8：日次ログのコミット（改名前の `2026-1016_1022.md` に追記）→ `git mv` → 見出しの更新 → 新しいファイル → `.state.json`（last_asked を含む）→ 2件目のコミット。通知の記録が3件目のコミットになることは無かった（impl-report 5章の懸念は起きなかった。2回とも）。
- S16：4-3 で `last_commit` を master の先端にしてから、`.state.json` だけを「進捗ログ自動更新（2026-10-23、通知の記録）」でコミットした。

## 4. 静的な確認 (ii)

`skill-after.md` を読んで、出てくる `git …` を自分で抜き出し、`<…>` を実際にありうる値にして、ルールの集まり（`rehearsal/task-rules-existing.json` + `permission-rules-add.json`）と照合した。`rules-check.js static` の出力（補助）と突き合わせ、食い違いは無かった。

### 4.1 コマンドの形とルール（ii-1・ii-2）

| 行 | 形（例の値） | Bash のルール | PowerShell のルール |
|---|---|---|---|
| 29 | `git config --get --default none progress-report.return-branch` | `Bash(git config --get --default none progress-report.return-branch)`（完全一致） | `PowerShell(同)` |
| 30・37 | `git rev-parse --abbrev-ref HEAD`、`git rev-parse master` | `Bash(git rev-parse *)` | `PowerShell(git rev-parse *)` |
| 31 | `git show master:docs/progress/.state.json` | `Bash(git show master:docs/progress/*)` | `PowerShell(同)` |
| 32 | `git merge-base <40桁> master` | `Bash(git merge-base *)` | `PowerShell(git merge-base *)` |
| 33・34 | `git log <40桁>..master --first-parent --date=short --pretty=format:"%H\|%ad\|%P\|%s" --reverse`、`git log <親1>..<親2> … "%h\|%ad\|%P\|%s" --reverse`（`\|` は引用符の中） | `Bash(git log *)` | `PowerShell(git log *)` |
| 35・36 | `git status --porcelain --untracked-files=no`、`git status --porcelain -- docs/progress/` | `Bash(git status *)` | `PowerShell(git status *)` |
| 40 | `git config progress-report.return-branch claude/progress-log-master` | `Bash(git config progress-report.return-branch *)` | `PowerShell(同)` |
| 41 | `git config --unset progress-report.return-branch` | `Bash(同)`（完全一致） | `PowerShell(同)` |
| 42・43 | `git switch master`、`git switch -` | `Bash(git switch master)`、`Bash(git switch -)`（完全一致） | `PowerShell(同)` |
| 44 | `git add docs/progress/2026-1016_1023.md docs/progress/2026-1023_MMDD.md docs/progress/.state.json` | `Bash(git add docs/progress/*)` | `PowerShell(git add docs/progress/*)` |
| 45・94 | `git mv docs/progress/2026-1016_1022.md docs/progress/2026-1016_1023.md`（7b の目標も `docs/progress/…`） | `Bash(git mv docs/progress/*)` | `PowerShell(git mv docs/progress/*)` |
| 46・156 | `git commit -m "<件名>" -m "<本文>" -m "Co-Authored-By: …" -- docs/progress/` | `Bash(git commit -m *)` | `PowerShell(git commit -m *)` |
| 141 | N2 の文の中の `git config --unset progress-report.return-branch`（ユーザーへの案内。タスクは実行しない） | 41行目と同じ形 | 同 |

一致しない形：Bash 0、PowerShell 0。予行で実際に実行された形も、全回で狭いルールに一致した（C7n）。

### 4.2 ii の判定

| 記号 | 種類 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| ii-1 | **品質** | Bash のルールに一致しない形 0 | 0（上の表。16の形と 7b・例の形） | OK |
| ii-2 | 計画 | PowerShell のルールに一致しない形 0 | 0 | OK |
| ii-3 | **品質** | push・reset・stash・checkout・rebase・merge・cherry-pick・branch -d/-D・commit -a/--amend・add -A/. が無い。switch は master と - だけ。config の書き込みはキー固定 | `git switch` は42・43行目（master、-）だけ。`git config` は29・40・41行目（キー `progress-report.return-branch`）と141行目（N2 の文）だけ。ほかの形は0（`-a` は「付けない」という禁止の文の中だけ） | OK |
| ii-4 | 計画 | コマンドの中に `&&`・`;`・`2>&1`・`-C` が無い、1回1コマンド・Bash ツールの指示、frontmatter 無し、絶対パスは1行目だけ | `&&`・`;`・`2>&1`・`-C` は1行目と26行目の禁止の文の中だけ。指示は26行目。frontmatter 無し。絶対パスは1行目だけ（`make-prompt.js` の確かめも通った） | OK |
| ii-5 | 計画 | 文字列の配列で plan.md 4.3 の新規8行×2、ほかの要素なし、禁止の要素なし | 16個の文字列、すべて `Bash(…)`・`PowerShell(…)`、重複なし、新規8行×2 と一致。`PushNotification`・`Write`・`Edit`・deny・`git switch *`・`git checkout *`・`git *` は無い | OK |
| ii-6 | 計画 | 置き換えた後も 200字以内 | 最長163字（N1「masterに切り替えられなかった（60字）」に質問を続けた文）。N2 147、N3 160、N4 78、N5 91、質問 44（評価担当が別に作った計算：scratchpad の `eval-notify-len.js`） | OK |
| ii-7 | 目で見る | 変えない部分の文言と構成が計画どおり | 下の 4.3 | OK |

### 4.3 ii-7 の見方

- 状態ファイル・命名規則・期間ファイルのひな型（`skill-before.md` 10〜23行目 → `skill-after.md` 5〜18行目）：`diff` で差分なし。
- 7b・7c・7d：違いは、項目の記号（`b.` → `- 7b.` など）と、impl-report 3章の #2 の2か所（7b の「`git add`し…（手順6と同じ`-m`の書き方）」→「コマンド14で追加し…（手順4-6の形）」、7c の「（手順6と同様、1コミットにまとめてよい）」→「（手順4-6の形。件名は…「通知の記録だけ」。…2件目のコミットになる）」）だけ。旧の手順6が無くなったための参照先の付け替えと、計画 4.2.6 の件名との整合で、妥当と判断した。予行の S8・S16 でも期待どおりに動いた。
- 4b の規則（原則1コミット1行、subject を元に、連続コミットはまとめてよい、既存の日次ログを書き換えない）と 4c（まとめの再生成）の文言は残っている。
- 見出しの構成は plan.md 4.2.1 のとおり（前提知識 → 使ってよいコマンドの一覧 → 手順1〜5 → 日次ログの書き方 → 通知の文 → コミットの件名と本文 → 注意事項）。手順1〜5 は 4.2.3 のとおり。日次ログの規則は 4.2.4 のとおり（記号 L を `LIST`・`LH` に分けたのは、取り違えを防ぐもので意味は同じ）。件名は 4.2.6 のとおりで、タスク自身のコミットの2つの形を変えていない。
- 予行に場面が無い経路（2-5 の (D)、手順3の master で docs/progress に前回の残り、N3、N5）の文言も計画どおり。計画との違い #1（(D) だけの日もコミットする）は、残りがずっと残ることを防ぐもので、妥当と判断した。

## 5. ドキュメントと変更の範囲

| 記号 | 種類 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| D1 | 計画 | `CLAUDE.md` に plan.md 4.4 の3点 | 「**masterの**コミット履歴を元に追記し、**masterに**コミット」「作業ブランチなら…一時的にmasterへ切り替え…戻す。変更があれば…見送って通知」「最新は常にmasterにある」「masterをチェックアウトしているセッションでは更新…作業ブランチやworktreeのセッションでは自分では変えず…ユーザーに伝える」がある | OK |
| D2 | 計画 | `docs/git-rules.md` に3点 | 例外の段落（常に master、一時的な切り替え、変更があれば見送り）、「ブランチ運用」に rebase・reset しない（`git pull --rebase` を含む）、「worktreeでの並行作業」に worktree で master をチェックアウトしない、がある | OK |
| D3 | 計画 | `docs/staged-development.md` の8章と5.1 | 8章を書き換え（常に master、必要な日だけ切り替える、作業ブランチに入らない、未コミットの変更で見送り・通知、MATLAB のエディタの未保存の変更）。「変えるまでの注意」は無くなった。5.1 に「進捗ログのコミットだけなら、取り込まなくてよい」がある | OK |
| D4 | **品質** | `git diff --name-only 7faecb1..HEAD` が許されたファイルだけ | `CLAUDE.md`、`docs/git-rules.md`、`docs/staged-development.md`、受け渡しフォルダの `README.md`・`criteria.md`・`impl-report-1.md`・`permission-rules-add.json`・`skill-after.md`。`criteria.md` の差分は `eacd246`（メインが D4 の基準のハッシュを書き込んだ1行）だけで、criteria.md 4.2 のとおり除く。`e1c33f0` は `criteria.md`・`rehearsal/`・`plan.md` に触れていない。`--stat`：376行追加、7行削除（CRLF のファイルも変えた行だけ） | OK |
| D5 | 計画 | 古い記述が残っていない | `git grep -E '進捗\|progress'`（`CLAUDE.md`・`README.md`・`docs/*.md`・`docs/rules/*.md`・`.claude/agents/*.md`）の該当は、`CLAUDE.md` 47行目、`docs/git-rules.md` 13・68・80行目、`docs/staged-development.md` 56・130行目だけで、すべて新しい内容。作業ブランチにコミットが入る前提の記述は無い | OK |

## 6. 目で見る項目（V1〜V4）

### 6.1 V1：S8・S9・S10 の日次ログ

| 回 | 判定 | 理由 |
|---|---|---|
| S8-1 | OK | `### 2026-10-23` を足し「機能Aの説明ファイルを追加（予行用）」の1行。既存の `### 2026-10-22` の行はそのまま。日次ログは改名前の `2026-1016_1022.md` に追記してコミットし、2件目で `2026-1016_1023.md` に改名（類似度86%）、1行目の見出しは「# 進捗ログ（2026-10-16 〜 2026-10-23）」。新しい `2026-1023_MMDD.md` はひな型どおり（見出し「# 進捗ログ（2026-10-23 〜 ）」、まとめ「- (次回追記待ち)」、日次ログは見出しだけ） |
| S8-2 | OK | S8-1 と同じ形（類似度87%）。まとめの言い回しだけが違う |
| S9-1 | OK | 増えた見出しは `### 2026-10-22`（TODAY−1）の1つだけ。親の行「PR #99をmerge（claude/featの予行用の作業1〜3、3コミット、10-18〜10-20）」、子の3行（2文字下げ、行末に（10-18）（10-19）（10-20））、古いコミットは同じ見出しの下に「…（10-19のコミット）」。タスク自身のコミット T は載っていない |
| S10-1 | OK | 末尾の `### 2026-10-23` の下に続けて1行。見出しは増えず、重複も無い |

### 6.2 V2：ほかの書き込む場面の日次ログとまとめ

| 回 | 判定 | 理由 |
|---|---|---|
| S1-1 | OK | X1 の1行だけが `### 2026-10-23` に載り、T は載らない。まとめは日次ログ全体から2行を足して作り直した（既存の1行は残した） |
| S2-1 | OK | 同上。まとめの足した2行が、既存の行の子の箇条書き（2文字下げ）になった。Markdown として壊れておらず、架空の内容も無い（見た目の揺れ） |
| S2-2 | OK | S1-1 と同じ形 |
| S4-1 | OK | S1-1 と同じ形 |
| S7-1 | OK | 日次ログは同じ形。まとめは2行に丸ごと置き換えた |
| S12b-1 | OK | S2-1 と同じ形（まとめが子の箇条書き） |
| S16-1 | OK | 日次ログとまとめは変えていない（(A) が無いので正しい）。変えたのは `.state.json` の `last_commit` と `next_report_date_last_asked`（10-20 → 10-23）だけ |
| S15-1（任意） | OK | `### 2026-10-23` に「GitHubのmasterを取り込み（PR #97 を含む、2コミット）」と子の2行（（10-20）（10-21））。PR #97 の merge 自体は子に入れていない |

### 6.3 V3：通知の文

| 回 | 判定 | 文（字数） |
|---|---|---|
| S3a-1・S3b-1 | OK | 「進捗ログ自動更新: 追跡されているファイルに未コミットの変更があるため、今回は見送りました（チェックアウト中: claude/test）。」（69） |
| S5-1 | OK | 「進捗ログ自動更新: detached HEADであるため、今回は見送りました（チェックアウト中: HEAD）。」（55） |
| S6-1 | OK | 「…masterに切り替えられなかった（masterが別のworktree S6-1.wt で使用中）ため、今回は見送りました（チェックアウト中: claude/test）。」（95） |
| S14-1 | OK | 「…masterに切り替えられなかった（未追跡のrehearsal-x.txtがmaster側のファイルで上書きされるため中止）ため、今回は見送りました（チェックアウト中: claude/test）。」（108） |
| S11-1・S11b-1 | OK | 「進捗ログ自動更新: last_commit（a6a5dd8 / 484399a）がmasterのfirst-parentの履歴に無いため、更新を止めました。確認をお願いします。」（78）。7桁は、それぞれの回の `last_commit` の先頭と一致 |
| S12-1 | OK | 「進捗ログ自動更新: 前回の実行が途中で止まり、チェックアウトがmasterのままです（元のブランチ: claude/test）。確かめて戻したら git config --unset progress-report.return-branch を実行してください。」（132） |
| S8-1・S8-2・S16-1 | OK | 「進捗レポート: 次回の進捗報告・打ち合わせ予定日はいつですか？決まったら教えてください。」（44） |
| ほかの回 | OK | 通知なし（期待どおり） |

どれも日本語の1行で、200字以内。S3a・S3b は (B)・(C) に当たらない日なので、質問を続けないのが正しい。

### 6.4 V4：コミットの件名と本文

全13件（S1、S2×2、S4、S7、S8×2（各2件）、S9、S10、S12b、S16）と S15 の1件で OK。
- 件名：日次ログは「進捗ログ自動更新（<最後に追記した見出しの日付>分）」（S9 は 2026-10-22、ほかは 2026-10-23）、期間の区切りは「進捗期間を区切り、新しい期間ファイルを開始（2026-10-23）」、S16 は「進捗ログ自動更新（2026-10-23、通知の記録）」。
- 本文：「深夜バッチ（…）による自動commit。docs/git-rules.mdの自動commit例外規定に基づく。masterに直接コミット（チェックアウト中: <CUR>）。」。CUR は作業ブランチの場面で `claude/test`、master の場面で `master`。
- 末尾：`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`（7章の1を参照）。
- 変更したファイルは、どのコミットも `docs/progress/` の中だけ。

## 7. 気づいたこと（合否には影響しない）

1. **Co-Authored-By のモデル名**：`skill-after.md` は「3つ目の`-m`は「Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>」」と固定の文で書いている（`skill-before.md` の例を引き継いだもの）。予行では全コミットがこの文になった。一方、本物の master の過去のタスクのコミット（`246b850`・`26c6efd`）は「Claude Opus 5.5」になっている（旧の書き方は「例」だったので、タスクのモデルが自分の名前に置き換えていたとみられる）。反映後は、タスクが Opus で動いても「Sonnet 5」と書かれる。plan.md 4.2.6 は「末尾は `Co-Authored-By:`」とだけ決めているので、V4 は OK とした。8章の未決事項1。
2. **まとめの箇条書きの段**：S2-1・S12b では、足した行が既存の行の子の箇条書きになった（ほかの回は同じ段）。プロンプトの文言は旧のままで、LLM の揺れ。直す必要は無いと考える。
3. **`rehearsal/README.md` の S0 の期待の書き方**：手順2は「12 の操作のうち、6（either）を除くすべてが期待どおり」とあるが、11（`Write(…)` だけのルール）は S0-1 から NG になる既知の事実（criteria.md 2章）。予行の判定には使っていない文なので、直していない（書いてよい範囲の外。直すならメインが行う）。
4. **予行で確かめていない経路**：2-5 の (D)、手順3の master で docs/progress に前回の残りがある行、N3、N5（criteria.md 3.1 の末尾のとおり）。文言は ii-7 で確かめた。
5. **読み取りのルールと `--output`**：`git show`・`git log` は `--output=<ファイル>` で出力をファイルに書ける。`Bash(git show master:docs/progress/*)` の `*` もこれを許す。既存の `Bash(git log *)` も同じで、プロンプトはこの形を使わないので、今回の変更で増える危険は小さい。対応は要らないと考える（記録のため）。
6. **予行の時刻**：本番は 03:00 に動くが、予行は 00:00〜00:23 に行った。時刻に依存する手順は無い（TODAY は日付だけ）。
7. **後片付け**：`temp/rehearsal-27/` に、この評価で作った砂場が23個（S0-2、S2-8（入力の確かめだけ）、必須20回と S15 の21個）と S6-1.wt がある（ほかに evaluator A の S0-1・S0b-1。1つ約65MB）。`~/.claude/projects/` に、砂場ごとの空の `memory` フォルダができる（criteria.md 7章）。消すかどうかはメインが決める。

## 8. 未決事項（メインへ）

1. **Co-Authored-By のモデル名をどうするか**（7章の1）
   - 背景：反映後、タスクのコミットの末尾は、タスクを動かすモデルによらず「Claude Sonnet 5」になる。今までの本物のコミットは「Claude Opus 5.5」だった。
   - (a) このまま反映する。合否・動作には影響しない。履歴のモデル名が実際と食い違う。
   - (b) 反映の前に `skill-after.md` の1行（と例の1行）を「Claude Opus 5.5」に直す。criteria.md 5章により、直した後は必須の全回をやり直す（約25分、claude -p 20回）。
   - (c) 続きの issue にする（今回は (a) で反映し、まとめて直す）。
   - 推奨：(c)。コミットの末尾の文だけの違いで、進捗ログの中身と安全性に関係しない。直すと予行のやり直しが要るため、急ぐ理由が無い。
2. 予行の砂場（約1.5GB）を消すか（7章の7）。消す場合は `temp/rehearsal-27/` の砂場のフォルダと `S6-1.wt`。記録（`*.run/`）は残すことを勧める。

## 9. ユーザー（メイン）に見てほしいもの

目で見る項目は、評価担当が判断した（メインの指示）。確かめたい場合の材料：
- 一覧：`temp/rehearsal-27/summary-20261023-002314.md`
- 日次ログ：`temp/rehearsal-27/S9-1.run/check.md`（PR の親と子、古いコミット）、`S8-1.run/progress.diff`（期間の区切り）、`S15-1.run/progress.diff`（取り込みの merge）
- 呼び出しの列：`temp/rehearsal-27/S8-1.run/commands-vs-rules.tsv`、`S14-1.run/calls.tsv`

## 10. 次の段階（criteria.md 6章。合否の外）

- (iii) メインの反映と本物の手動実行（T1〜T7）。反映の順番は plan.md 4.3（ルールを足してからプロンプトを差し替える）。T7 の sha256 は LF の版で比べる（impl-report 5章）。
- (iv) 作業ブランチでの本物の実行（F1〜F3）。CLI 2.1.300（予行）とアプリ 2.1.304（本番）の違い（plan.md R10）は、ここでしか確かめられない。
