- 段階: 実装
- 作成者: implementer
- 作成日: 2026-10-22
- 入力: issue #27、[`README.md`](./README.md)（決定事項）、[`plan.md`](./plan.md)（承認済み）、[`criteria.md`](./criteria.md)（承認済み）、[`rehearsal/README.md`](./rehearsal/README.md) と予行のスクリプト（読んだだけ）、[`skill-before.md`](./skill-before.md)、メインの依頼文（実装、1回目）
- 状態: 下書き

# #27 実装レポート（1回目）

## 1. 結論

- `plan.md` 5章の手順1〜5を、この順にすべて終えた。
  1. [`skill-after.md`](./skill-after.md)（163行、frontmatterなし、絶対パスは1行目だけ）を書いた。
  2. [`permission-rules-add.json`](./permission-rules-add.json)（plan.md 4.3 の新規の8行を Bash と PowerShell で、16個の文字列の配列）を書いた。
  3. `CLAUDE.md`・`docs/git-rules.md`・`docs/staged-development.md` を plan.md 4.4 のとおりに直した。
  4. 自己確認（静的な照合、禁止の形、読み取りのコマンドの実行、通知の長さ）を行い、問題は無かった（4章）。
  5. このレポートを書いた。
- `runAllTests`・`checkcode`・unitテスト：**対象外**（MATLABのコードを変えていない。plan.md 6章）。受け入れテストの代わりは、criteria.md の ii-1〜ii-7・D1〜D5 と、評価担当の予行（`rehearsal/`。私は実行していない）。
- 計画との違い：**あり（2点。小さい）**。(1) 前回の残り (D) だけの日もコミットする、(2) 7c の「1コミットにまとめてよい」を「4-4 の後なら2件目のコミット」に替えた（3章）。どちらも、計画の手順の順番から必要になったもの。

## 2. 変更したファイル

| ファイル | 新規・変更 | 要点 |
|---|---|---|
| `docs/issues/27-progress-log-master/skill-after.md` | 新規 | 変更後のプロンプトの全文。`update_scheduled_task` の `prompt` にそのまま渡す。sha256 `8a2eea5191948c16442a04ce123b5f3d66f980d4d39948aaed08c140e459d2d0`（作業ツリーのLFの状態） |
| `docs/issues/27-progress-log-master/permission-rules-add.json` | 新規 | `permissions.allow` に足す16個の文字列の JSON 配列。sha256 `5f20c3ff56466f96d09159c693466665210cab40ed16a662a37c9e456d82439f` |
| `docs/issues/27-progress-log-master/impl-report-1.md` | 新規 | このファイル |
| `CLAUDE.md` | 変更（1行） | 進捗レポートの項目：masterの履歴を元にmasterにコミットする、作業ブランチなら一時的に切り替える・変更があれば見送って通知、最新は常にmaster、次回予定日の手での更新はmasterのセッションだけ（作業ブランチ・worktreeではユーザーに伝える） |
| `docs/git-rules.md` | 変更（3か所） | 例外の段落に、masterへのコミットと一時的な切り替え（未コミットの変更があれば見送り）を追加。「ブランチ運用」に、masterをrebase・resetしない（`git pull --rebase` を含む）を追加。「worktreeでの並行作業」の「ブランチ」に、worktreeでmasterをチェックアウトしないを追加 |
| `docs/staged-development.md` | 変更（2か所） | 8章「進捗ログの自動コミット」を書き換え（常にmaster、必要な日だけ切り替える、作業ブランチに入らない、未コミットの変更で見送り・通知、MATLABのエディタに未保存の変更を残さない。「変えるまでの注意」を外した）。5.1「呼ぶ前」に「進捗ログのコミットだけなら、取り込まなくてよい」を追加 |

`CLAUDE.md`・`docs/git-rules.md`・`docs/staged-development.md` は作業ツリーでCRLFのファイルで、差分は変えた行だけ（`git diff --stat`：6行追加、5行削除）。書いてはいけないもの（plan.md・criteria.md・受け渡しフォルダの README.md・skill-before.md・rehearsal/・docs/progress/・.gitignore・.githooks/・.claude/・src/・scripts/・test/・docs/issues/closed/・~/.claude/・temp/rehearsal-27/）には触れていない（`git status --porcelain` は上の5つだけ）。

## 3. 計画との違い

| # | plan.md | 実装 | 理由 |
|---|---|---|---|
| 1 | 4-4「(A) があれば、1件コミットする」 | 「(A) があるか、手順3で前回の残り（(D)）を含めたときは、1件コミットする」 | 2-5 の (D)（masterで docs/progress に前回の残りがある）だけの日に、4-4 でコミットしないと、残りがずっと残り、毎日 (D) になる。件名は「日次ログ」のもの |
| 2 | 4-5「(B)・(C) は、旧7b・7cのとおりに行う（中身は変えない）」 | 7c の「変更をcommitする（手順6と同様、1コミットにまとめてよい）」を「（手順4-6の形。件名は「通知の記録だけ」。手順4-4でコミットした後なら、これは2件目のコミットになる）」に替えた。7b の「まとめて`git add`し」「（手順6と同じ`-m`の書き方）」を「まとめてコマンド14で追加し」「（手順4-6の形）」に替えた | 新しい手順では 4-4（日次ログのコミット）が 4-5 より先なので、7c を (A) のコミットにまとめるには順番を入れ替える指示が要り、文字どおりに追うLLMには分かりにくい。別のコミットにすれば、件名（4.2.6 の「通知の記録だけ」）とも合う。criteria.md 6.1 の T2（「通知の記録が重なれば2件」）とも合う。旧の手順番号（手順6）は新しい構成に無いので、参照先を替えた。バッククォートの `git add` は、静的な照合で「一致なし」と出るので、コマンドの番号で書いた。ほかの 7b・7c の文言は、旧のまま |

### 自分で決めた細部（後の作業に影響しうるもの）

- **記号の名前**：plan.md は、新しいコミットの一覧（2-3）と、日次ログの末尾の見出しの日付（4.2.4）の両方を L と書いている。取り違えを防ぐため、一覧を `LIST`、末尾の見出しの日付を `LH` とした。
- **通知の理由の文**を決めた（N1：「detached HEADである」「masterでマージやcherry-pickが途中である」「追跡されているファイルに未コミットの変更がある」「masterに切り替えられなかった（<gitのメッセージの要約>）」。N3：「進捗ログの変更がコミットされずに残っている」「<gitのメッセージの要約>」「戻った先のブランチが <コマンド2の出力> だった」）。gitのメッセージとエラー内容は60字以内に要約する、と書いた。
- **7b の順番の注記**：旧7bは、コミットの行の後に通知と `next_report_date_last_asked` の更新の行がある（「変更をcommitに含める」）。4-5 の見出しの文に「7bでは、通知の送信と`next_report_date_last_asked`の更新を済ませてから、1回だけコミットする」を足した（7b の本文は変えていない）。
- **前回の残りの扱い**（手順3のmasterの行）：旧手順1の文に「残りの日次ログに、載せるコミットがすでに書かれていれば、手順4-2で同じ行を二重に書かない」を足した（masterの `.state.json` はコマンド3でコミット済みの版を読むので、残りが書いた分が LIST に再び出るため）。
- **1行目**：旧の文に「Read・Write・Editに渡す絶対パスは、このパスの後ろに`docs\progress\<ファイル名>`をつないで作る」を足した（ほかの行に絶対パスを書かずに済ませるため）。
- **前提知識**に「手順2（判定）では、作業ツリーの`docs/progress/`を読まない（作業ブランチでは古いことがある）」を足した。2-6 の下書きは「行の文だけ。見出しの日付は 4-1 で読み直したファイルで決める」とした（切り替える前にmasterの期間ファイルを読むコマンドが一覧に無いため）。
- **4-3** は「この実行の最初のコミットの前に一度だけ。(A) が無く 4-5 だけでコミットする場合も、ここで書く」と書いた（S16 で `last_commit` がmasterの先端に進むように。criteria の C4）。
- **日次ログの規則の補い**：PRの親の行の N（手順2-4で除いた後の中身の数）と MM-DD〜MM-DD（中身の Author Date の最初と最後）の意味、pullの取り込みで PR が複数あるとき「PR #NN・#MM を含む」とする、を書いた。plan.md の例（PR #26）をそのまま載せた。
- **コミットの件名と本文**：3つ目の `-m` は `skill-before.md` のとおり `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`。件名と本文に、二重引用符・バッククォート・ドル記号・改行を入れない、を足した。コマンド16の形の例（作業ブランチ claude/xxx から切り替えた日）を1つ載せた。
- 旧の「`commit`の直後は必ず`-m`とし、`-q`・`--quiet`・`-a`等のオプションは付けない」は、コマンド16の説明に移した。注意事項に「ブランチを切り替えるのは、手順3のコマンド12と、手順5のコマンド13だけ」と「手順3でmasterに切り替えた後にエラーになったら、手順5を試みてから通知する」（plan.md 4.1）を足した。

## 4. 確認の結果

### 4.1 MATLAB

- `checkcode`：対象外（`.m` ファイルを書いていない・変えていない）
- `runAllTests`：対象外（plan.md 6章）。MATLABは使っていない。
- 実データでの動作確認：対象外（`experiments/`・`results/` に何も作っていない）

### 4.2 コマンドの形と許可ルールの対応表（plan.md 4.3。ii-1・ii-2 の自己確認）

照合の規則は README.md の決定事項（`*` の無いルールは完全一致、`x *` は `x` にも一致、Bash と PowerShell は別）。ルールの集まりは `rehearsal/task-rules-existing.json`（既存のタスクのルール）と `permission-rules-add.json`。`rules-check.js static` の出力とも突き合わせ、抜き出された18か所（一覧の16個、7b の `git mv`、コミットの例）が Bash・PowerShell の両方のルールに一致した（「一致なし」0件）。バッククォートの外の `git` は、通知N2の文の中の `git config --unset progress-report.return-branch`（ユーザーへの案内。タスクは実行しない）だけで、これもコマンド11と同じ形。

| # | `skill-after.md` のコマンドの形 | 種類 | Bash のルール | PowerShell のルール | 既存か |
|---|---|---|---|---|---|
| 1 | `git config --get --default none progress-report.return-branch` | 読み | `Bash(git config --get --default none progress-report.return-branch)` | `PowerShell(同)` | 新規（本番の base では `Bash(git config *)` にも一致） |
| 2 | `git rev-parse --abbrev-ref HEAD` | 読み | `Bash(git rev-parse *)` | `PowerShell(git rev-parse *)` | 既存 |
| 3 | `git show master:docs/progress/.state.json` | 読み | `Bash(git show master:docs/progress/*)` | `PowerShell(同)` | 新規 |
| 4 | `git merge-base <last_commit> master` | 読み | `Bash(git merge-base *)` | `PowerShell(git merge-base *)` | 新規 |
| 5 | `git log <last_commit>..master --first-parent --date=short --pretty=format:"%H\|%ad\|%P\|%s" --reverse` | 読み | `Bash(git log *)` | `PowerShell(git log *)` | 既存 |
| 6 | `git log <親1>..<親2> --date=short --pretty=format:"%h\|%ad\|%P\|%s" --reverse` | 読み | `Bash(git log *)` | `PowerShell(git log *)` | 既存 |
| 7 | `git status --porcelain --untracked-files=no` | 読み | `Bash(git status *)` | `PowerShell(git status *)` | 新規 |
| 8 | `git status --porcelain -- docs/progress/` | 読み | `Bash(git status *)` | `PowerShell(git status *)` | 新規 |
| 9 | `git rev-parse master` | 読み | `Bash(git rev-parse *)` | `PowerShell(git rev-parse *)` | 既存 |
| 10 | `git config progress-report.return-branch <ブランチ名>` | 書き | `Bash(git config progress-report.return-branch *)` | `PowerShell(同)` | 新規（同上） |
| 11 | `git config --unset progress-report.return-branch` | 書き | `Bash(git config --unset progress-report.return-branch)` | `PowerShell(同)` | 新規（同上） |
| 12 | `git switch master` | 書き | `Bash(git switch master)` | `PowerShell(git switch master)` | 新規 |
| 13 | `git switch -` | 書き | `Bash(git switch -)` | `PowerShell(git switch -)` | 新規 |
| 14 | `git add docs/progress/<ファイル> [docs/progress/<ファイル> ...]` | 書き | `Bash(git add docs/progress/*)` | `PowerShell(git add docs/progress/*)` | 既存 |
| 15 | `git mv docs/progress/<旧> docs/progress/<新>`（7b の `git mv docs/progress/<current_file> <目標ファイル名>` も、目標が `docs/progress/…` なので同じ形） | 書き | `Bash(git mv docs/progress/*)` | `PowerShell(git mv docs/progress/*)` | 既存 |
| 16 | `git commit -m "<件名>" -m "<本文>" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -- docs/progress/` | 書き | `Bash(git commit -m *)` | `PowerShell(git commit -m *)` | 既存（`-- docs/progress/` は `*` の中） |

（表の中の `\|` は表の区切りと区別するための書き方。`skill-after.md` には `|` と書いてある。`skill-after.md` ではコマンドを表ではなく箇条書きにしたので、`\|` は無い。）

### 4.3 禁止の形（ii-3・ii-4 の自己確認）

`skill-after.md` を検索した結果：

- `&&`・`;`・`2>&1`・`-C`：26行目（「`;`・`&&`・`|`でつながない…`2>&1`などのリダイレクトや`-C`を付けない」という禁止の指示の文）と、1行目（旧の文「`-C`オプションなしで」）だけ。コマンドの中には無い。
- `git switch`：`git switch master`（42行目）と `git switch -`（43行目）だけ。
- `git checkout`・`git stash`・`git reset`・`git push`・`git rebase`・`git merge`（`merge-base` を除く）・`git cherry-pick`・`git branch`・`git pull`・`git commit -a`・`--amend`・`git add -A`・`git add .`：無い。gitの設定の書き込みは、キー `progress-report.return-branch` だけ。
- frontmatter：無い（1行目が「対象リポジトリ: …」）。
- 絶対パス：1行目だけ（`Users`・`HirokiMiwa` の出現は1行目だけ）。`rehearsal/make-prompt.js` を、出力先を scratchpad にして実行し、「1行目に本物のパスがちょうど1つ」「差し替えの後に本物のパスが残っていない」「1行目のほかは同じ」の検査を通ることを確かめた（砂場・`temp/rehearsal-27/` には書いていない）。
- 「1回のツール呼び出しにつき1コマンド」「Bashツールを使う」の指示：26行目にある。

### 4.4 `permission-rules-add.json` の形（ii-5 の自己確認）

JSON の配列、要素は16個の文字列、すべて `Bash(…)` か `PowerShell(…)`。plan.md 4.3 の新規の8行を両方で含み、ほかの要素は無い。重複なし。`PushNotification`・`Write`・`Edit`・deny、`git switch *`・`git checkout *`・`git *` は無い。

### 4.5 読み取りのコマンドの実行（worktree、2026-10-22）

付録Aと同じ形の出力になった。書き込みのコマンド（10〜16）、ブランチの切り替え、gitの設定の書き込み、コミットは実行していない。

| # | 実行した形 | 出力 |
|---|---|---|
| 1 | `git config --get --default none progress-report.return-branch` | `none` |
| 3 | `git show master:docs/progress/.state.json` | `last_commit: 26c6efd4b12271314150a21715766e274245192e`、`next_report_date: null`、`next_report_date_last_asked: 2026-10-21`、`current_file: 2026-1021_MMDD.md` |
| 4 | `git merge-base 26c6efd4b12271314150a21715766e274245192e master` | `26c6efd4…`（一致 → masterの祖先） |
| 5 | `git log 26c6efd4…..master --first-parent --date=short --pretty=format:"%H\|%ad\|%P\|%s" --reverse` | 2行。1行目 `246b8506…\|2026-10-22\|26c6efd4…\|進捗ログ自動更新（2026-10-21分）`（第1親 = last_commit → 鎖の上。タスク自身のコミットなので除く）、2行目 `ba9077da…\|2026-10-22\|246b8506…\|進捗ログのlast_commitをmaster上のコミットに直し、…`（載せる） |
| 6 | `git log cd920723…..32df69a6… --date=short --pretty=format:"%h\|%ad\|%P\|%s" --reverse`（PR #26 の merge `b479770` の親1..親2） | 21行。merge 5件（親が2つ）、タスク自身のコミット 7件、残り9件（plan.md 2.3 の4と同じ） |

（コマンド6の親のハッシュは、`git rev-parse b479770^1 b479770^2` で得た。）

### 4.6 通知の文の長さ（ii-6 の自己確認）

`<CUR>`・`<B>`・`<R>` に `claude/progress-log-master`、gitのメッセージの要約に60字を入れて数えた（scratchpad の `notify-len.js`）。最長は N1（「masterに切り替えられなかった（60字）」）に次回予定日の質問を続けた文で **163字**。すべて200字以内。

| 文 | 最長の字数 |
|---|---|
| N1 | 140（質問を続けると 163） |
| N2 | 147 |
| N3 | 160（理由が60字のgitのメッセージ） |
| N4 | 78 |
| N5 | 91（エラー内容60字） |
| 次回予定日の質問 | 44 |

通知の文は `rehearsal/notify-patterns.json` の語を含む（N1「見送り」、N2「途中で止ま」、N3「戻れ」、N4「last_commit」、N5「エラーが発生」、質問「予定日はいつ」）。ほかの種類の語を含まないことも確かめた（N2の「戻したら」、N4の「止めました」は、それぞれN3・N2の語に当たらない）。

### 4.7 場面ごとの、プロンプトの上での経路（自分で追ったもの。予行の代わりではない）

| 場面 | 経路 | 期待（criteria 3.1）との照合 |
|---|---|---|
| S1・S7・S10 | 1 → 2（(A)）→ 3 master → 4（4-4 で1件）→ 5 は無し | 1件、切り替え無し。S7 は `-- docs/progress/` でステージが残る。S10 は d = LH で見出しが増えない |
| S2・S4・S12b | （S12b は 1-3 で記録を消す）→ 2（(A)）→ 3 作業ブランチ（コマンド7が空。S4 の `notes.txt` は出ない）→ 10・12 → 4（1件）→ 5（8・13・2・11） | 1件、+2、記録 none、本文に `claude/test` |
| S3a・S3b | 2（(A)）→ 3 作業ブランチ、コマンド7が空でない → N1 | 何も変わらない、N1 |
| S5 | 2（(A)）→ 3 `HEAD` → N1 | 何も変わらない、N1 |
| S6・S14 | 2（(A)）→ 3 → 10 → 12 失敗 → 11 → N1 | 何も変わらない、記録 none、N1 |
| S8 | 2（(A)・(B)）→ 3 → 4-4 で1件（改名の前のファイルに追記）→ 4-5 の7b（改名、新しいファイル、質問、last_asked、2件目）→ 5 | 2件、最後の件名が期間の区切り、ASK |
| S9 | 2（T を除き、PR #99 の merge と古いコミット）→ 3 master → 4（`### TODAY−1` に親の行と子の3行、古いコミットは d < LH で「（MM-DDのコミット）」） | 1件、見出しは TODAY−1 だけ |
| S11 | 2-2 で merge-base ≠ last_commit → N4 | 何も変わらない、N4 |
| S11b | 2-3 で1行目（PR #98 の merge）の第1親 ≠ last_commit → N4 | 何も変わらない、N4 |
| S12 | 1-3（R あり、CUR = master）→ N2 | 何も変わらない、記録が残る、N2 |
| S13 | 2（T だけ → (A) 無し。(B)・(C)・(D) も無し）→ 終わる | 何もしない、切り替え無し、通知無し |
| S16 | 2（(C) だけ）→ 3 → 4-3 で last_commit をmasterの先端に → 4-5 の7c（質問、last_asked、「進捗ログ自動更新（TODAY、通知の記録）」の1件）→ 5 | 1件、+2、ASK |

## 5. 評価担当への申し送り

- 入力：`docs/issues/27-progress-log-master/skill-after.md`、`docs/issues/27-progress-log-master/permission-rules-add.json`（rehearsal/README.md の前提どおりの形）。予行は実行していない。`temp/rehearsal-27/` には何も書いていない。
- 特に見てほしい点
  - **S8**：7b の文言は旧のままで、コミットの行が通知の行より前にある。4-5 の見出しに「通知と last_asked の更新を済ませてから1回だけコミットする」と注記したが、LLMが通知の記録を3件目のコミットにしないか（C3 の件数、C3b の最後の件名）。
  - **S16**：4-3 の書き方で `last_commit` がmasterの先端に進むか（C4）。件名「進捗ログ自動更新（TODAY、通知の記録）」（C3b）。
  - **S9**：記号 `LH`（末尾の見出しの日付）を1件ごとに見直す規則どおりに、古いコミットが `### TODAY−1` の下に「（MM-DDのコミット）」付きで入るか（C10・V1）。
  - **ii-7**：7b・7c で文言を替えたのは3章の #2 の3か所だけ。ほかは旧のまま。状態ファイル・命名規則・期間ファイルのひな型の文言は旧のまま。
  - S0 では `git show master:docs/progress/*`・`git merge-base *`・`git status *` のルールを確かめていない（S0 の6で、`git status --porcelain` は組み込みの許可で通った）。予行の C7 で拒否が出ないことと、C7n で狭いルールに一致することを見てほしい。
- 改行：`skill-after.md` は作業ツリーでLF。`.gitattributes` は `* text=auto`、`core.autocrlf=true` なので、別のチェックアウトではCRLFになりうる（`rehearsal/` には `eol=lf` があるが、`skill-after.md` には無い）。`make-prompt.js` はCRLFをLFに直すので予行には影響しない。メインが反映の後に sha256 を比べる（criteria T7）ときは、LFの版で比べる必要がある。
- 自己確認に使った一時ファイル（リポジトリの外）：`C:\Users\owner\AppData\Local\Temp\claude\C--Users-owner-Documents-HirokiMiwa-matlab-Miwa-myResearch\6cef6269-c610-4d20-9b82-6f4fe07fe8d0\scratchpad\notify-len.js`、`…\scratchpad\rules-json-check.js`、`…\scratchpad\prompt-dry.md`（make-prompt.js の出力）。

## 6. 旧（`skill-before.md`）との差分の要約

- frontmatter を外した（`update_scheduled_task` の `prompt` に渡す本文だけ）。1行目に、Read・Write・Edit の絶対パスの作り方を足した。
- 導入に「進捗ログは常にmasterの履歴を読み、masterにコミットする（HEADを基準にしない）」を足した。
- 前提知識：状態ファイル・命名規則・期間ファイルのひな型・例外規定は旧のまま（例外規定に「コミットは常にmasterに対して行う」を足した）。「基準はmaster」「作業ブランチのときの切り替えの考え方と記録のキー」「タスク自身のコミットの見分け方」を足した。旧の許可の範囲と書き込みの形の2項目は、「使ってよいコマンドの一覧」（コマンド1〜16、読み9・書き7）に置き換えた。
- 手順：旧1〜7を、新1〜5に組み替えた（plan.md 4.1 の対応のとおり）。
  - 新1：前回の記録（`progress-report.return-branch`）と、チェックアウト中のブランチを読む。
  - 新2：`HEAD` ではなく `master` を読む（`git show master:…`、`..master --first-parent`）。`last_commit` の2つの確かめ（祖先、first-parentの鎖）、mergeの中身の展開、タスク自身のコミットの除外、(A)〜(D) の判定。やることが無ければ切り替えずに終わる。
  - 新3：detached・masterの途中のマージ・作業ブランチの未コミットの変更では見送ってN1。作業ブランチでは記録してから `git switch master`。旧手順1（前回の残り）はmasterの行に移した。
  - 新4：`last_commit` は `git rev-parse master`。コミットは必ず `-- docs/progress/` 付き。旧7b・7c は 4-5 に入れた（中身は旧のまま。3章の #2 を除く）。
  - 新5：`git switch -` で戻り、記録を消す。戻れなければN3。
- 日次ログの書き方：タスク自身のコミットを載せない。PRのマージは親の行と子の行（元の日付）。見出しの日付は末尾より前に戻さず、同じ日付の見出しを2つ作らない。古い日付のコミットには「（MM-DDのコミット）」。
- 通知：N1〜N5 と次回予定日の質問（旧のまま）。
- コミット：件名に「通知の記録」の形を足した。本文に「masterに直接コミット（チェックアウト中: <CUR>）。」を足した。
- 注意事項：旧の3項目のまま。「切り替えた後にエラーになったら、手順5を試みてから通知する」「ブランチを切り替えるのはコマンド12・13だけ」を足した。

## 7. 未決事項・仮定

- **仮定1：(A) と (C) が同じ日に当たるとき、通知の記録は別のコミット（2件目）にする**（3章の #2）。
  - 背景：旧7cは「1コミットにまとめてよい」だったが、新しい手順では日次ログのコミット（4-4）が 7c（4-5）より先にある。
  - (a) 別のコミットにする（今の実装）。手順が順番どおりで、件名も 4.2.6 の「通知の記録だけ」と合う。masterのコミットが1件増える日がある（3日に1回まで）。
  - (b) まとめる。4-4 の前に 7c の通知と更新を済ませる指示を足す。コミットは減るが、手順の順番の例外が増え、LLMが取り違えやすい。
  - 推奨：(a)。criteria の T2（「通知の記録が重なれば2件」）とも合い、予行の場面（S16）にも影響しないため。
- **仮定2：前回の残り (D) だけの日は、「日次ログ」の件名で1件コミットする**（3章の #1）。予行に場面は無い（criteria 3.1 の末尾）。件名の日付は、残りが追記した最後の見出しの日付になる。
- **仮定3：`CLAUDE.md` の太字の指示は「（Claudeから尋ねた場合に限らず、どのセッションでも）」を残し、「masterをチェックアウトしているセッションでは更新する。作業ブランチやworktreeのセッションでは、ユーザーに伝える」に分けた**（Q6 (a)）。「どのセッションでも」は「どのセッションで伝えられても、何かをする」の意味で残した。
- 質問すべき未決事項は無い。
