# issueの書き方・扱い方

## 方針

このリポジトリのissueは、**Claudeへの作業依頼書**を兼ねる。Claudeがissueを読んだだけで、質問を何度も往復せずに最後まで作業できることを一番に考えて書く。

ひな型は `.github/ISSUE_TEMPLATE/` にある。GitHubの「New issue」から選ぶとラベルが自動で付く。

| ラベル | ひな型 | 使う場面 |
|---|---|---|
| `bug` | [bug.md](../.github/ISSUE_TEMPLATE/bug.md) | エラー、誤った出力、想定外の挙動 |
| `refactor` | [refactor.md](../.github/ISSUE_TEMPLATE/refactor.md) | 動作を変えずに構造・命名・責務を整理する |
| `feature` | [feature.md](../.github/ISSUE_TEMPLATE/feature.md) | 関数・クラス・処理・スクリプトの追加 |
| `dataset` | [dataset.md](../.github/ISSUE_TEMPLATE/dataset.md) | 実験データ（cycleResult など）の生成と保存 |
| `figure` | [figure.md](../.github/ISSUE_TEMPLATE/figure.md) | 論文・スライド用の図表 |
| `documentation` | [documentation.md](../.github/ISSUE_TEMPLATE/documentation.md) | README・docs・ヘルプの追加や修正 |
| `good first issue` | [good-first-issue.md](../.github/ISSUE_TEMPLATE/good-first-issue.md) | 範囲が小さく手順が決まったタスク（Claude・gemma4に丸ごと任せる候補） |
| `high priority` | なし | 優先度のラベル。上のどれかと一緒に付ける |

## 共通の見出し

どのひな型も次の見出しをこの順番で持つ（ラベルごとの見出しは「対象ファイル」の後に入る）。

| 見出し | 書くこと | 必須 |
|---|---|---|
| ゴール | 終わったときに何ができるようになっているか（1〜2文） | ◯ |
| 背景・目的 | なぜやるのか。Claudeが迷ったときの判断基準になる | |
| 対象ファイル | リポジトリからの相対パス。不明なら「要調査: <範囲>」 | ◯ |
| 制約・触らないもの | 変えてはいけないもの（出力、公開API、archive/ など） | |
| 未決事項（着手前に要確認） | ユーザーが決めること。無ければ「なし（Claudeの判断で可）」 | ◯ |
| 完了条件 | チェックボックス。1項目ずつ確認できる形で | ◯ |
| 検証方法 | 実際に打つコマンド（`cd test; runAllTests` など） | ◯ |
| 実行の前提 | 使うデータのパス、ginputが必要か、ClaudeがMATLABで実行してよいか | |
| 作業の進め方 | masterに直接 / `claude/<slug>` ブランチ＋PR | |
| 関連 | 関連issue、コミット、docs | |

必須の欄が埋まっていないissueは、Claudeが着手前に質問する。

書き方のコツ:
- 案が複数あるときは、採用する案を決めて書くか、「未決事項」に選択肢を書く。案を並べたままにしない
- 「scripts/のほぼすべて」ではなく、分かる範囲でパスを書く。分からなければ「要調査」と明記する（Claudeが調べて一覧を示す）
- `data/` と `experiments/` はgit管理外。データが必要なら手元のパスを書く

## Claudeがissueを受け取ったときの手順

1. `gh issue view <番号> --comments` でissueとコメントを読む
2. 「未決事項」に何か書いてあれば、作業の前にユーザーに確認する。必須の欄が空のときも同じ
3. 「対象ファイル」と「関連」を読む。「要調査」の場合は調べた結果（対象ファイルの一覧）を示してから作業する
4. 「作業の進め方」に従ってブランチを決める（空欄なら [git-rules.md](git-rules.md) の基準で決める）
5. 作業する。「制約・触らないもの」は守る
6. 「完了条件」を1つずつ確認し、「検証方法」のコマンドを実行する
7. 結果（何をしたか、検証の結果、残った課題）をissueにコメントする文案をユーザーに見せる。投稿はユーザーの確認を取ってから
8. コミットする（[git-rules.md](git-rules.md) に従い、コミットメッセージに `#<番号>` を入れる）。push・PR作成・issueのcloseはユーザーに確認してから

複数の段階（計画、実装、評価 など）に分けて、サブエージェントやセッションをまたいで進める作業は、**必ずissueを立ててから始める**（受け渡しフォルダの置き場所がissue番号で決まるため）。そのようなissueでは、受け渡しファイルを `docs/issues/<番号>-<slug>/` に置き、PRの最後のコミットで `docs/issues/closed/` に移す。詳しくは [`issues/README.md`](issues/README.md) を参照。

原則: **情報が足りないときは推測で進めず質問する**。特に、出力の数値が変わる変更、ファイルの削除、既存データの上書きは、issueに書かれていない限り行わない。
