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

### 計画 — 承認済み

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | planner | `plan.md` を書く（1回目）。推奨は、`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState` を `src/` に作り、スクリプト55本は出力先・日付・実験条件の行だけを差し替える案。既存のフォルダは、対応表の CSV を読む `scripts/migration/migrateResults.m` で移す。<br>実装を前半（関数・テスト・README の表。承認A）と後半（スクリプト・文書・`.gitignore`）に分け、移行は main が承認B（対応表）・承認C（バックアップ）を取って行う。`experiments/` の改名は評価の直前。<br>未決事項 Q1〜Q6、対応表の未決事項 M1〜M5。<br>対応表の案は `mapping-draft.md` に分けた（main が依頼文で認めた例外。planner が書いてよいのは本来 `plan.md` だけ） | [`plan.md`](./plan.md)、[`mapping-draft.md`](./mapping-draft.md)、`48798a3` |
| 2026-11-24 | ユーザー | **決定** 承認。Q1〜Q5 は推奨どおり。`experiments/` は評価の直前に改名し、マージまで master のスクリプトで読まない。移行は main が承認B・C を取って行う。`runInfo.json` は 4.3 の表のとおり。`Histogram` があれば `tol`・`binWidth` を写す。既存のスクリプトの不具合は推奨のとおりに扱い、今ある警告は直さない | — |
| 2026-11-24 | ユーザー | **決定** Q6：実験名は (a) の8つ。#35 の実験は `grooveBottomDetection`。<br>issue の規則の「slug に合わせる」と「図のテーマと同じ名前にする」が #35 でぶつかるので、README に書く実験名の決め方に「issue の slug が、すでにある図のテーマや評価スクリプトの置き場所の名前と違うときは、すでにある名前に合わせる」を足す | — |
| 2026-11-24 | main | 決定を `plan.md` 8章（と 5.1 の手順9）・`mapping-draft.md` の M6 に書き、状態を「承認済み」にしてコミットする。M1〜M5 と説明の最終案は承認B で決める | [`plan.md`](./plan.md)、`ef39e86` |

### 評価基準 — 承認済み

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | evaluator（A） | `criteria.md` を書き、受け入れテスト（42件）と評価スクリプトを作る（1回目）。途中で利用上限により止まり、同じエージェントを再開して仕上げた。<br>数値の項目は、テスト T1・T2、計画どおりかの確認 P1〜P8、品質の基準 Q1〜Q13（Q3・Q6 は a・b に分ける）、変えてはいけないもの D1〜D4。ユーザーが判断する項目は U1〜U3（移した後の `results/` の並び、実データの `runInfo.json`、README の節）。<br>移す前の `results/`・`experiments/` の817ファイルのパス・大きさ・SHA-256 を `manifestBeforeMigration.csv` に記録した。数え直した数は計画の見込み（603・55・52・92・144）とすべて同じ。<br>仕様どおりの使い捨ての試作で42件すべてが通り、誤りを入れた試作18通りはすべて落ちることを確かめた。未決事項 Q-a | [`criteria.md`](./criteria.md)、`test/unit/ResultLayoutAcceptanceTest.m`、`scripts/evaluation/resultsLayout/` |
| 2026-11-24 | main | 受け入れテストを実行し、3件が通り39件が失敗することを確かめる（関数がまだ無いので正常）。評価基準・受け入れテスト・評価スクリプトを確認待ちでコミットする | `0e60754` |
| 2026-11-24 | ユーザー | **決定** criteria.md を承認した。Q-a は (a)（「計画」だけを満たさないときも不合格にし、実装に戻す） | — |
| 2026-11-24 | main | 決定を criteria.md 7章に書き、状態を「承認済み」にする。受け入れテストを追加したコミット `0e60754` を criteria.md の先頭と 2.2 に書き入れてコミットする | [`criteria.md`](./criteria.md)、`84942d5` |

### 実装と移行 — 作業中（実装は承認済み。移行は承認B 待ち）

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | implementer | 前半（`plan.md` 5.1 の手順1〜11）。`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState` を `src/` に作り、`saveCycleResult` から `collectMeta`・`gitState` を使う形にした。`cycleConditions` に新しい呼び方を足し、`scripts/migration/migrateResults.m` を作った。unit テスト6クラス（46件）を書き、README に「結果の置き場所と実行記録」の節を作った。<br>`runAllTests` は346件すべて通過（受け入れテスト 42/42）。書いた・変えた `.m` 19個の `checkcode` の警告は0件。<br>計画との違いは細部の5つ（`migrateResults` の CSV の確かめ方を厳しくした、識別子 `migrateResults:moveFailed` を足した、README に小節を足したなど）。未決事項 Q1（`kind` に無い高解像度化のパラメータを渡したときの扱い） | [`impl-report-1a.md`](./impl-report-1a.md) |
| 2026-11-24 | main | 差分を確かめる。変えたファイルは計画の前半の範囲だけで、説明だけを直す5つの `src/` は、コメントの行だけが変わっていた。`runAllTests` を実行し、346件すべての通過を確かめる。前半を確認待ちでコミットする | `fd98ae0` |
| 2026-11-25 | ユーザー | **決定** 承認A：README の「`runInfo.json` の項目」の表と「実験名の一覧」を、そのまま承認した。<br>**決定** Q1 は (a)：`runConditions` は、`kind` に無い高解像度化のパラメータも、渡されれば書く。(c)「エラーにする」は、今後の実装の案として残す | — |
| 2026-11-25 | main | 決定を書き、Q1 の (c) を `follow-ups.md` の案A に下書きする | [`follow-ups.md`](./follow-ups.md)、`2416ee2` |
| 2026-11-25 | implementer | 後半（`plan.md` 5.2 の手順12〜20）。スクリプト55本（実験23本は `runConditions`・`resultDir`、うち1周分の8本は `cycleConditions(runCond, …)` も、図32本は `figureDir`）、`.gitignore`、文書15ファイル、README の「対応表」の節を直し、`scripts/migration/resultsMapping.csv` を `mapping-draft.md` の今の案どおりに作った。<br>`runAllTests` は346件すべて通過（受け入れテスト 42/42）。`checkcode` の警告は変える前と同じ27件。移行の試しは `results` 57行・658ファイル、`experiments` 22行・12ファイルで、エラー・警告なし。<br>実データの確認で、`results/bilateralFilter/2026-1125_implCheck/`（37ファイル、wav は 0924 と同じ）と `results/grooveTracking/2026-1125_implCheck/`（15ファイル、`ycoords` は 1014 と `isequal`）を作り、残した。<br>計画との違いは細部の8つ。未決事項 Q1（評価スクリプトが自分自身を対象に数える不具合）、Q2（M1〜M5 と説明に関わる CSV の行） | [`impl-report-1b.md`](./impl-report-1b.md) |
| 2026-11-25 | main | 差分を確かめる。`src/`・`test/`・受け入れテスト・評価スクリプト・`criteria.md`・`plan.md`・`mapping-draft.md`・`follow-ups.md` は変わっていない。`runAllTests` を実行し、346件すべての通過を確かめる。評価スクリプトの不具合（Q1）は、`baseGrepFiles` が基準のコミットの `scripts/` を探すので、自分自身の `mkdirFromDate`・`cycleConditions(` の文字列に当たることを、コードで確かめた。<br>作業ツリーを空にして進捗ログの定期タスクを止めないよう、計画 7.1 の手順2で入れる予定の `.gitignore` も、このコミットに含める（`git mv` は承認の後に行う） | `0e3527e` |
| 2026-11-25 | ユーザー | **決定** 実装の後半を承認した。<br>**決定** 後半の Q1 は (b)：評価スクリプトは直さない。P1・P2・Q7 で、外れが評価スクリプト自身の1本だけのときは、満たしたとする | — |
| 2026-11-25 | main | 決定を `criteria.md` 7章に書く | [`criteria.md`](./criteria.md)、`6dc758a` |
| 2026-11-25 | main | 計画 7.1 の手順2。`.gitignore` は `0e3527e` で入れてある。`git mv results/figures/slides/202609asj results/figures/202609asj/slides` で52ファイルを移し、差分が移動（R100）52行だけであることを確かめてコミットした。空になった `results/figures/slides/` を消した。`git ls-files results` は144のまま | `3f327ed` |
| 2026-11-25 | main | 承認B の材料。作業ツリーが空の状態で、`migrateResults` の試しを両方の段階で実行した。`results` は57行（移す45行・658ファイル、空のフォルダを消す12行）、`experiments` は22行（移す12行・12ファイル、消す10行）で、警告は出なかった。`impl-report-1b.md` 4章の表と同じ。M1〜M5、説明の語、implCheck の2つのフォルダを残すかを、ユーザーに確かめる | `dbad295` |
| 2026-11-26 | ユーザー | **決定** 承認B：移行の試しの表を承認した。M1〜M5 と説明の語は、すべて推奨の (a)（日付は今のフォルダの日付に年を足す。空の `experiments/1026/`・`1110/` は消す。`0831/digitalNeedle/` はほかと同じ規則で移し、ファイル名の日付も変える。`results/1111/README.md` はそのまま移す。`results/1110/` は移して残す。説明は `mapping-draft.md` の表のとおり）。<br>**決定** 実装担当の確認で作った `results/bilateralFilter/2026-1125_implCheck/` と `results/grooveTracking/2026-1125_implCheck/` は残す。新しい形の名前なので、移さずに残す古い形のフォルダ（評価スクリプトの `APPROVED_LEFTOVERS`）には当たらない。承認B で残す・消すと決めた古い形のものは無いので、`APPROVED_LEFTOVERS`・`APPROVED_DELETIONS` は空のまま | — |
| 2026-11-26 | main | 決定を `mapping-draft.md` の未決事項の節に書く | [`mapping-draft.md`](./mapping-draft.md)、`831e64d` |
| 2026-11-26 | main | 計画 7.1 の手順3。作業ツリーが空の状態で、`migrateResults(..., Phase="results")` の試し（移す45行・658ファイル、消す12行。承認B の表と同じ）→ `DryRun=false` で移す → もう一度試す、の順に行った。最後の試しは57行すべて `done` で、警告は出なかった。<br>`results/` の直下は実験名7つ（`stylus` はまだ無い）と `figures` だけになった。移したファイルの数は、実験名ごとに合計603（implCheck の52を除く）と原稿用の55で、計画と同じ。`git status` は空のままで、`git ls-files results` は144 | — |

### 評価 — 未着手
### 振り返り — 未着手
### 続きのissue — 未着手
### 解決のまとめ — 未着手
### 仕上げ（closed/ へ移動・PR） — 未着手

## ファイル一覧

- `README.md`：このファイル
- [`plan.md`](./plan.md)：計画
- [`mapping-draft.md`](./mapping-draft.md)：既存のフォルダの対応表の案（計画の付属）
- [`criteria.md`](./criteria.md)：評価基準
- [`impl-report-1a.md`](./impl-report-1a.md)：実装の報告（1回目の前半）
- [`impl-report-1b.md`](./impl-report-1b.md)：実装の報告（1回目の後半）
- [`follow-ups.md`](./follow-ups.md)：続きのissueの案（下書き。仕上げで確定する）
