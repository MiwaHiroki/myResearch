- 段階: 準備
- 作成者: main
- 作成日: 2026-10-26
- 入力: issue #30
- 状態: 作業中

# #30 写真ごとに1回のクリックからN本の溝を抽出し、N周分の音声を作る

- issue: [#30 [feature] 写真ごとに1回のクリックからN本の溝を抽出し、N周分の音声を作る（ヒストグラムによる溝の選択）](https://github.com/MiwaHiroki/myResearch/issues/30)
- ブランチ: `claude/multi-groove`
- 進め方: [`../../staged-development.md`](../../staged-development.md)（段階的な開発の手順書）
- 運用: [`../README.md`](../README.md)（受け渡しフォルダ）、[`../../rules/communication.md`](../../rules/communication.md)（受け渡しファイルの書き方）

## 進め方

計画（planner）→ 評価基準（evaluator A）→ 実装（implementer）→ 評価（evaluator B）の順に進める。各段階の成果物はユーザーが承認し、メインセッションがコミットする。評価で不合格なら実装に戻す（最大3回。超えたらユーザーに相談する）。

このissueでは、**正解データ（N本を `trackGroove` で別々に追跡したもの）をユーザーが `ginput` で作る**（8×N回のクリック）。実装をコミットした後、評価の前に行う。

## 段階の状態

| 段階 | 担当 | 成果物 | 状態 | 承認日 |
|---|---|---|---|---|
| 計画 | planner | `plan.md` | 未着手 | |
| 評価基準 | evaluator（A） | `criteria.md`、受け入れテスト | 未着手 | |
| 実装 | implementer | `impl-report-<n>.md` | 未着手 | |
| 正解データの作成 | ユーザー | `experiments/<日付>/` の cycleResult | 未着手 | |
| 評価 | evaluator（B） | `eval-report-<n>.md` | 未着手 | |
| 振り返り | main | `retrospective.md` | 未着手 | |

## 決定事項・申し送り（段階をまたぐもの）

- 2026-10-26（issue作成時、ユーザーの決定）
  - y座標が小さい側（画像の上側）が、レコードの内側。クリックする1本目はN本の中で最も外側（最初に再生される）溝で、2本目以降はy座標が小さい側に並ぶ。
  - 評価に使う溝の本数は N=5。
  - issueの未決事項1〜4は、計画段階で決める。
  - 確認を省く範囲（`docs/staged-development.md` 3章）：**コミットの確認**と**エージェントを呼ぶ前の確認**は省く。**依頼文の事前の提示**は省かない（呼ぶ前に依頼文をユーザーに見せる）。必ず挟む確認（計画・評価基準の承認、ユーザーが判断する項目、issueに書かれていないデータの作成・削除・上書き、push、PRの作成）は今までどおり。

## ファイル一覧

作成されたら、相対パスのリンクで追記する（例: `./plan.md`）。

- `README.md`（このファイル）
