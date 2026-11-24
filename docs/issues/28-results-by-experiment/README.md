- 段階: 準備
- 作成者: main
- 作成日: 2026-11-24
- 入力: issue #28
- 状態: 作業中

# #28 結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す

- issue: [#28 [refactor] 結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す](https://github.com/MiwaHiroki/myResearch/issues/28)
- ブランチ: `claude/results-by-experiment`
- PR: （作ったら書く）
- 進め方: `docs/staged-development.md`、受け渡しフォルダの運用: `docs/issues/README.md`

## 解決のまとめ

仕上げで書く（summarizer）。

## 作業履歴

### 準備・全体 — 完了

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | main | issue #28 を受け、ブランチ `claude/results-by-experiment`（`origin/master` の `94e3057` から）と受け渡しフォルダを作る。<br>issue の未決事項は「着手前に決めることは無い」とあり、作業の途中で確かめる3つ（`experiments/` を改名してからマージまでの扱い、`runInfo.json` の項目の表、対応表）だけが書かれているので、着手前に尋ねることは無い。<br>同じフォルダで動いていた #35 の進捗報告の素材の試行のセッションが終わるのを待ってから、ブランチを切った | `README.md`、`c7d2460` |
| 2026-11-23 | ユーザー | **決定** 進め方：各サブエージェントが段階の作業を終えるたびに、main がその内容と未決事項をユーザーに報告する。ユーザーが承認したら、次の段階に進む。<br>**決定** 確認を省く範囲：承認を次の段階の開始の合図とし、エージェントを呼ぶ前の確認と依頼文の事前の提示は省く。手順書どおりの段階ごとのコミット（確認待ち・決定の反映）も、確認なしで main が行う。push・PR の作成・`experiments/` の改名は、そのつどユーザーに確かめる | — |
| 2026-11-23 | ユーザー | **決定** 進捗報告の素材は作らない。結果フォルダの構成と実行記録の整理で、研究の内容（溝の抽出や音声の品質）には関わらないため | — |

### 計画 — ユーザー確認待ち

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | planner | `plan.md` を書く（1回目）。推奨は、`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState` を `src/` に作り、スクリプト55本は出力先・日付・実験条件の行だけを差し替える案。既存のフォルダは、対応表の CSV を読む `scripts/migration/migrateResults.m` で移す。<br>実装を前半（関数・テスト・README の表。承認A）と後半（スクリプト・文書・`.gitignore`）に分け、移行は main が承認B（対応表）・承認C（バックアップ）を取って行う。`experiments/` の改名は評価の直前。<br>未決事項 Q1〜Q6、対応表の未決事項 M1〜M5。<br>対応表の案は `mapping-draft.md` に分けた（main が依頼文で認めた例外。planner が書いてよいのは本来 `plan.md` だけ） | [`plan.md`](./plan.md)、[`mapping-draft.md`](./mapping-draft.md) |
### 評価基準 — 未着手
### 実装 — 未着手
### 評価 — 未着手
### 振り返り — 未着手
### 続きのissue — 未着手
### 解決のまとめ — 未着手
### 仕上げ（closed/ へ移動・PR） — 未着手

## ファイル一覧

- `README.md`：このファイル
- [`plan.md`](./plan.md)：計画
- [`mapping-draft.md`](./mapping-draft.md)：既存のフォルダの対応表の案（計画の付属）
