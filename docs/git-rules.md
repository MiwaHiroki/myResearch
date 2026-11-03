# git操作ルール（Claude用）

## 目的

Claudeがこのリポジトリでgit操作を行う際、後から**いつ・どのファイルを・何のために**変更したかを誰でも確実に追えるようにする。

- 「いつ」は`git log`のコミット日時がそのまま記録になる。
- 「どのファイル」は`git diff --stat`/`git show --stat`がそのまま記録になる。
- 「何のために」だけはコミットメッセージ本文に書かない限り残らない。ここが最も欠けやすいので、以下のルールで担保する。

コミットは常にユーザーから明示的な指示があった場合のみ行う（無断コミットはしない）。これは本ドキュメント固有の話ではなく既存のグローバルルールの確認。

例外: `docs/progress/`配下の進捗ログ自動更新に限り、スケジュールタスク（`progress-report-daily`、毎日3時実行）による自動commitを許可する（2026-09-23、ユーザー承認）。このコミットは常に`master`に対して行う。そのため、作業ブランチをチェックアウトしているときは、タスクがメインのチェックアウトを一時的に`master`へ切り替え、コミットした後に元のブランチへ戻すことがある。追跡されているファイルに未コミットの変更があるときは切り替えず、その日は見送って通知する（2026-10-22、issue #27）。それ以外のファイル・コードの変更を無断commitすることは引き続き禁止。

## コミットのルール

### ルール1: 1コミット=1目的

複数の目的（例: リネームとバグ修正、機能追加とドキュメント整理）が混ざる変更は、目的ごとに分けてコミットする。`git add`でファイル単位・hunk単位に分割してよい。

### ルール2: コミット本文に「なぜ」を必ず1行以上書く

タイトルは「何をしたか」を簡潔に。本文には、なぜこの変更が必要だったか（背景・目的・きっかけ）を最低1行書く。タイトルだけで自明に見えるケースでも省略しない。

良い例（過去コミット`df8e061`を踏襲）:

```
DarknessMap.imgWidth/imgHeightをwidth/heightへ改名（rename-proposal P4-1）

ImageData/GroovePointCloudと命名を揃え、img接頭辞を廃した。DarknessMap本体
（プロパティ宣言・コンストラクタ・dInterpのmeshgrid呼び出し）3箇所の書き換え
は、Ollama MCPサーバーに新設した部分編集ツールedit_file_with_ollama経由で
ローカルLLM(gemma4)に委譲し、3/3成功（差し戻し・引き取りなし）。呼び出し元
（GroovePointCloud, DarknessMapTest, scripts/4本）とrename-proposal.mdを
Claudeが機械的に更新。

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
```

### ルール3: 「いつ」はgitのコミット日時に委ねる

本文に日付を手書きする必要はない（`git log`のAuthor Dateが正）。ただし`docs/`内の経緯記録（`rename-proposal.md`など）に日付を明記するのは従来通りでよい。

### ルール4: 「どのファイル」は`git diff --stat`に委ねつつ、機械的な一括変更は対象範囲を一言添える

ファイル一覧を本文に書き写す必要はない。ただし、リネーム等で多数ファイルを機械的に変更した場合は、対象ファイル群の性質（例:「呼び出し元3ファイルを機械的に更新」）を一言添えると、後から変更の妥当性を判断しやすい。

### ルール5: Claude以外（ローカルLLM等）が実際に編集した箇所は明記する

Ollama経由のgemma4など、Claude以外のツール・エージェントが実際にファイルを書き換えた場合は、その旨をコミット本文に明記する。誰が（何が）どの範囲を担当したかを後から追えるようにするため。

### ルール6: サブエージェントが関わったコミットには`Agent:`を付ける

サブエージェント（`.claude/agents/`の`planner`・`evaluator`・`implementer`など）はコミットしない。各段階の成果物は、ユーザーの承認後にメインセッションがコミットする。そのコミットまでに関わったエージェントを、コミットメッセージ末尾の`Co-Authored-By:`の直前に1行ずつ書く。メインセッション自身が編集した場合は`Agent: main`と書く。

```
Agent: planner
Agent: main
```

`git log --grep "Agent: planner"`で、そのエージェントが関わったコミットを検索できる。

## ブランチ運用

- 指示内容が明確で影響範囲が小さい単純な変更（例: 1ファイルのリネーム、ドキュメント更新）は、これまで通り`master`に直接コミットしてよい。
- Claudeが自律的に複数ファイル・複数ステップにまたがる変更を行う場合は、作業ブランチを切る。ユーザーがマージ前に差分をレビューできるようにするため。
- ブランチ名は`claude/<内容を表す短い英語スラッグ>`とする（例: `claude/darkness-map-rename`）。既存の`feature/*`・`backup/*`と混在させず、Claude発の作業ブランチだと一目で分かるようにする。
- ローカルの`master`には、進捗ログの自動更新のコミットが毎日入る。`master`をrebase・resetしない（`git pull --rebase`を含む）。`.state.json`の`last_commit`が`master`の履歴からたどれなくなり、タスクが止まるため（issue #27）。

## worktreeでの並行作業

複数のClaudeセッションを並行して走らせるときは、セッションごとにgit worktreeを使い、編集が衝突しないようにする。

- **作り方**: デスクトップアプリでセッション開始時に「worktree」を選ぶ（CLIなら`claude --worktree <名前>`）。`.claude/worktrees/<名前>/`に作られ、`.claude/`ごとgitignore済み。分岐元はメインのチェックアウトの現在の`HEAD`（`.claude/settings.json`の`worktree.baseRef: "head"`。未pushのコミットも含めるため）。
- **初期化は自動**: `core.hooksPath=.githooks`で有効化した`.githooks/post-checkout`が、worktree作成時に以下を行う（メインのチェックアウトでは何もしない）。
  - `data/`・`experiments/`: メインへのジャンクションを張る。**中身はメインと共有**なので、worktree側で消すとメインからも消える。worktreeを削除してもリンクが消えるだけで、リンク先は残る（確認済み）。
  - `.claude/settings.local.json`（許可設定）: メインからコピー（gitignoreされているため）。コピーなので、恒久的に直したい場合はメイン側を編集する。
  - 失敗した・手動で`git worktree add`した場合は、worktree内で`sh .githooks/post-checkout`を実行すればやり直せる。別PCでは`git config core.hooksPath .githooks`を一度実行して有効化する。
- **`results/`は共有しない**: worktreeの`results/`は独立。残したい出力はマージ前にメインへ移す。
- **ブランチ**: worktreeのブランチもClaude発の作業ブランチとして扱い、下記「プルリクエスト運用」に従う。`master`はメインのチェックアウトが使っているため、worktree内で直接`master`にコミットはできない。worktreeで`master`をチェックアウトしない（進捗ログのタスクが、メインのチェックアウトを`master`に切り替えられなくなる。issue #27）。
- **MATLAB**: MATLABは1つを全セッションで共有している。テスト（`test/unit/`）は自分のファイル位置から`src/`を足すので、worktreeのテストファイルを絶対パスで`runtests`すればworktree側のコードで走る。`currentProject()`に依存する`scripts/`は開いているプロジェクトのルートを使うため、worktree側で実行する場合はそのworktreeの`Research.prj`を開く必要があり、他のセッションに影響する。同時に複数セッションからスクリプトを走らせない。
- **後片付け**: 作業が終わったworktreeは、ブランチをマージ（またはPR化）してから`git worktree remove`で削除する。削除はユーザーの指示があってから行う。

## プルリクエスト運用

- 作業ブランチでの変更が完了したらリモートへpushし、`gh pr create`でPRを作成する。push・PR作成はユーザーへの影響が及ぶ操作なので、実行前に一言確認してから行う（既存のグローバルルールの適用）。
- PRのタイトル・本文はコミットメッセージと同じ基準（何を・なぜ）を満たす。本文には目的・背景を必ず書く。
- `docs/issues/<番号>-<slug>/` を使ったissueでは、PRの最後のコミットでそのフォルダを `docs/issues/closed/` へ`git mv`し、PR本文に`Closes #<番号>`を書く（[`issues/README.md`](issues/README.md)）。
- PRの**マージはユーザーが行う**。Claudeは`gh pr merge`を実行しない。
- マージ済みブランチの削除も、ユーザーの指示があってから行う（削除は破壊的操作のため）。
- force-pushや履歴の書き換えは、共有ブランチに対しては行わない（既存のグローバルルールの適用）。
