- 段階: 準備
- 作成者: main
- 作成日: 2026-10-12
- 入力: issue #25
- 状態: 承認済み

# #25 写真1枚の範囲で1本の溝を自動追跡する

- issue: [#25 [feature] 写真1枚の範囲で1本の溝を自動追跡する（fitGroove＋extractGrooveShapeの代替）](https://github.com/MiwaHiroki/myResearch/issues/25)
- ブランチ: `claude/groove-tracking`
- 運用: [`../README.md`](../README.md)（受け渡しフォルダ）、[`../../rules/communication.md`](../../rules/communication.md)（受け渡しファイルの書き方）

## 進め方

計画（planner）→ 評価基準（evaluator A）→ 実装（implementer）→ 評価（evaluator B）の順に進める。各段階の成果物はユーザーが承認し、メインセッションがコミットする。評価で不合格なら実装に戻す（最大3回。超えたらユーザーに相談する）。

## 段階の状態

| 段階 | 担当 | 成果物 | 状態 | 承認日 |
|---|---|---|---|---|
| 計画 | planner | [`plan.md`](./plan.md) | 承認済み | 2026-10-13 |
| 評価基準 | evaluator（A） | [`criteria.md`](./criteria.md)、受け入れテスト | 承認済み | 2026-10-13 |
| 実装 | implementer | [`impl-report-1.md`](./impl-report-1.md) | 完了（1回で合格） | 2026-10-13 |
| 評価 | evaluator（B） | [`eval-report-1.md`](./eval-report-1.md) | 合格（1回目） | 2026-10-15 |

## 決定事項・申し送り（段階をまたぐもの）

- 2026-10-13（実装1回目の後、ユーザーの決定）
  - `scripts/grooveTrack_1cycle.m` の `date`・`PREV_RESULT_PATH` は `"MMDD"`・`""` のまま残す（書き換え忘れで実行するとエラーで止まり、過去の出力を上書きしないため）。
  - 実装担当が作った `experiments/1013/cycleResult_origD_track_1013.mat` は、コミット前のコードで作ったため `meta.gitDirty = true`。**評価（モードB）では、コミット後のコードで追跡の結果を別の日付で作り直して使う。** 1013のファイルは消さずに残す。
  - U1（追跡の経路の目視）：ユーザーが `results/1013/grooveTrack_img1〜8.png` を確認し、問題なし。評価スクリプトが作る重ね描きの図（`evalTrack_overlay_img*.png`）は、評価のときに改めて見る。
  - `CLAUDE.md` の Architecture notes に追跡の流れを1項目足した（main）。
- 2026-10-13（評価の日付、ユーザーの決定）
  - 評価（モードB）は **2026-10-14以降** に行い、保存の日付は**評価を実行する日（MMDD）**にする。手動選択の再現（`cycleResult_origD_<日付>.mat`）、作り直す追跡の結果（`cycleResult_origD_track_<日付>.mat`）、評価の図・表（`results/<日付>/evalTrack_*`）をすべてこの日付にする。
  - 理由：今日（1013）実行すると、作り直す追跡の結果が1回目の実装の出力（`experiments/1013/cycleResult_origD_track_1013.mat`、`results/1013/` の追跡の図・wav）とぶつかるため。
  - evaluatorへの依頼文は、評価の当日にメインが作る。
- 2026-10-15（評価1回目の後、ユーザーの決定）
  - 評価（2026-10-14実行、日付 `1014`）は、数値の項目をすべて満たし、ユーザーが U1〜U4 を確認して問題なしとしたので**合格**。差し戻しは0回。
  - デトレンドの次数は写真ごと9次のまま。
  - `criteria.md` の E6b・E6c の差分の基準を `6e0adea` に直した（判定は変わらない）。
  - 評価で作ったデータ：`experiments/1014/cycleResult_origD_1014.mat`（今のコードで手動選択を再現した基準）、`experiments/1014/cycleResult_origD_track_1014.mat`（追跡）。日付を書き換えたスクリプトのコピーは `temp/*_eval1014.m`（gitの管理外）。
  - 進捗ログの自動コミット（`3261e62`）が作業ブランチに入った件は、このままPRでmasterに入れる。

## ファイル一覧

作成されたら、相対パスのリンクで追記する（例: `./plan.md`）。

- `README.md`（このファイル）
- [`plan.md`](./plan.md)：計画（planner、2026-10-13 承認）
- [`criteria.md`](./criteria.md)：評価基準（evaluator モードA、2026-10-13 承認）。受け入れテストは `test/unit/GrooveTrackingAcceptanceTest.m`、評価スクリプトは `scripts/evaluation/grooveTracking/compareTrackingToManual.m`
- [`impl-report-1.md`](./impl-report-1.md)：実装の報告 1回目（implementer、2026-10-13）
- [`eval-report-1.md`](./eval-report-1.md)：評価レポート 1回目（evaluator モードB、2026-10-14。2026-10-15 ユーザー確認で合格）
- [`retrospective.md`](./retrospective.md)：試験運用の振り返り（main、中間版。評価の後に最終版にする）
- [`follow-ups.md`](./follow-ups.md)：続きのissueの案と、作るタイミングのメモ（main）
