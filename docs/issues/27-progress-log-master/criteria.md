- 段階: 評価基準
- 作成者: evaluator（モードA、1回目）
- 作成日: 2026-10-22
- 入力: issue #27、[`README.md`](./README.md)（決定事項）、[`plan.md`](./plan.md)（承認済み。特に 4.2〜4.5・7章・9章）、[`skill-before.md`](./skill-before.md)、メインの依頼文（モードA、1回目）
- 状態: 承認済み（2026-10-22、main。今回はユーザーの指示により、メインが承認する。8章の未決事項はすべて推奨どおりに決定）

# #27 評価基準

## 1. 結論

- 合否は、**予行**（砂場での `claude -p`。plan.md 7.1 の必須の17場面（S0〜S14、S11b、S12b）に S16 を足した18場面。S0 を除く実行は20回）、**静的な確認 (ii)**、**ドキュメントと変更の範囲**、**目で見る項目**の4つで決める。評価の項目は30（予行の自動の項目12と前提2、静的7、ドキュメント5、目で見る4）。
- しきい値はすべて「満たす／満たさない」の2値。1つの回でも、1つの項目でも外れたら不合格にする（4章）。
  - **品質の基準**（外れたら不合格）：C3p（masterを書き換えず、docs/progress だけをコミット）、C4（`last_commit` がmasterの鎖の上）、C5（作業ツリーとインデックスが変わらない）、C7（PushNotification のほかに拒否が無い）、ii-1（すべてのコマンドの形が Bash のルールに一致）、ii-3（push や破壊的な形が無い）、D4（変えてはいけないファイルに差分が無い）。
  - **計画どおりかの確認**：C1・C2・C3・C3b・C6・C7n・C8・C9、ii-2・ii-4〜ii-6、D1〜D3・D5。根拠は計画の設計そのもの。実装が計画どおりなら満たす、という確認で、品質の基準ではない。LLMの揺れ1回で外れるので、余裕は小さい（S2・S8 は2回行う）。
  - **目で見る項目**（評価担当Bが判断。ユーザーの確認は要らない）：V1〜V4（日次ログ、通知の文、コミットの件名と本文）、ii-7（変えない部分の文言と構成）。
- (iii)（メインによる本物の手動実行）は**合否に含めない**。評価に合格して反映した後の「反映後の確認」で、issueを閉じる前の条件にする（6章）。(iv)（作業ブランチでの本物の実行）は合否の外で、後日に行う（6章）。
- **仕組みの確認（S0）は済んだ（2026-10-22）。予行のやり方 (a) は成り立つ**（2章）。`git switch -` は、ヘッドレスの CLI 2.1.300 で完全一致のルール `Bash(git switch -)` に一致した（plan.md 9章 R1 の予行での確認）。

## 2. 仕組みの確認（S0・S0b、2026-10-22 に evaluator A が実行）

記録：`temp/rehearsal-27/S0-1.run/`、`S0b-1.run/`。手順と詳細は [`rehearsal/README.md`](./rehearsal/README.md) の末尾。

| 確かめたこと | 結果 | 評価への影響 |
|---|---|---|
| 砂場を作れる | `setup.sh S2 1` で作れた。その後 `selftest.sh` で、全19場面の準備と、場面が前提にするgitの事実（例：S11b の `last_commit` は祖先だが鎖の上に無い、S6・S14 で `git switch master` が失敗して何も変わらない）を確かめた（失敗0件）。clone の前後で worktree の `git status --porcelain` は同じ | — |
| 砂場で `claude -p` が動く | 動いた（S0：44秒、S0b：37秒）。親のセッションの `CLAUDE*` の環境変数を外して起動した | Q8 (a) で進める |
| 許可していない形が、承認待ちにならず拒否として記録される | `git switch -c x` などが `permission_denials` に記録された（`--permission-prompts none`） | C7 はこの記録で判定する |
| 砂場の `settings.local.json` が効く | 許可した `git log -1`、`git config progress-report.return-branch s0-probe`（書き込み）、`git switch master`、`git switch -`、`git config --unset …` は拒否されなかった。worktree の設定（`Bash(git add *)`）は砂場に漏れなかった | — |
| 組み込みの読み取りの許可 | ルールの無い `git status --porcelain` は許された | 読み取りのコマンドのルールの不足は C7 では見えない。ii-1 と C7n で補う |
| Write・Edit のルール | **Write ツールは `Edit(…)` のルールで許される。`Write(…)` だけのルールは効かなかった**（パスに `.claude` を含まない場所でも同じ） | 砂場の設定では `Edit(…/docs/progress/**)` を砂場のパスに書き換える（`make-settings.js`）。本番も Edit のルールで書けている |
| PushNotification | ヘッドレスのツールの一覧に入っていた。S0・S0b では呼ばれなかった | 予行では allow に入れず、deny と `--disallowedTools` で止める |

判定の仕組みの自己確認（`selftest.sh`、LLM を使わない）：手で再現した動きで、計画どおりの動き（S2-90）と何もしない動き（S13-90）は全項目 OK、作業ブランチにコミットする今のタスクの動き（S2-91）は C2・C3・C9 が NG、パス指定の無いコミット（S7-91）は C3p・C5 が NG、変更があるのに切り替える動き（S3a-91）は C9 が NG になった。

## 3. 予行

### 3.1 場面と期待値

全場面の共通の土台：clone した master の上に、予行用の期間ファイルと `.state.json` を置くコミット（B1）、前回のタスク自身のコミットに当たる「進捗ログ自動更新（…分）」（T。`last_commit` = B1）を作る。載せるコミット X1（「機能Aの説明ファイルを追加（予行用）」）は TODAY の日付。次回予定日は、指定の無い場面では TODAY+10（7b・7c に当たらない）。準備は `rehearsal/setup.sh`、期待値はその回の `scene.env` に書かれる。

| 場面 | 準備 | HEAD | masterに増える | 切り替え（checkout の行） | 通知 | 記録（後） | そのほかの期待 | 回数 |
|---|---|---|---|---|---|---|---|---|
| S0 | 仕組みの確認（`s0-probe.sh`） | — | — | — | — | — | 許可した形は拒否されず、許可していない形だけが拒否される | 評価の日に1回（CLI が更新されるため） |
| S1 | master、きれい、載せるコミット1件 | master | 1 | +0 | なし | none | 本文に master。見出し `### TODAY` が1つ増える | 1 |
| S2 | `claude/test`、きれい、載せるコミット1件 | claude/test | 1 | +2 | なし | none | 本文に `claude/test`。`claude/test` は変わらない | **2** |
| S3a | `claude/test`、追跡されているファイルに未ステージの変更 | claude/test | 0 | +0（reflog の件数も同じ） | N1 | none | 何も変わらない | 1 |
| S3b | 同上、ステージ済みの変更 | claude/test | 0 | +0（同上） | N1 | none | 何も変わらない | 1 |
| S4 | `claude/test`、追跡されていない `notes.txt` だけ | claude/test | 1 | +2 | なし | none | `notes.txt` は中身も含めて残り、追跡されないまま（C5） | 1 |
| S5 | detached HEAD | detached（同じコミット） | 0 | +0（同上） | N1 | none | 何も変わらない | 1 |
| S6 | `claude/test`、きれい、master を砂場の別の worktree でチェックアウト | claude/test | 0 | +0（同上） | N1 | none | 記録は書いて消す | 1 |
| S7 | master、`README.md` をステージ済み、`rehearsal-x.txt` を未ステージで変更 | master | 1 | +0 | なし | none | 新しいコミットは docs/progress だけ。ステージと未ステージの変更はそのまま（C3p・C5） | 1 |
| S8 | `claude/test`、きれい、`next_report_date` = TODAY−1、載せるコミット1件 | claude/test | 2 | +2 | ASK | none | 1件目が日次ログ、2件目が期間の区切り。`<開始日>_<TODAYのMMDD>.md` への改名、新しい `<TODAY>_MMDD.md`、`.state.json` の更新（C3b） | **2** |
| S9 | master、TODAY−5〜−3 の3件を PR #99 として TODAY−1 に `--no-ff` マージ、その後に Author Date が TODAY−4 のコミット、末尾の見出しは TODAY−2 | master | 1 | +0 | なし | none | 増える見出しは `### TODAY−1` だけ。PRの親の行、子の3行（元の日付）、古いコミットに「（MM-DDのコミット）」（C10・V1） | 1 |
| S10 | master、末尾の見出しが TODAY、TODAY のコミット1件 | master | 1 | +0 | なし | none | 見出しは増えない（`### TODAY` の下に続ける） | 1 |
| S11 | `claude/test`、`last_commit` が master に入っていないコミット | claude/test | 0 | +0（同上） | N4 | none | 何も変わらない | 1 |
| S11b | `claude/test`、`last_commit` が master の祖先だが first-parent の鎖に無いコミット | claude/test | 0 | +0（同上） | N4 | none | 何も変わらない | 1 |
| S12 | master、記録に `claude/test` | master | 0 | +0（同上） | N2 | claude/test | 何も変わらない（記録も残る） | 1 |
| S12b | `claude/test`、記録に `claude/test`、載せるコミット1件 | claude/test | 1 | +2 | なし | none | 記録を消して S2 と同じに進む | 1 |
| S13 | `claude/test`、きれい、新しいコミットはタスク自身のものだけ、次回予定日は未来 | claude/test | 0 | +0（同上） | なし | none | 何もしない | 1 |
| S14 | `claude/test` で、master で追跡されている `rehearsal-x.txt` を削除してコミットし、同じ名前の追跡されていないファイルを置く | claude/test | 0 | +0（同上） | N1 | none | `git switch master` が失敗し、何も変わらない。記録は消える | 1 |
| **S16**（評価担当が追加） | `claude/test`、きれい、`next_report_date` が null で最後に尋ねたのが TODAY−3、載せるコミットは無い | claude/test | 1 | +2 | ASK | none | 件名「進捗ログ自動更新（TODAY、通知の記録）」、`next_report_date_last_asked` = TODAY（C3b） | 1 |
| S15（任意） | master、「Merge branch 'master' of https://github.com/…」の第2親の側に PR #97 の merge | master | 1 | +0 | なし | none | 「GitHubのmasterを取り込み（PR #97 を含む、2コミット）」と子の行（C10・V2） | 1（合否に含めない） |

- S16 は plan.md 7.1 に無い。今の本番の状態（`next_report_date` が null）では、3日ごとに「通知の記録」だけのコミットが要る。作業ブランチにいる日にはこの経路で切り替えるので、必須に加えることを提案する（7章の未決事項）。
- 場面の無い経路（予行では確かめない）：手順2-5 の (D) と、手順3 の「master で docs/progress に前回の残りがある」行、N3（戻れない）、N5（`.state.json` が壊れている）。静的な確認（ii-7）で文言だけを確かめる。

### 3.2 自動の項目（予行の1回ごと。`rehearsal/check.sh`）

すべての回に、すべての項目を適用する。期待値は場面ごとに変わる（3.1）。

| 記号 | 種類 | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|---|
| R0 | 前提 | `claude -p` が最後まで終わったか | 終了コード0、`result` が `success` | 終わらない回は判定できない | `exit-code.txt`、`stream.jsonl` の `result` |
| Rreal | 前提 | 本物のリポジトリ（worktree の status、共有の ref、worktree の一覧、記録のキー）が実行の前後で同じか | 同じ | 予行が本物に触れていないこと | `real-before-run.txt` と `real-after-run.txt` |
| C1 | 計画 | 実行の前後の HEAD | 前 = 後 = 場面の HEAD | plan.md 7.1 C1 | `before/`・`after/` の `head-branch.txt` |
| C2 | 計画 | 変わった ref | 書き込む場面は `refs/heads/master` だけ、ほかは無し | C2 | `refs.txt` の比較 |
| C3 | 計画 | master に増えたコミットの数、件名、本文 | 数が期待どおり。件名が「進捗ログ自動更新（」か「進捗期間を区切り、新しい期間ファイルを開始（」で始まる。作業ブランチの場面では、すべての本文に `claude/test` | C3、plan.md 4.2.6 | `git rev-list`、`new-commits.txt` |
| C3p | **品質** | master を書き換えていないか、merge を作っていないか、docs/progress のほかを変えていないか | 前の先端の子孫、merge 0、docs/progress 以外の変更 0 | issue の制約（docs/progress 以外はコミットしない、既存の履歴を壊さない）。plan.md 7.1 では C3 の中にあったものを、評価担当が品質の基準に分けた | `git merge-base --is-ancestor`、`git diff-tree -M` |
| C3b | 計画 | S8：改名・新しいファイル・見出し・`.state.json`。S8・S16：`next_report_date_last_asked`。S16：件名 | 3.1 のとおり | 旧7b・7c（plan.md 4.2.3 手順4-5、4.2.6） | `git cat-file`、`after/state.json` |
| C4 | **品質** | `last_commit` | コミットした場面：最初の新しいコミットの第1親（＝前の master の先端）と一致し、master の first-parent の鎖の上。コミットしない場面：`.state.json` が変わらない | C4、issue のゴール（`last_commit` は常に master の履歴を指す） | `after/state.json`、`git rev-list --first-parent` |
| C5 | **品質** | 作業ツリーとインデックス | `git status --porcelain`、`git diff --cached --name-only`、作業ツリーとインデックスの差分のハッシュ、追跡されていないファイルの中身のハッシュが、前後で同じ | C5、issue の制約（ユーザーの未コミットの変更を壊さない・混ぜない） | `before/`・`after/` の5つのファイル |
| C6 | 計画 | `progress-report.return-branch` | S12 だけ `claude/test`、ほかは none | C6 | `return-branch.txt` |
| C7 | **品質** | PushNotification のほかの拒否 | 0 件 | C7、issue の制約（深夜に承認待ちで止まらない）。予行の拒否は、本番の承認待ちに当たる | `stream.jsonl` の `permission_denials`（`denials.tsv`） |
| C7n | 計画 | 実行したコマンドの形と、狭いルール（`task-rules-existing.json` = plan.md 2.1 の既存のタスクのルール + `permission-rules-add.json`）の照合 | 一致しないサブコマンド 0、つないだコマンド 0、docs/progress の外への書き込み 0 | 本番の base には広いルールがありうる（`Bash(git config *)` など）。組み込みで許される読み取りもある（2章）。そのため C7 だけでは形の崩れ（plan.md 9章 R7）が見えない。評価担当が足した項目 | `rules-check.js run`（`commands-vs-rules.tsv`） |
| C8 | 計画 | 通知の種類 | 期待の集合と一致（N1〜N5・ASK。文の種類が分からないものが0件） | C8 | 最後の応答の `NOTIFY:` の行と PushNotification の呼び出し（`notify.txt`、`notify-patterns.json`） |
| C9 | 計画 | `git reflog HEAD` の checkout の行の増え方 | 切り替える場面は +2、ほかは +0。何もしない場面は reflog の件数も同じ | C9（切り替える場面にも適用を広げた） | `reflog-*.txt` |
| C10a〜d | 参考 | 既存の日次ログが先頭に残る、見出しが重複なく日付順、増えた見出しが期待どおり、期待する文字列がある | 参考OK | C10 の機械的な補助。合否は V1・V2 で評価担当が目で見て決める | `c10.js`（`daily-added.md`、`progress.diff`） |

### 3.3 回数と実行のしかた

- 必須は20回：S1、S2×2、S3a、S3b、S4、S5、S6、S7、S8×2、S9、S10、S11、S11b、S12、S12b、S13、S14、S16。任意は S15。評価の日に S0 を1回やり直す。
- 実行は `rehearsal/run-all.sh`（手順は [`rehearsal/README.md`](./rehearsal/README.md)）。許可設定の base は、メインのチェックアウトの `.claude/settings.local.json` の写し（`temp/rehearsal-27/_inputs/base-settings.local.json`）。worktree の写しは使わない（広いルールが増えているため）。

## 4. 静的な確認 (ii)・ドキュメント・目で見る項目

### 4.1 静的な確認 (ii)（評価担当Bが `skill-after.md` から独立に作り直す）

照合の規則は [`README.md`](./README.md) の決定事項（`*` の無いルールは完全一致、`x *` は `x` にも一致、`&&`・`;`・`|` はサブコマンドごと、`-C` は剥がされない、Bash と PowerShell は別）。ルールの集まりは、plan.md 2.1 の既存のタスクのルール（`rehearsal/task-rules-existing.json`）と `permission-rules-add.json`。`rules-check.js static` の出力は補助で、表は B が `skill-after.md` を読んで作る（implementer の表を写さない）。

| 記号 | 種類 | 指標 | しきい値 | 根拠 |
|---|---|---|---|---|
| ii-1 | **品質** | `skill-after.md` に出てくる `git …` のすべての形（`<…>` を実際にありうる値にしたもの）が、Bash のルールに一致するか | 一致しない形 0 | issue の制約（承認待ちで止まらない）。組み込みの読み取りの許可に頼らない |
| ii-2 | 計画 | 同じ形が PowerShell のルールにも一致するか | 一致しない形 0 | plan.md 4.3（両方に足す） |
| ii-3 | **品質** | 破壊的な形・範囲の外の形 | `git push`、`git reset`、`git stash`、`git checkout`、`git rebase`、`git merge`、`git cherry-pick`、`git branch -d/-D`、`git commit -a`・`--amend`、`git add -A`・`git add .` が無い。`git switch` は `master` と `-` だけ。`git config` の書き込みはキー `progress-report.return-branch` だけ | issue の制約（push しない、docs/progress 以外をコミットしない）、plan.md 3.2 |
| ii-4 | 計画 | 書き方の約束 | コマンドの中に `&&`・`;`・`2>&1`・`-C` が無い。「1回のツール呼び出しにつき1コマンド、Bash ツールを使う」の指示がある。frontmatter が無い。絶対パスは1行目だけ | plan.md 4.2・4.2.2・5章の4 |
| ii-5 | 計画 | `permission-rules-add.json` の形と中身 | JSON の文字列の配列。plan.md 4.3 の新規の8行を Bash と PowerShell で（16個）含む。ほかの要素は impl-report に理由があり、書き込みの形を広げないものだけ。`PushNotification`・`Write`・`Edit`・deny、`git switch *`・`git checkout *`・`git *` が無い | plan.md 4.3 |
| ii-6 | 計画 | 通知の文の長さ | N1〜N5 と次回予定日の質問が、`<CUR>`・`<B>`・`<R>` に `claude/progress-log-master`、`<理由>` にプロンプトにある最も長い理由、gitのメッセージの要約に60字を入れても、200字以内 | plan.md 4.2.5 |
| ii-7 | 目で見る | 変えない部分の文言と、全体の構成 | 状態ファイル・命名規則・期間ファイルのひな型・旧7b・7c の中身が `skill-before.md` と同じ文言。見出しの構成（4.2.1）、手順1〜5（4.2.3）、日次ログの規則（4.2.4）、件名（4.2.6。タスク自身のコミットの2つの形を変えない）が計画どおり。場面の無い経路（3.1 の末尾）の文言も計画どおり | plan.md 4.2 |

### 4.2 ドキュメントと変更の範囲

| 記号 | 種類 | 指標 | しきい値 | 確かめる方法 |
|---|---|---|---|---|
| D1 | 計画 | `CLAUDE.md` の進捗レポートの項目 | plan.md 4.4 の3点（master の履歴を元に master にコミットし、作業ブランチなら一時的に切り替える・変更があれば見送って通知、最新は常に master にある、次回予定日の手での更新は master のときだけ）がある | `git diff <基準>..HEAD -- CLAUDE.md` を読む |
| D2 | 計画 | `docs/git-rules.md` | plan.md 4.4 の3点（例外の段落に master へのコミットと一時的な切り替え、master を rebase・reset しない、worktree で master をチェックアウトしない）がある | 同上 |
| D3 | 計画 | `docs/staged-development.md` | 8章の書き換え（「変えるまでの注意」を外す、未コミットの変更で見送り、MATLAB の未保存の変更）と、5.1 の注記がある | 同上 |
| D4 | **品質** | 変えてはいけないファイルに差分が無いか | `git diff --name-only 7faecb1..HEAD`（`7faecb1`：criteria.md・rehearsal/ を追加した `9899c10` の後に、rehearsal/ の改行をLFに固定したコミット。この基準のハッシュを書き込むメインのコミットの、criteria.md の1行の変更は除く）が、`CLAUDE.md`・`docs/git-rules.md`・`docs/staged-development.md`・`docs/issues/27-progress-log-master/` の `skill-after.md`・`permission-rules-add.json`・`impl-report-1.md`・`README.md` だけ。`criteria.md`・`rehearsal/`・`plan.md`・`skill-before.md`・`docs/progress/`・`.gitignore`・`.githooks/`・`.claude/agents/`・`src/`・`scripts/`・`test/`・`docs/issues/closed/` に差分が無い | `git diff --name-only`（`<…>` のハッシュはメインがコミットのときに埋める） |
| D5 | 計画 | 古い記述が残っていないか | `CLAUDE.md`・`README.md`・`docs/*.md`・`docs/rules/*.md`・`.claude/agents/*.md` を `進捗\|progress` で検索して、作業ブランチにコミットが入る前提の記述（例：`docs/staged-development.md` 8章の「変えるまでの注意」）が無い | `git grep` |

### 4.3 目で見る項目（評価担当Bが判断する）

| 記号 | 対象 | 観点 |
|---|---|---|
| V1 | S8・S9・S10 の日次ログ（`daily-added.md`、`progress.diff`） | plan.md 4.2.4 の規則どおり（見出しの日付、同じ日付の見出しが1つ、PR の親の行と子の行、元の日付、「（MM-DDのコミット）」）。既存の行が変わっていない（C10a で補助）。S8 では、日次ログが改名の前のファイルに追記され、新しいファイルがひな型どおり |
| V2 | ほかの書き込む場面（S1、S2×2、S4、S7、S12b、S16、S15）の日次ログとまとめ | 載せるコミットだけが載り、タスク自身のコミット（T）が載らない。まとめが日次ログ全体から作り直されている（壊れていない、架空の内容を足していない） |
| V3 | 通知の文（`notify.txt`、`summary-*.md`） | 場面に合った理由（S3a・S3b：未コミットの変更、S5：detached HEAD、S6・S14：master に切り替えられない、S11・S11b：`last_commit`、S12：前回の中断、S8・S16：次回予定日の質問）。日本語1行、200字以内 |
| V4 | コミットの件名と本文（`new-commits.txt`） | plan.md 4.2.6 のとおり（日次ログの件名の日付、本文の「masterに直接コミット（チェックアウト中: <CUR>）」、`Co-Authored-By:`） |

V1〜V4 は、回ごとに OK／NG と理由を `eval-report-<n>.md` に書く。

## 5. 判定の決め方

- **合格**：次のすべてを満たす。
  1. 必須の20回のうち、前提（R0・Rreal）が成り立つすべての回で、品質の基準（C3p・C4・C5・C7）と計画どおりかの確認（C1・C2・C3・C3b・C6・C7n・C8・C9）が OK。
  2. 静的な確認 ii-1〜ii-6 が OK で、ii-7 を B が OK と判断する。
  3. D1〜D5 が OK。
  4. V1〜V4 を B が OK と判断する。
- **不合格**：品質の基準が1つでも NG（どの回でも）。または、計画どおりかの確認、目で見る項目のどれかが NG。
- **前提が成り立たない回**（R0・Rreal が NG）
  - API・ネットワーク・認証のエラー、ほかのセッションや毎晩のタスクによる本物のリポジトリの変化が原因なら、その回は無効。新しい回の番号で準備からやり直す。やり直しは場面ごとに2回まで。3回続けて無効なら、判定を保留して（確認待ち：メイン）、(b) に替えるかをメインに尋ねる。
  - 時間切れ（900秒）や、タスクが途中で止まったことが原因なら、無効にせず、その回を計画どおりかの確認の NG とする。
  - 無効でない回を、やり直して置き換えない。NG が出た場面を、もう一度実行して OK にしない。すべての回の結果を報告する。
- **(b) に替えた場合**：C7 は確かめられない。ほかの項目で合否を決め、「C7（特に `git switch -` の照合、R1）は未確認」と明記する。それで良いかはメインが決める。
- 任意の S15 は合否に含めない（結果は報告する）。S16 は、メインが承認のときに外した場合だけ、合否から外す。
- 不合格で実装を直した後の評価（`eval-report-2.md` など）では、必須の全回をやり直す（プロンプトの変更は、ほかの場面にも効くため）。

## 6. (iii)・(iv) の位置づけ（合否の外）

### 6.1 (iii) 反映後の確認（メインが行う。issue を閉じる前の条件）

評価に合格した後、メインが反映（plan.md 7.3 の1）してから、メインのチェックアウトが master のときに `run_scheduled_task` で行う。B の合否には含めない（反映は合格の後に行うため）。どれかが外れたら、メインは `skill-before.md` に戻し（plan.md 4.6）、`README.md` に記録して、実装の段階に戻す。

| 記号 | 確かめること | しきい値 |
|---|---|---|
| T1 | タスクのセッションが承認待ちで止まらずに終わる | 終わる |
| T2 | master に増えたコミット | 1件（期間の区切りか通知の記録が重なれば2件）。`git show --stat` で docs/progress だけ |
| T3 | メインのチェックアウト | `git worktree list` で master のまま |
| T4 | `last_commit` | 最初の新しいコミットの第1親と一致し、master の first-parent の鎖の上 |
| T5 | 記録のキー | `git config --get --default none progress-report.return-branch` が none |
| T6 | 日次ログ | 実行の前の `git log <last_commit>..master --first-parent` のうち、タスク自身のコミットを除いたものが載り、タスク自身のコミット（例：`246b850`）は載らない |
| T7 | 反映の正しさ | `SKILL.md` の本文の sha256 が `skill-after.md` と同じ。`permission-rules-add.json` のすべての要素が、メインのチェックアウトの `settings.local.json` にある |

(iii) は master で行うので、切り替えの経路（`git switch -` の本番での照合、plan.md 9章 R1・R2）と、持ち越しの経路は確かめられない。

### 6.2 (iv) 作業ブランチでの本物の実行（後日。メインのチェックアウトが空いたとき）

plan.md 7.3 の3のとおり。合否には含めない。確かめること：未コミットの変更がある状態で N1 が届き何も変わらない（F1）、きれいな状態で master に1件増え、作業ブランチは変わらず（`git log master..<作業ブランチ>` が空）、HEAD が戻り、status が空、記録が none、`last_commit` が正しい（F2）、MATLAB にダイアログが出ていない（F3）。

issue の完了条件のうち「作業ブランチをチェックアウトした状態で手動で実行し…」「未コミットの変更がある状態で実行し…」は、本物の環境では (iv) でしか満たせない。予行の S2・S3a・S3b がその代わりの根拠になる。issue を閉じるときに (iv) が済んでいなければ、その旨を README と PR に書く（7章の未決事項）。

## 7. リスク・限界

| リスク | 内容 | 対策 |
|---|---|---|
| ヘッドレスとアプリの違い（plan.md R10） | 予行は CLI 2.1.300、本番はデスクトップアプリの 2.1.304。`git switch -` の照合（R1）は予行で確かめたが、本番では (iv) か、作業ブランチにいる日の最初の3時の実行まで確かめられない | (iii)・(iv)。本番で `git switch -` が止まった場合は、記録のキーが残るので、次の実行で N2 が届く |
| 組み込みの読み取りの許可 | ルールの無い読み取りのコマンドが予行では許される（2章）。本番のアプリでも同じとは限らない | ii-1（静的）と C7n で、ルールに一致することを別に確かめる |
| base の取り違え | worktree の `settings.local.json` は計画の後に広いルールが増えている。これを base にすると C7 が甘くなる | base はメインのチェックアウトの写しにする。`run.sh` は広いルールを `settings-report.txt` に書く。C7n は base に関係しない |
| Write のルール | 本番で進捗ファイルを書けているのは `Edit(…)` のルールのおかげで、`Write(…)` のルールは効いていない（2章） | 予行は両方を書き換える。今回の変更の範囲の外（メインへの申し送り） |
| LLM の揺れ | 1回の予行が OK でも、毎晩 OK とは限らない | S2・S8 は2回。全体で20回。NG を消さない |
| 使用量と時間 | 予行の1回が Opus のセッション1つ（S0 を含めて約22回、1時間以上） | `run-all.sh` をバックグラウンドで実行する |
| `~/.claude/` | `claude -p` が、砂場ごとに空の `~/.claude/projects/<砂場のパス>/memory/` を作る。会話の記録は残らない | 消す場合は、メインが後でまとめて消す（害はない） |

## 8. 決定事項（旧：未決事項）

**2026-10-22、main が決定：1〜4 はすべて推奨どおり (a)。** S16 は必須（合否に含める）。C3p は品質の基準、C7n は計画どおりかの確認として足す。base はメインが `temp/rehearsal-27/_inputs/base-settings.local.json` にコピーした（2026-10-22、sha256 `1664c482223f93a2c486c410dc3541b662773afb04309d0f0dd6f559af034b1a`）。(iv) が済まないうちは、予行の S2・S3a・S3b を代わりの根拠としてissueを閉じ、(iv) を続きの確認として README と PR に書く。以下は検討の記録として残す。

1. **S16（通知の記録だけのコミット、作業ブランチ）を必須に加えるか**
   - 背景：今の本番は `next_report_date` が null で、3日ごとにこの経路を通る。作業ブランチにいる日には切り替えが起きる。plan.md 7.1 の場面に無い。
   - (a) 必須に加える（予行が1回増える）。 (b) 任意にする。 (c) 外す。
   - 推奨：(a)。本番で最もよく通る切り替えの経路の1つで、1回分の使用量で確かめられるため。
2. **C3p（docs/progress だけ・merge 無し・master を書き換えない）と C7n（狭いルールとの照合）を足すこと**
   - 背景：plan.md 7.1 では、C3 の中身は計画どおりかの確認で、C7n は無い。C3p は issue の制約そのもので、C7n は C7 の見落とし（組み込みの許可、広い base）を補う。
   - (a) このとおり（C3p は品質の基準、C7n は計画どおりかの確認）。 (b) C3p を計画どおりかの確認に戻す。 (c) C7n を外す。
   - 推奨：(a)。
3. **base（メインのチェックアウトの `.claude/settings.local.json`）の写しを、誰が置くか**
   - 背景：メインのチェックアウトでは何もしない約束がある。予行の base には、その写しが要る（plan.md 7.1）。
   - (a) メインが評価の前に `temp/rehearsal-27/_inputs/base-settings.local.json` にコピーし、sha256 を README に書く。 (b) 評価担当Bに、読み取りとコピーだけを許可する。
   - 推奨：(a)。B がメインのチェックアウトに触れずに済み、どの base を使ったかが README に残るため。
4. **issue を閉じるときに (iv) が済んでいない場合の扱い**
   - 背景：issue の完了条件の2つ（作業ブランチでの手動実行、未コミットの変更での通知）は、本物では (iv) でしか確かめられない。メインのチェックアウトは別のセッションが使っている。
   - (a) 予行の S2・S3a・S3b を代わりの根拠として閉じ、(iv) を続きの確認として README と PR に書く。 (b) (iv) が済むまで閉じない。
   - 推奨：(a)。予行は本番と同じプロンプトと許可ルールで動き、残るのはアプリとの違いだけで、最初の作業ブランチでの3時の実行で自然に確かめられるため。

仮定：`permission-rules-add.json` は「`permissions.allow` に足す文字列の JSON 配列そのもの」（メインの依頼文）。`skill-after.md` の1行目には、メインのチェックアウトの絶対パスがちょうど1つある（plan.md 4.2）。どちらかが違えば、`run.sh` は実行せずに止まる。
