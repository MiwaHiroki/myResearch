---
name: refactor
about: 動作を変えずにコードの構造・命名・責務を整理する
title: "[refactor] "
labels: ["refactor"]
---

<!-- 書き方は docs/issue-guide.md を参照。急ぎなら high priority ラベルも付ける。
     リネームや責務の移動が src/・test/・scripts/ にまたがる場合、Claude は matlab-refactor エージェントを使う。 -->

## ゴール
<!-- 終わったときにコードがどうなっているか。1〜2文 -->

## 背景・目的
<!-- なぜ今のままだと困るのか（読みにくい、重複している、名前と中身が合わない など） -->

## 対象ファイル
<!-- 変更の中心になるファイル。リポジトリからの相対パス -->
- 

## 現状
<!-- 今の構造・名前・呼び出し方。コード片があると確実 -->
```matlab

```

## あるべき姿
<!-- 変更後の呼び出し側のコード例。複数案がある場合は採用案を1つに決めるか、「未決事項」に書く -->
```matlab

```

## 影響範囲
<!-- 確認すべき範囲にチェック。archive/ は原則対象外 -->
- [ ] `src/`
- [ ] `test/unit/`
- [ ] `scripts/`（`scripts/archive/` を除く）
- [ ] `scripts/paper/`・`scripts/slides/`
- [ ] `README.md`・`docs/`
- [ ] `Research.prj`（ファイルの追加・削除・移動がある場合）

## 制約・触らないもの
- 数値の出力（抽出した溝形状・音声）は変えない
- `src/archive/`・`scripts/archive/`・`test/archive/` は変更しない
- 

## 未決事項（着手前に要確認）
<!-- ユーザーが決めること（名前の最終案、互換用の旧名を残すか など）。無ければ「なし（Claudeの判断で可）」 -->
- なし（Claudeの判断で可）

## 完了条件
- [ ] 「あるべき姿」のとおりに変更した
- [ ] 影響範囲の呼び出し側をすべて更新した（grep で旧名が残っていない）
- [ ] テストを更新・追加した
- [ ] `cd test; runAllTests` が全部通る
- [ ] （出力に関わる場合）変更前後の出力が一致することを確認した
- [ ] README・docs の記述を更新した

## 検証方法
```matlab
cd test
results = runAllTests;
```
<!-- 旧名の残りを探す: git grep -n "<旧名>" -- ':!*/archive/*'
     出力の一致確認をする場合は、比較する mat / スクリプトを書く -->

## 実行の前提
<!-- 出力比較にスクリプト実行が必要な場合: データのパス、ginput の要否（grooveSelection の再利用）、Claude が MATLAB で実行してよいか -->
- データ: 
- ginput: 不要 / 必要（grooveSelection: ）
- ClaudeによるMATLAB実行: 可 / 不可

## 作業の進め方
<!-- 複数ファイルにまたがる場合は claude/<slug> ブランチ＋PR が基本（docs/git-rules.md） -->

## 関連
<!-- 関連 issue (#番号)、docs/refactoring/rename-proposal.md の項目番号 など -->
