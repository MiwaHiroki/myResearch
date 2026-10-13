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
| 実装 | implementer | [`impl-report-1.md`](./impl-report-1.md) | 1回目完了（評価待ち） | 2026-10-13 |
| 評価 | evaluator（B） | `eval-report-<n>.md` | 未着手 | |

## 決定事項・申し送り（段階をまたぐもの）

- 2026-10-13（実装1回目の後、ユーザーの決定）
  - `scripts/grooveTrack_1cycle.m` の `date`・`PREV_RESULT_PATH` は `"MMDD"`・`""` のまま残す（書き換え忘れで実行するとエラーで止まり、過去の出力を上書きしないため）。
  - 実装担当が作った `experiments/1013/cycleResult_origD_track_1013.mat` は、コミット前のコードで作ったため `meta.gitDirty = true`。**評価（モードB）では、コミット後のコードで追跡の結果を別の日付で作り直して使う。** 1013のファイルは消さずに残す。
  - U1（追跡の経路の目視）：ユーザーが `results/1013/grooveTrack_img1〜8.png` を確認し、問題なし。評価スクリプトが作る重ね描きの図（`evalTrack_overlay_img*.png`）は、評価のときに改めて見る。
  - `CLAUDE.md` の Architecture notes に追跡の流れを1項目足した（main）。

## ファイル一覧

作成されたら、相対パスのリンクで追記する（例: `./plan.md`）。

- `README.md`（このファイル）
- [`plan.md`](./plan.md)：計画（planner、2026-10-13 承認）
- [`criteria.md`](./criteria.md)：評価基準（evaluator モードA、2026-10-13 承認）。受け入れテストは `test/unit/GrooveTrackingAcceptanceTest.m`、評価スクリプトは `scripts/evaluation/grooveTracking/compareTrackingToManual.m`
- [`impl-report-1.md`](./impl-report-1.md)：実装の報告 1回目（implementer、2026-10-13）
