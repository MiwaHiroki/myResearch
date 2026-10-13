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
| 実装 | implementer | `impl-report-<n>.md` | 未着手 | |
| 評価 | evaluator（B） | `eval-report-<n>.md` | 未着手 | |

## ファイル一覧

作成されたら、相対パスのリンクで追記する（例: `./plan.md`）。

- `README.md`（このファイル）
- [`plan.md`](./plan.md)：計画（planner、2026-10-13 承認）
- [`criteria.md`](./criteria.md)：評価基準（evaluator モードA、2026-10-13 承認）。受け入れテストは `test/unit/GrooveTrackingAcceptanceTest.m`、評価スクリプトは `scripts/evaluation/grooveTracking/compareTrackingToManual.m`
