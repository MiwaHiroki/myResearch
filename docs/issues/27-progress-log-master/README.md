- 段階: 準備
- 作成者: main
- 作成日: 2026-10-22
- 入力: issue #27
- 状態: 作業中

# #27 進捗ログの自動更新を、常にmasterにコミットする

- issue: [#27 [bug] 進捗ログの自動更新が、チェックアウト中の作業ブランチにコミットしてしまう](https://github.com/MiwaHiroki/myResearch/issues/27)
- ブランチ: `claude/progress-log-master`（worktree `.claude/worktrees/progress-log-master/`。メインのチェックアウトは別のセッションが使っている）
- 運用: [`../README.md`](../README.md)（受け渡しフォルダ）、[`../../staged-development.md`](../../staged-development.md)（段階的な開発の手順書）

## 進め方

計画（planner）→ 評価基準（evaluator A）→ 実装（implementer）→ 評価（evaluator B）の順に進める。MATLABは使わない（変えるのはタスクのプロンプトとドキュメント）。

タスクのプロンプト（`~/.claude/scheduled-tasks/progress-report-daily/SKILL.md`）はリポジトリの外にあり、gitで管理されていない。そのため、この受け渡しフォルダに変更前と変更後の写しを置いて記録する。実際のタスクへの反映は、メインが `mcp__scheduled-tasks__update_scheduled_task` で行う（サブエージェントはこのツールを使えない）。

## 段階の状態

| 段階 | 担当 | 成果物 | 状態 | 承認日 |
|---|---|---|---|---|
| 計画 | planner | [`plan.md`](./plan.md) | 承認済み（main） | 2026-10-22 |
| 評価基準 | evaluator（A） | [`criteria.md`](./criteria.md)、[`rehearsal/`](./rehearsal/README.md) | 承認済み（main） | 2026-10-22 |
| 実装 | implementer | [`impl-report-1.md`](./impl-report-1.md)、[`skill-after.md`](./skill-after.md)、[`permission-rules-add.json`](./permission-rules-add.json) | 完了（1回目、`e1c33f0`） | 2026-10-22 |
| 評価 | evaluator（B） | `eval-report-1.md` | 未着手 | |

## 決定事項・申し送り（段階をまたぐもの）

- 2026-10-22（着手時、ユーザーの指示）
  - **今回はユーザーの承認を挟まず、メインが自律的に進める**（「今回は私の承認を求めず、自律的に実装を進めてください」）。計画・評価基準の承認、未決事項の決定、段階ごとのコミットはメインが判断する。pushとPRの作成は、`CLAUDE.md`（グローバル）の「pushはユーザーに確認」に従い、最後にユーザーに確かめる。
  - issueの未決事項は、issueの推奨どおりに決めた（メインの判断）。
    - **Q1 → (a)**：チェックアウト中のブランチがmasterでなければ、一時的に `git switch master` してから作業し、最後に元のブランチへ戻す。作業ツリーに未コミットの変更があるときは、何もせず次回に持ち越し、通知する。
    - **Q2 → (a)**：進捗ログに載せるのはmasterの履歴だけ。作業ブランチの途中経過は、PRのマージ後にまとめて載る。
  - 検証のためのタスクの手動実行で増える進捗ログのコミットは、消さずに残す（正規の進捗ログとして扱う）。
- 2026-10-22（main、着手時の状況）
  - メインのチェックアウト（リポジトリのルート）では、別のセッション（「実験結果フォルダ構成の改善」）が並行して作業している。**メインのチェックアウトのブランチを、検証のために切り替えない**（そのセッションの作業を壊すおそれがあるため）。ブランチの切り替えを伴う場面の確かめ方は、計画で決める。
  - 変更前のタスクのプロンプトを [`skill-before.md`](./skill-before.md) に控えた（2026-10-22時点の `SKILL.md` と同一。sha256 `177466f4…`）。
- 2026-10-22（main、許可ルールの照合の仕様。claude-code-guide エージェントが公式ドキュメントで確認）
  - `*` の無いルールは完全一致だけ。`Bash(git status *)` は引数なしの `git status` にも一致する。`Bash(x:*)` と `Bash(x *)` は同じ。
  - `&&`・`;`・`|` でつないだコマンドは、サブコマンドごとに照合される。`git -C <path> …` は `-C` が剥がされないので一致しない。
  - `PowerShell(...)` ルールもあり、照合の仕方はBashと同じ。BashのルールはPowerShellツールには効かない。
  - 単独の `-`（`git switch -`）の扱いは文書に無い。予定タスクに効くと文書が明記しているのは `~/.claude/settings.json` の allow だけ（ただし、今のタスクはプロジェクトの `settings.local.json` のルールで毎晩承認なしに動いている）。
  - 過去の実行では、タスクのセッションはBashツールでgitを1コマンドずつ実行し、進捗ファイルはWriteツールで書いていた。
- 2026-10-22（計画の承認、main）
  - `plan.md` を承認した。8章の Q1〜Q9 はすべて推奨どおり（plan.md 8章の冒頭に記録）。要点：タスク自身のコミットは日次ログに載せず「やること」にも数えない（Q1）、PRのマージは親の1行と中身の子の行（Q2）、masterでは `-- docs/progress/` のパス指定でコミットして続ける（Q3）、未追跡のファイルだけなら切り替える（Q4）、中断の記録は `git config progress-report.return-branch`（Q5）、次回予定日の手での更新はmasterのときだけ（Q6）、予行は砂場の `claude -p`（Q8）。
- 2026-10-22（評価基準の承認、main）
  - `criteria.md` を承認した。8章の 1〜4 はすべて推奨どおり：S16（作業ブランチで通知の記録だけをコミット）を必須に加える、C3p（品質）・C7n（計画）を足す、予行の許可設定の base はメインがコピーする、(iv) が済まないうちは予行の S2・S3a・S3b を代わりの根拠にしてissueを閉じ、(iv) を続きの確認として残す。
  - 予行の base：メインのチェックアウトの `.claude/settings.local.json` を `temp/rehearsal-27/_inputs/base-settings.local.json` にコピーした（sha256 `1664c482223f93a2c486c410dc3541b662773afb04309d0f0dd6f559af034b1a`）。
  - 仕組みの確認（S0）で分かったこと：ヘッドレスの `claude -p` で、完全一致のルール `Bash(git switch -)` は一致した（plan.md 9章 R1 は予行の上では解消）。Writeツールは `Edit(…)` のルールで許され、`Write(…)` だけのルールは効かなかった（本番で進捗ファイルを書けているのもEditのルールのおかげ。今回の範囲の外）。

## ファイル一覧

作成されたら、相対パスのリンクで追記する（例: `./plan.md`）。

- `README.md`（このファイル）
- [`skill-before.md`](./skill-before.md)：変更前のタスクのプロンプト（`SKILL.md` の写し、main）
- [`plan.md`](./plan.md)：計画（planner、2026-10-22 main承認）
- [`criteria.md`](./criteria.md)：評価基準（evaluator モードA、2026-10-22 main承認）
- [`rehearsal/`](./rehearsal/README.md)：砂場での予行のスクリプト（evaluator モードA）。実行の記録は worktree の `temp/rehearsal-27/`（gitの管理外）
- [`skill-after.md`](./skill-after.md)：変更後のタスクのプロンプト（implementer。評価の後に、メインが本物の `SKILL.md` に反映する）
- [`permission-rules-add.json`](./permission-rules-add.json)：タスクの許可設定に足すルール（implementer。反映はメイン）
- [`impl-report-1.md`](./impl-report-1.md)：実装の報告 1回目（implementer、2026-10-22）
