- 段階: 計画
- 作成者: planner
- 作成日: 2026-10-22
- 入力: issue #27、[`README.md`](./README.md)（決定事項）、[`skill-before.md`](./skill-before.md)、メインの依頼文（1回目）、メインからの追加の事実（許可ルールの照合、9項目。2026-10-22）
- 状態: 承認済み（2026-10-22、main。今回はユーザーの指示により、メインが承認する。8章の未決事項はすべて推奨どおりに決定）

# #27 計画：進捗ログの自動更新を、常にmasterに対して行う

この計画では、issueの未決事項を「issueのQ1」「issueのQ2」と書く。単に「Q1」〜「Q9」と書いたものは、この計画の8章の未決事項を指す。

## 1. 結論

- **案B（先に読み、書き込みが要る日だけ切り替える）を推奨する。** タスクはまず、ブランチを切り替えずに `git show master:docs/progress/.state.json` と `git log <last_commit>..master --first-parent` でmasterの状態を読み、「やること」があるかを決める。無ければ何もせずに終わる。
- やることがあり、チェックアウト中が作業ブランチ B なら、**追跡されているファイルに未コミットの変更が無いときだけ**、元のブランチ名を `git config progress-report.return-branch B` に記録してから `git switch master` を実行する。進捗ログを書いて `git commit -m … -- docs/progress/`（docs/progress だけをコミットする形）でコミットし、`git switch -` で戻して記録を消す。
- **タスク自身のコミット（「進捗ログ自動更新（」「進捗期間を区切り、新しい期間ファイルを開始（」）は、日次ログに載せず、「やること」にも数えない**（Q1）。今は、毎回の実行で前回のタスク自身のコミットが「新しいコミット」になるので、何もしない日がほとんど無い。このままだと、作業ブランチにいる間は毎日ブランチを切り替えることになる。
- `last_commit` は毎回、(1) masterの祖先であること、(2) masterのfirst-parentの鎖の上にあること、を確かめる。どちらかが外れたら、何も変えずに通知する。PRのマージは、first-parentの1件として、マージの日の見出しの下に「PR #NNをmerge（要約）」の行と、中身のコミットの子の行（元の日付つき）で書く。見出しの日付は、末尾の見出しの日付より前に戻さない。
- 検証は次の3つで行う。(i) 砂場のcloneで、ヘッドレスの `claude -p` に `skill-after.md` を実行させる予行（必須17場面。許可ルールも本番と同じものを使う）。(ii) 許可ルールとコマンドの形の対応表。(iii) メインによる本物の手動実行（メインのチェックアウトがmasterのとき）。作業ブランチでの本物の実行（iv）は、メインのチェックアウトが空いたときに行う。

## 2. 調査結果

### 2.1 今のプロンプトと許可ルール

- `skill-before.md` の手順2・5は `HEAD` を基準にしている（`git log <last_commit>..HEAD`、`git rev-parse HEAD`）。手順6の `git commit -m` は、インデックス全体をコミットする（`docs/progress/` 以外がステージされていると混ざる）。
- 許可ルール（メインのチェックアウトの `.claude/settings.local.json`。worktree側の写しと同じ内容であることを `diff` で確かめた）のうち、タスクに関係するもの：
  - 既存：`git add docs/progress/*`、`git mv docs/progress/*`、`git commit -m *`、`git commit -q -m *`、`git log *`、`git rev-parse *`（それぞれBashとPowerShell）、`Write`・`Edit`（`docs/progress/**` の絶対パス）、`Read(//c/Users/owner/Documents/HirokiMiwa/matlab@Miwa/**)`、`PushNotification`
  - Bashだけにある広いもの：`Bash(git config *)`、`Bash(git worktree *)`（タスクとは別の用途で足されたもの。今回は触らない）
  - 無いもの：`git status`、`git show`、`git merge-base`、`git switch`
- ユーザーの設定（`~/.claude/settings.json`）には allow が無い。

### 2.2 実行環境（メインが確かめた事実と、この調査で確かめたこと）

- 許可ルールの照合（メインの確認）：`*` の無いルールは完全一致。`Bash(git status *)` は引数なしの `git status` にも一致する。`&&`・`;`・`|` でつないだコマンドは、サブコマンドごとに照合される。`2>&1` の扱いは文書に無い。`git -C <path> …` は `-C` が剥がされないので一致しない。BashのルールはPowerShellツールには効かない。単独の `-`（`git switch -`）の扱いは文書に無い。予定タスクに効くと明記されているのは `~/.claude/settings.json` だけ。ただし、今のタスクはプロジェクトの `settings.local.json` のルールで毎晩承認なしに動いている。実行中に「always allow」を選ぶと、タスクごとの「Always allowed」にも保存される。
- タスクのセッションは、Bashツールでgitを1コマンドずつ実行し、進捗ファイルはWriteツールで書いていた（メインの確認）。
- タスクは、アプリが起動していてPCが起きているときだけ動く。スリープ中に予定の時刻が過ぎると、起きた後に1回だけ追いついて実行する（メインの確認）。**深夜以外（ユーザーや並行のセッションが作業している時間）に動くことがある。**
- `.githooks/post-checkout` は、`git rev-parse --absolute-git-dir` と `--git-common-dir` が同じ（＝メインのチェックアウト）なら、すぐ `exit 0` する（コードを読んで確認）。`git switch` のたびに呼ばれるが、メインのチェックアウトでは何もしない。
- gitは2.55.0（`git config --get --default` が使える）。`pull.rebase=false`。MATLABプロジェクトの定義ファイル（`resources/project/` の144ファイル）がgitで追跡されている。ブランチ間でこれらが違うと、切り替えのたびにMATLABプロジェクトのファイルが変わる。
- `claude` CLI（2.1.300）が `C:\Users\owner\.local\bin\claude` にある（予行でヘッドレス実行に使える）。
- メインのチェックアウトの `git status` は、この調査では読めなかった（worktreeに隔離されたセッションは、共有のチェックアウトでgitを実行できない）。メインも同じ制約を受けるはずなので、(iii) の確認は、worktreeから参照できる範囲（`git log master`、`git show master:…`、`git worktree list`、`git config --get`）で行う。

### 2.3 履歴から分かったこと

1. **タスク自身のコミットが毎日「新しいコミット」になる。** `last_commit` はコミットの前の `HEAD` を指す（自分自身のハッシュは書けない）。そのため、次の実行では前回のタスク自身のコミットが必ず範囲に入る。日次ログの 10-14〜10-20 は、ほぼ「進捗ログ自動更新（…分）」の1行だけになっている（`docs/progress/2026-1012_1021.md`）。今のままだと、何もしない日はほとんど無い。
2. **masterのfirst-parentのmergeは2種類ある。** GitHubのPRのマージ（`b479770` #26、`93bd2e3` #24、`3672139` #19）と、`git pull` によるマージ（`d286241`・`d25d3fb`・`83b77f7` の「Merge branch 'master' of https://github.com/…」）。mergeコミットのAuthor Dateは、マージした日になる。
3. **過去の日付のコミットが、first-parentの鎖に入ることがある。** 10-22のcherry-pick（`5376e05`・`dfe7e4e`・`26c6efd`。Author Dateは10-20・10-21、Commit Dateは10-22）、amendやrebase（`c628f72`・`e98e6fc`）がその例。
4. **PR #26 の中身**（`cd92072..32df69a`）は21コミット。そのうちmergeが5件、作業ブランチに入ったタスク自身のコミットが7件、残りの9件がふつうのコミット。
5. **PRのマージの書き方の前例**：`2026-0810_1012.md` では「PR #19をmerge（grooveShape3d関連）」の1行と、ブランチのコミットがそれぞれの日付の見出しに並んでいる。この期間のファイルは全履歴からまとめて作ったので、日付順に並んでいる。日々の追記では、この並びにはならない。
6. **`last_commit` の確かめ方**（付録B）：
   - `git log <X>..master` は、X がmasterの祖先でなくても失敗しない（範囲がずれて、二重に追記される）。作業ブランチ側に残っていた `d4030e1` は、`git merge-base d4030e1 master` が `32df69a` を返すので、祖先でないことが分かる。
   - X がmasterの祖先でも、first-parentの鎖の上にない場合がある（例：`32df69a` はPR #26 の作業ブランチの先端）。その場合、`git log 32df69a..master --first-parent` の最初の行（`b479770`）の第1親は `cd92072` になり、X と一致しない。このままmergeの中身を展開すると、作業ブランチの時点で載せたコミットを二重に載せる。
7. 同じ日付の見出しは、今のところ二重になっていない。しかし、手動の実行の後に3時の実行が来る場合や、0時から3時のあいだのコミットがある場合には、今の手順（末尾に `### YYYY-MM-DD` を足すだけ）では二重になる。

## 3. 案の比較

### 3.1 切り替えのしかた（issueのQ1(a)の範囲内での案）

| 案 | 内容 | 長所 | 短所 | 根拠 |
|---|---|---|---|---|
| A 毎回切り替える | 作業ブランチなら、毎回masterへ切り替えて今の手順をそのまま行い、戻す | 手順が単純。今の手順をほぼそのまま使える | 作業ブランチにいる間は、ほぼ毎日切り替える（2.3の1）。切り替えるたびに、並行のセッションやMATLABへ影響する機会になる。`last_commit` の異常にも、切り替えた後でしか気づけない | 10-14〜10-20 は毎日、書き込みがあった |
| **B 先に読み、必要な日だけ切り替える（推奨）** | `git show master:…` と `git log …..master` で、切り替えずに判定する。書き込みが要る日だけ切り替える | タスク自身のコミットを除けば（Q1）、作業ブランチにいる間の切り替えは、masterに新しいコミットがある日、期間の区切りの日、3日ごとの通知の日だけになる。`last_commit` の確認も切り替えの前に済み、異常があってもチェックアウトに触れない | コマンドの形が2つ増える（`git show`、`git merge-base`）。Q1の(a)と組み合わせないと、切り替える日は減らない | 付録Aで、読み取りの形が今のmasterで想定どおりに動くことを確かめた |
| C 下書きまで切り替えの前に済ませる | Bに加えて、追記する行とまとめを切り替えの前に作る。切り替えた後は書くだけにする | masterにいる時間が最も短い | Edit・Writeの前に、切り替えた後のファイルを読み直す必要がある（中身とmtimeが変わるため）。古いファイル（作業ブランチ側）と新しいファイルを取り違える危険がある | — |

Bを推奨する。Cの利点は、「切り替える前に、追記する行の下書きを作っておいてよい」という一文として、Bに取り込む（コマンドは増えない）。

採らない案：gitの低水準のコマンド（`hash-object`・`commit-tree`・`update-ref`）で、チェックアウトに触れずにmasterへコミットする方法。コマンドの形が多く、LLMが正確に組み立てるのは難しい。masterをチェックアウト中のときは作業ツリーとずれる。このため採らない（issueのQ1はすでに(a)に決まっている）。

### 3.2 細かい選択

| 項目 | 推奨 | 他の案 | 推奨の理由 |
|---|---|---|---|
| 元のブランチへの戻し方 | `git switch -`（完全一致のルール） | `git switch @{-1}`（PowerShellでは `@{` が壊れる）／`git switch <B>`（`git switch *` が要り、`-c`・`-f`・`--discard-changes` も許してしまう。denyで防ぐと、ふだんの `git switch -c claude/<slug>` も止まる）／`git checkout -`（`-` の不確かさは同じ） | ワイルドカードを使わずに済む。単独の `-` が一致するかは文書に無いので、予行で確かめる（9章のR1） |
| 途中で止まったときの記録 | `git config progress-report.return-branch <B>`（切り替えの前に書き、戻ってから消す）（Q5） | `temp/` に印のファイルを置く（Writeのルールが増える）／reflogから推測する（ユーザーの切り替えと区別できない）／記録しない | ブランチを切り替えても消えない。作業ツリーの状態にも影響しない。どの時点で止まっても残る |
| masterをチェックアウト中で、docs/progress 以外に未コミットの変更（ステージ済みを含む）があるとき | 続ける。`git commit … -- docs/progress/` で docs/progress だけをコミットする（Q3） | 持ち越して通知する | パス指定のコミット（`--only` の動作）は、ほかのパスのステージを残したままにするので、混ざらない。masterで直接作業する日でも、進捗ログが止まらない |
| 作業ブランチで、追跡されていないファイルだけがあるとき | 切り替える（`--untracked-files=no` で判定）（Q4） | 持ち越す | 追跡されていないファイルを上書きする場合、`git switch` は何も変えずに止まる。消えないファイルが残っていると、ずっと持ち越しになってしまう |
| PRのマージの書き方 | 親の1行と、中身の子の行（元の日付つき）（Q2） | 1行だけ／first-parentを使わず平らに並べる | 作業ブランチの途中経過がマージの後にしか載らない（issueのQ2(a)）ので、中身を残したほうがスライドを作るときに役に立つ |
| 見出しの日付 | 末尾の見出しの日付より前に戻さない。同じ日付なら、その見出しの下に続けて書く | 日付どおりに見出しを足す（過去の日付の見出しが末尾に並ぶ）／正しい位置に差し込む（既存の部分を変えることになり、「追記のみ」に反する） | 「追記のみ」を守りつつ、見出しが日付順に並ぶ |

## 4. 設計

### 4.1 処理の流れ（旧手順との対応）

| 旧（`skill-before.md`） | 新（`skill-after.md`） |
|---|---|
| 前提知識（状態ファイル、命名規則、期間ファイルの構成） | そのまま |
| 前提知識（許可の範囲、書き込みの形） | 「使ってよいコマンドの一覧」（4.2.2）に置き換える |
| 手順1（未コミットの残りを含める） | 手順3のmasterの行 |
| 手順2（`git log <last_commit>..HEAD`） | 手順2-1〜2-4（`..master --first-parent`、祖先と鎖の確認、mergeの展開、タスク自身のコミットを除く） |
| 手順3（0件なら手順7だけ） | 手順2-5（やることが無ければ、何もせず終わる） |
| 手順4a・4b（Author Dateでまとめて末尾に追記） | 4.2.4 の規則 |
| 手順4c（まとめを作り直す） | そのまま |
| 手順5（`git rev-parse HEAD`） | 手順4-3（`git rev-parse master`） |
| 手順6（`git add` と `git commit -m`） | 手順4-4・4-6（`-- docs/progress/` を付ける） |
| 手順7（期間の区切り、通知の判定） | 手順4-5（中身はそのまま） |
| 注意事項 | そのまま。「切り替えた後にエラーになったら、手順5を試みてから通知する」を足す |

### 4.2 `skill-after.md` の中身

frontmatterは付けない（`update_scheduled_task` の `prompt` にそのまま渡す本文）。**1行目だけに、対象リポジトリの絶対パスを書く**（予行では1行目だけを差し替えるため。ほかの行に絶対パスを書かない）。変えない部分（状態ファイル、命名規則、期間ファイルのひな型、手順7b・7cの中身）は、`skill-before.md` の文言を残す。

#### 4.2.1 見出しの構成

```
（1行目）対象リポジトリ: `<絶対パス>`（…カレントディレクトリは常にこのリポジトリのルート…）
（導入）…進捗ログは常にmasterの履歴を読み、masterにコミットする。…
## 前提知識
  - 状態ファイル／ファイル命名規則／期間ファイルの構成（変更なし）
  - 基準はmaster（HEADではない）。作業ブランチのときの切り替えの考え方
  - タスク自身のコミットの見分け方
  - 自動commitの例外規定（変更なし。masterに対して行う、を足す）
  - 使ってよいコマンドの一覧（4.2.2）と、書き方の約束
## 手順
  1. 状況を確かめる（何も変えない）
  2. masterの状態を読み、今日やることを決める（何も変えない）
  3. 作業する場所を用意する
  4. 進捗ログを書き、masterにコミットする
  5. 元のブランチに戻す（手順3で切り替えたときだけ）
## 日次ログの書き方（4.2.4）
## 通知の文（4.2.5）
## コミットの件名と本文（4.2.6）
## 注意事項
```

#### 4.2.2 使ってよいコマンドの一覧（プロンプトに、この一覧のとおりに書く）

「これ以外のコマンドは使わない。1回のツール呼び出しにつき1コマンド。`;`・`&&`・`|` でつながない。`2>&1` などのリダイレクトや `-C` を付けない。Bashツールを使う。」と書く。

| # | コマンドの形 | 種類 | 使う手順 |
|---|---|---|---|
| 1 | `git config --get --default none progress-report.return-branch` | 読み | 1-1 |
| 2 | `git rev-parse --abbrev-ref HEAD` | 読み | 1-2、5-3 |
| 3 | `git show master:docs/progress/.state.json` | 読み | 2-1 |
| 4 | `git merge-base <last_commit> master` | 読み | 2-2 |
| 5 | `git log <last_commit>..master --first-parent --date=short --pretty=format:"%H\|%ad\|%P\|%s" --reverse` | 読み | 2-3 |
| 6 | `git log <親1>..<親2> --date=short --pretty=format:"%h\|%ad\|%P\|%s" --reverse` | 読み | 2-4 |
| 7 | `git status --porcelain --untracked-files=no` | 読み | 3 |
| 8 | `git status --porcelain -- docs/progress/` | 読み | 2-5、3、5-1 |
| 9 | `git rev-parse master` | 読み | 4-3 |
| 10 | `git config progress-report.return-branch <ブランチ名>` | 書き | 3 |
| 11 | `git config --unset progress-report.return-branch` | 書き | 1-3、3、5-3 |
| 12 | `git switch master` | 書き | 3 |
| 13 | `git switch -` | 書き | 5-2 |
| 14 | `git add docs/progress/<ファイル> [docs/progress/<ファイル> ...]` | 書き | 4-6 |
| 15 | `git mv docs/progress/<旧> docs/progress/<新>` | 書き | 4-5 |
| 16 | `git commit -m "<件名>" -m "<本文>" -m "Co-Authored-By: …" -- docs/progress/` | 書き | 4-6 |

（表の中の `\|` は、表の区切りと区別するための書き方。プロンプトには `|` と書く。）

ほかに使ってよいもの：Read（リポジトリの中）、Write・Edit（`docs/progress/` の中だけ）、PushNotification。

#### 4.2.3 手順

**手順1 状況を確かめる（何も変えない）**
- 1-1 コマンド1で、前回の記録 R を読む（記録が無ければ `none` が出る）。
- 1-2 コマンド2で、チェックアウト中のブランチ CUR を読む（`master`、ブランチ名、detached HEAD のときは `HEAD`）。
- 1-3 R が `none` でないとき：
  - CUR が `master` → 通知N2を送り、何も変えずに終わる（前回の実行が、masterに切り替えた後に止まった）。
  - CUR が `master` でない → コマンド11で記録を消して、続ける（前回は、戻った後に止まっただけ）。

**手順2 masterの状態を読み、今日やることを決める（何も変えない）**
- 2-1 コマンド3で、masterの `.state.json`（S）を読む。読めない、JSONとして壊れている、`last_commit` が null のいずれかなら、通知N5を送って終わる。
- 2-2 コマンド4の出力が `S.last_commit`（40桁）と一致することを確かめる。一致しない（エラーを含む）なら、通知N4を送って終わる。
- 2-3 コマンド5で、新しいコミットの一覧 L を得る。L が空でなければ、1行目の `%P` の1つ目のハッシュが `S.last_commit` と一致することを確かめる。一致しなければ、通知N4を送って終わる（`last_commit` がfirst-parentの鎖の上にない）。
- 2-4 L の各行を分ける。
  - タスク自身のコミット（件名が「進捗ログ自動更新（」または「進捗期間を区切り、新しい期間ファイルを開始（」で始まる）は除く。
  - `%P` にハッシュが2つある行（merge）は、コマンド6（親1..親2）で中身を読む。中身から、mergeとタスク自身のコミットを除く。中身が空になれば、そのmergeも除く。
  - 残ったものが「載せるコミット」。
- 2-5 TODAY（今日の日付）で、やることを判定する。
  - (A) 載せるコミットが1件以上ある。
  - (B) `S.next_report_date` がnullでなく、`TODAY >= next_report_date`（旧7b）。
  - (C) `S.next_report_date` がnullで、`next_report_date_last_asked` がnull、または TODAY との差が3日以上（旧7c）。
  - (D) CUR が `master` で、コマンド8の出力が空でない（前回の実行の残り）。
  - どれにも当たらなければ、ここで終わる（切り替えない。通知しない）。
- 2-6 (A) があれば、4.2.4 の規則で、追記する行の下書きを作っておいてよい。

**手順3 作業する場所を用意する**

| CUR | 確かめること | すること |
|---|---|---|
| `HEAD`（detached） | — | 通知N1（理由：detached HEAD）を送って終わる |
| `master` | コマンド7の出力に、未マージの行（行頭の2文字に `U` がある、または `AA`・`DD`）がある | 通知N1（理由：マージやcherry-pickの途中）を送って終わる |
| `master` | コマンド8の出力に変更がある | 旧手順1と同じ。中身を確かめ、`.state.json` と進捗ファイルとして矛盾がなければ、今回の分に含める。矛盾があれば、通知N5を送って終わる |
| `master` | 上のどちらでもない（docs/progress 以外に変更があっても構わない） | 手順4へ（コミットは docs/progress だけなので混ざらない） |
| ブランチ B | コマンド7の出力が空でない | 通知N1（理由：未コミットの変更がある）を送って終わる |
| ブランチ B | コマンド7の出力が空 | コマンド10で B を記録し、コマンド12を実行する。失敗したら、コマンド11で記録を消し、通知N1（理由：masterに切り替えられない、gitのメッセージの要約）を送って終わる。成功したら手順4へ |

**手順4 進捗ログを書き、masterにコミットする（基準は常に `master`）**
- 4-1 `docs/progress/.state.json` と `current_file` を、Readで読み直す（切り替えた後は中身もmtimeも変わっているため、Edit・Writeの前に読み直す）。切り替えた場合は、手順2-1の内容と同じことを確かめる。違えば通知N5を送り、手順5へ。
- 4-2 (A) があれば、4.2.4 の規則で日次ログに追記し、まとめを作り直す（旧4c）。
- 4-3 コミットする前に一度だけ、`.state.json` の `last_commit` を、コマンド9の出力（この実行でコミットする前のmasterの先端）にする。この実行で2件コミットする場合も、値は変えない。
- 4-4 (A) があれば、1件コミットする（件名は4.2.6）。
- 4-5 (B)・(C) は、旧7b・7cのとおりに行う（中身は変えない）。7cの通知の記録だけをコミットする場合の件名は、4.2.6 のとおりにする。
- 4-6 コミットの形：コマンド14で、触ったファイルを追加する。続けてコマンド16でコミットする。**末尾には必ず `-- docs/progress/` を付ける。**

**手順5 元のブランチに戻す（手順3で切り替えたときだけ。手順4でエラーになったときも、ここを行う）**
- 5-1 コマンド8の出力が空であることを確かめる。空でなければ、戻らずに通知N3（理由：進捗ログの変更がコミットされずに残っている）を送って終わる（記録は消さない）。
- 5-2 コマンド13を実行する。失敗したら、通知N3（gitのメッセージの要約）を送って終わる（記録は消さない）。並行のセッションの変更（docs/progress 以外）は、gitが元のブランチへ持ち帰る。持ち帰れない場合は、gitが止まる。
- 5-3 コマンド2の出力が B であることを確かめ、コマンド11で記録を消す。B でなければ、通知N3を送って終わる（記録は消さない）。

#### 4.2.4 日次ログの書き方

- 載せるのは、手順2-4の「載せるコミット」だけ。タスク自身のコミットは書かない。
- 1件は、first-parentの1行に当たる。
  - ふつうのコミット：旧4bと同じ（原則として1コミット1行、件名をもとに簡潔な日本語で書く。ほぼ同じ内容の連続したコミットは、1行にまとめてよい）。
  - merge：
    - 親の行：GitHubのPRのマージ（件名が「Merge pull request #NN …」）は「PR #NNをmerge（<内容の要約>、Nコミット、MM-DD〜MM-DD）」と書く。`git pull` の取り込み（「Merge branch 'master' of …」）は「GitHubのmasterを取り込み（PR #NN を含む、Nコミット）」と書く。それ以外のmergeは「<ブランチ名>をmerge（<要約>）」と書く。
    - 子の行（2文字下げた箇条書き）：中身のコミット（mergeとタスク自身のコミットを除く）を、原則として1コミット1行で書き、行末に `（MM-DD）` を付ける。ほぼ同じ内容の連続したコミットは、1行にまとめてよい。
- 見出しの日付：コミット（mergeは親の行）のAuthor Date（`%ad`）を d、日次ログの末尾の見出しの日付を L とする。
  - 見出しが無い、または d > L：末尾に `### d` を足し、その下に書く。
  - d = L：新しい見出しは作らない。末尾の見出しの下の、最後の行に続けて書く。
  - d < L（cherry-pick、rebase、fast-forwardで古い日付のコミットが入った場合）：末尾の見出し（L）の下に書き、行末に `（MM-DDのコミット）` を添える。
  - こうすると、見出しは日付順に並び、同じ日付の見出しは2つできない。
- 既存の行は書き換えない（追記のみ。旧4bのまま）。

例（PR #26 を今の規則で書いた場合。中身9件のうち3件だけを示す）：

```markdown
### 2026-10-19
- PR #26をmerge（溝の自動追跡 issue #25：trackGroove・grooveTrack_1cycle.mの実装、評価1回目で合格、振り返り。9コミット、10-12〜10-19）
  - issue #25の受け渡しフォルダを作成（10-12）
  - 写真1枚の範囲で溝を自動追跡する`trackGroove`と`grooveTrack_1cycle.m`を実装（10-13）
  - issue #25の受け渡しフォルダを`docs/issues/closed/`へ移動（10-19）
```

#### 4.2.5 通知の文（PushNotification。200字以内、日本語、1行）

| 記号 | 場面 | 文（案） |
|---|---|---|
| N1 | 持ち越し | 「進捗ログ自動更新: <理由>ため、今回は見送りました（チェックアウト中: <CUR>）。」。その日に(B)か(C)に当たる場合は、「次回の進捗報告・打ち合わせ予定日はいつですか？」を続ける |
| N2 | 前回の中断 | 「進捗ログ自動更新: 前回の実行が途中で止まり、チェックアウトがmasterのままです（元のブランチ: <R>）。確かめて戻したら git config --unset progress-report.return-branch を実行してください。」 |
| N3 | 戻れない | 「進捗ログ自動更新: masterに切り替えた後、元のブランチ <B> に戻れませんでした（<理由>）。チェックアウトはmasterのままです。確認をお願いします。」 |
| N4 | `last_commit` の異常 | 「進捗ログ自動更新: last_commit（<先頭7桁>）がmasterのfirst-parentの履歴に無いため、更新を止めました。確認をお願いします。」 |
| N5 | その他の異常 | 旧注意事項の文のまま（「進捗ログ自動更新でエラーが発生しました。確認をお願いします: (エラー内容)」） |
| — | 次回予定日の質問 | 旧7b・7cの文のまま |

N1は、作業ツリーが汚れている間、やることがある日ごとに届く（9章のR8）。

#### 4.2.6 コミットの件名と本文

- 日次ログ：「進捗ログ自動更新（<最後に追記した見出しの日付>分）」
- 通知の記録だけ：「進捗ログ自動更新（<TODAY>、通知の記録）」
- 期間の区切り：「進捗期間を区切り、新しい期間ファイルを開始（<TODAY>）」（旧のまま）
- 本文：旧の文（「深夜バッチ（scheduled task: progress-report-daily）による自動commit。docs/git-rules.mdの自動commit例外規定に基づく。」）に、「masterに直接コミット（チェックアウト中: <CUR>）。」を足す。末尾は `Co-Authored-By:`。
- 件名の先頭の2つの形は、タスク自身のコミットの見分けに使う。この形を変えない。

### 4.3 許可ルール

メインのチェックアウトの `.claude/settings.local.json` の `permissions.allow` に、次を足す（反映はメイン）。BashとPowerShellの両方に足す。denyは足さない（ふだんの `git switch -c` などを止めないため）。

| ルール（`Bash(…)` と `PowerShell(…)` の両方） | 一致させるコマンド（4.2.2の番号） | 種類 | 既存か |
|---|---|---|---|
| `git status *` | 7、8 | 読み | 新規 |
| `git show master:docs/progress/*` | 3 | 読み | 新規 |
| `git merge-base *` | 4 | 読み（merge-baseに書き込みの形は無い） | 新規 |
| `git config --get --default none progress-report.return-branch` | 1 | 読み | 新規（Bashは既存の `git config *` でも一致する） |
| `git config progress-report.return-branch *` | 10 | 書き（このキーだけ） | 新規（同上） |
| `git config --unset progress-report.return-branch` | 11 | 書き | 新規（同上） |
| `git switch master` | 12 | 書き（完全一致） | 新規 |
| `git switch -` | 13 | 書き（完全一致） | 新規 |
| `git rev-parse *` | 2、9 | 読み | 既存 |
| `git log *` | 5、6 | 読み | 既存（`--pretty=format:"…\|…"` の形は今も毎晩一致している） |
| `git add docs/progress/*`・`git mv docs/progress/*`・`git commit -m *` | 14〜16 | 書き | 既存（`-- docs/progress/` は `*` の中） |

- 読み取りのコマンドには、多少形が崩れても止まらないように、広めのワイルドカードを使う。書き込みのコマンドは、完全一致かキーを固定した形にする。
- 反映の順番：(1) ルールを足す、(2) プロンプトを差し替える。逆にすると、その間の実行が、新しいコマンドの承認待ちで止まる。
- 実行中に承認を求められた場合、「always allow」は選ばない（タスクごとの「Always allowed」に保存され、ルールの置き場所が2つになるため）。一度だけ許可して、ルールを `settings.local.json` に足す。
- 既存の広い `Bash(git config *)` は今回は触らない（狭める場合は、別のissueにする）。

### 4.4 ドキュメントの変更の方針

`docs/rules/communication.md` に従い、日本語で、結論を先に簡潔に書く。経緯は書きすぎず、issue番号を添える。

- **`CLAUDE.md`（進捗レポートの項目）**
  - 「gitコミット履歴を元に追記する」を、「**masterの**コミット履歴を元に追記し、**masterに**コミットする」に変える。作業ブランチをチェックアウト中なら、追跡されているファイルに未コミットの変更が無いときだけ、一時的にmasterへ切り替えて戻す。変更があれば、その日は見送って通知する（issue #27）。この内容を1〜2文で書く。
  - 「進捗ログの最新は常にmasterにある（作業ブランチの `docs/progress/` は古いことがある）」を1文で足す。
  - 次回予定日を手で更新する指示に、「この変更はmasterをチェックアウトしているときに行う。作業ブランチやworktreeにいるときは自分では変えず、ユーザーにその旨を伝える」を足す（Q6。決定に合わせる）。
- **`docs/git-rules.md`**
  - 冒頭の「例外」の段落：コミットは常に `master` に対して行うこと、そのためにメインのチェックアウトを一時的に `master` に切り替えて戻すことがあること（追跡されているファイルに未コミットの変更があるときは切り替えない）を足す。日付とissue #27も添える。
  - 同じ段落か「ブランチ運用」に、「ローカルの `master` には進捗ログのコミットが入る。`master` をrebase・resetしない（`git pull --rebase` を含む。`last_commit` がたどれなくなり、タスクが止まる）」を足す。
  - 「worktreeでの並行作業」の「ブランチ」の項に、「worktreeで `master` をチェックアウトしない（進捗ログのタスクがmasterに切り替えられなくなる）」を足す。
- **`docs/staged-development.md`**
  - 8章「進捗ログの自動コミット」を書き換える。タスクは常にmasterにコミットする（issue #27）。作業ブランチをチェックアウトしていると、必要な日だけ一時的にmasterへ切り替えて戻す。作業ブランチに進捗ログのコミットは入らない。未コミットの変更を残したまま夜を越すと、その日は見送りになり通知が来る。MATLABのエディタで未保存の変更を残さない（切り替えでファイルが一時的に変わるため）。「変えるまでの注意」という書き方は外す。
  - 5.1「呼ぶ前」の `git merge master` の項に、「（進捗ログのコミットだけなら、取り込まなくてよい）」を足す。
- ほかに同じ趣旨の記述が無いことを確かめた（`CLAUDE.md`・`README.md`・`docs/*.md`・`docs/rules/*.md`・`.claude/agents/*.md` を `進捗|progress` で検索した。該当は上の3ファイルだけ）。`docs/issues/closed/25-groove-tracking/` は記録なので変えない。

### 4.5 新しく作るファイルと、変えるファイル

| ファイル | 作る人 | 内容 |
|---|---|---|
| `docs/issues/27-progress-log-master/skill-after.md`（新規） | implementer | 変更後のプロンプトの全文（frontmatterなし） |
| `docs/issues/27-progress-log-master/permission-rules-add.json`（新規） | implementer | 足すallowルールの配列（BashとPowerShell）。メインの反映と予行の設定の両方が、このファイルを使う |
| `docs/issues/27-progress-log-master/impl-report-1.md`（新規） | implementer | 4.3の表（コマンドの形とルールの対応）、旧との差分の要約、自己確認の結果 |
| `CLAUDE.md`、`docs/git-rules.md`、`docs/staged-development.md`（変更） | implementer | 4.4 |
| `docs/issues/27-progress-log-master/criteria.md`、`rehearsal/`（新規） | evaluator A | 7.1 |
| `docs/issues/27-progress-log-master/eval-report-1.md`（新規） | evaluator B | 7.2 |
| `~/.claude/scheduled-tasks/progress-report-daily/SKILL.md`（リポジトリの外） | main | `update_scheduled_task` の `prompt` に `skill-after.md` を渡す。frontmatterは残る。descriptionは変えなくてよい（変えるなら「masterの」を足す程度） |
| メインのチェックアウトの `.claude/settings.local.json`（gitの管理外） | main | `permission-rules-add.json` の項目を足す |

触らないもの：`docs/progress/`（masterの進捗ログ。このPRで変えると、毎晩のコミットとぶつかる）、`.gitignore`、`.githooks/`、`src/`・`scripts/`・`test/`、`docs/issues/closed/`。

**分担（依頼文の想定を確定する）**：上の表のとおりにする。プロンプトの全文は implementer が `skill-after.md` に書く。許可ルールは impl-report の表に加えて、機械で読める `permission-rules-add.json` にも書く（予行の設定とメインの反映で、同じものを使うため）。evaluator A の定義では、書いてよい場所に `rehearsal/` が入っていない。そのため、メインが依頼文で明示的に許可する（7章）。

### 4.6 互換性

- `.state.json` の項目は変えない（新しい項目は無い）。中断の記録は、リポジトリのファイルではなく `.git/config` のキー `progress-report.return-branch` に置く（worktreeと共有。ふだんは存在しない）。
- 既存の日次ログは変えない。Q1を(a)にすると、これからはタスク自身のコミットの行が載らなくなる（過去の行はそのまま残る）。
- 最初の実行：今の `last_commit`（`26c6efd`）は、masterのfirst-parentの鎖の上にある（付録A）。`246b850`（タスク自身のコミット）は除かれ、`ba9077d` が載る。
- 元に戻す方法：`skill-before.md` を `update_scheduled_task` に渡す。足したルールは残しておいても害はない。`git config --unset progress-report.return-branch` で記録を消す。

## 5. 実装の手順（implementer）

1. **`skill-after.md` を書く**：`skill-before.md` を土台に、4.2のとおりに書く。1行目だけに絶対パスを書く。変えない部分の文言は残す。
2. **許可ルールを書く**：`permission-rules-add.json`（4.3の新規の行を、BashとPowerShellそれぞれの文字列で並べた配列）と、impl-reportの対応表（4.2.2のコマンドごとに、一致するルール）を書く。
3. **ドキュメントを直す**：4.4のとおりに直す。
4. **自己確認**（実行してよいのは読み取りのコマンドだけ）：
   - `skill-after.md` に出てくる `git …` をすべて抜き出す。それぞれが、4.3のルールに2.2の照合の規則で一致することを、表で確かめる。
   - 次のものが無いことを確かめる：`&&`・`;`（コマンドの中）、`2>&1`、`-C`、`git switch` のほかの形、`git checkout`、`git stash`、`git reset`。1行目のほかに絶対パスが無いことも確かめる。
   - 読み取りのコマンド1・3・4・5・6を、worktreeで実際に実行し、付録Aと同じ形の出力になることを確かめる（refは共有なので、masterを読める）。**書き込みのコマンド（10〜16）は実行しない。**
   - 通知の文が200字以内であることを確かめる。
5. **`impl-report-1.md` を書く**：旧との差分の要約、対応表、自己確認の結果、計画との違いを書く。

してはいけないこと：本物の `SKILL.md` や `settings.local.json` の編集、`git switch`・`git config` の書き込み・`git commit`、`docs/progress/` の編集、予行の実行（評価の段階で行う）。正式なデータ（`experiments/`）はこのissueには無い。

## 6. テストの方針

- MATLABのコードは変えないので、unitテストは書かない（`runAllTests` は対象外）。
- 実装担当の確かめは、5章の手順4（静的な対応表と、読み取りのコマンドの実行）だけにする。動作の確かめ（場面ごとの予行）は、実装と独立させるため、評価担当が作って行う（7章）。

## 7. 評価担当への申し送り

### 7.1 評価基準（evaluator A）：`criteria.md` と `rehearsal/`

メインは依頼文で、evaluator A に `docs/issues/27-progress-log-master/rehearsal/` への書き込みを許可する。evaluator B には、砂場（`temp/rehearsal-27/` 以下のclone）の中でのgitの書き込みと、`claude -p` の実行を許可する。どちらも、プロジェクトのリポジトリそのもののブランチやコミットには触れない。

**予行の仕組み（`rehearsal/` のbashスクリプト。名前と分け方はevaluator Aが決める）**

- 砂場：worktreeの `temp/rehearsal-27/<場面>/`（gitの管理外）。場面ごとに、`git clone --no-hardlinks --branch master <worktreeのパス> <砂場>` で作る（共有のチェックアウトを直接指すと、隔離の仕組みで拒まれる場合があるため、worktreeから作る）。作ったら `git remote remove origin` を実行する（pushの経路を断つ）。
- 砂場の許可設定：`<砂場>/.claude/settings.local.json`（cloneの `.gitignore` で無視される）。中身は、メインのチェックアウトの今の許可ルールに `permission-rules-add.json` を足したもの。`Write`・`Edit` のパスは、砂場の `docs/progress/**` に書き換える。**`PushNotification` は許可しない**（通知を本当に送らないため。呼ぼうとすれば拒否として記録に残り、送るはずの文が分かる）。
- プロンプト：`skill-after.md` の1行目だけを砂場のパスに差し替え、先頭に「（予行）PushNotificationは使わず、送るはずだった文を、最後の応答に『NOTIFY: <文>』の形で書くこと」を足す。**差し替えた後に、本物のリポジトリのパスが残っていたら、実行せずに止める。**
- 実行：砂場をカレントディレクトリにして `claude -p` で実行する。`--dangerously-skip-permissions`・`--allowedTools` は付けない（許可は砂場の設定だけから来るようにし、本番の照合を再現するため）。出力は `--output-format stream-json --verbose` でファイルに残す。
- 仕組みの確認（S0）：許可していないコマンド（例：`git switch -c x`）を頼むだけのプロンプトを流し、拒否として記録されること（`permission_denials` など）を先に確かめる。ヘッドレスで拒否が自動になることは、この確認を前提にしている。
- 実行の前後の写し：HEADのブランチ、`git for-each-ref`、`git status --porcelain`、`git diff --cached --name-only`、`git config --get --default none progress-report.return-branch`、`git reflog HEAD` の件数、masterの `.state.json`。

**自動で確かめる項目（場面ごとに、期待に合わせて適用する）**

| 記号 | 項目 |
|---|---|
| C1 | 実行の後のHEADのブランチが、実行の前と同じ |
| C2 | 変わったrefは master だけ（変えない場面では、すべて同じ） |
| C3 | masterに増えたコミットの数が期待どおり。どのコミットも `docs/progress/` だけを変え、件名がタスク自身のコミットの形 |
| C4 | masterの `.state.json` の `last_commit` が、最初の新しいコミットの第1親と一致し、first-parentの鎖の上にある |
| C5 | `git status --porcelain` と `git diff --cached --name-only` が、実行の前と同じ |
| C6 | `progress-report.return-branch` が無い（S12だけは残る） |
| C7 | 拒否された呼び出しが、PushNotificationのほかに無い |
| C8 | 通知（NOTIFY、またはPushNotificationの拒否の入力）が、期待どおりにある・無い。文の種類（N1〜N5）が合う |
| C9 | 切り替えないはずの場面で、`git reflog HEAD` の件数が変わらない |
| C10 | （目で見る）日次ログの見出しと行が4.2.4の規則どおり。既存の行が変わっていない |

**場面（必須はS0〜S14。S11b・S12bを含めて17場面。S15は任意）**

| 場面 | 準備 | 期待 |
|---|---|---|
| S0 | 仕組みの確認（上） | 拒否が記録される |
| S1 | master、作業ツリーはきれい、載せるコミットが1件 | masterに1件増える。C1〜C7、C10 |
| S2 | 作業ブランチ `claude/test`、きれい、masterに載せるコミットが1件 | masterに1件増え、ブランチは変わらず、HEADは `claude/test` に戻る。記録は無い。コミットの本文に `claude/test`。C1〜C7、C10（**2回実行する**） |
| S3 | 作業ブランチ、追跡されているファイルに未ステージの変更（もう1回は、ステージ済みの変更で） | 何も変わらない。N1（未コミットの変更）。C9 |
| S4 | 作業ブランチ、追跡されていないファイル `notes.txt` だけ | S2と同じ。`notes.txt` は残り、追跡されていないまま（Q4(a)の場合） |
| S5 | detached HEAD | 何も変わらない。N1（detached）。C9 |
| S6 | 作業ブランチ、きれい、masterを砂場の別のworktreeでチェックアウト | 何も変わらない（記録も消えている）。N1（切り替えられない） |
| S7 | master、`README.md` をステージ済み、別の追跡されているファイルを未ステージで変更、載せるコミットが1件 | 新しいコミットは docs/progress だけ。`README.md` はステージ済みのまま、もう1つは変更されたまま（Q3(a)の場合） |
| S8 | 作業ブランチ、きれい、`next_report_date` ≦ TODAY、載せるコミットが1件 | masterに2件（日次ログ、期間の区切り）。`git mv` の改名と新しいファイルが入る。HEADが戻る。次回予定日の質問が通知される（**2回実行する**） |
| S9 | master、過去の日付（TODAY−5〜−3）の3件を持つブランチを、TODAY−1の日付で `--no-ff` マージする（件名「Merge pull request #99 from MiwaHiroki/claude/feat」）。その後に、Author DateがTODAY−4のコミット（cherry-pickの代わり）。末尾の見出しはTODAY−2 | 見出しは `### TODAY−1` の1つだけ。PRの親の行、子の3行（元の日付つき）、古いコミットの行に「（MM-DDのコミット）」。C10 |
| S10 | master、末尾の見出しがTODAY、TODAYの日付のコミットが1件 | `### TODAY` は1つのまま、その下に続けて書く。C10 |
| S11 | `last_commit` を、masterに入っていない側のブランチのコミットにする | 何も変わらない。N4。C9 |
| S11b | `last_commit` を、masterの祖先だがfirst-parentの鎖に無いコミット（マージされたブランチの先端）にする | 何も変わらない。N4。C9 |
| S12 | master、`progress-report.return-branch` に `claude/test` が残っている | 何も変わらない（記録も残る）。N2 |
| S12b | `claude/test` で、記録に `claude/test` が残っている、載せるコミットが1件 | 記録を消して、S2と同じに進む |
| S13 | 作業ブランチ、きれい。masterの新しいコミットはタスク自身のコミットだけ。`next_report_date` は未来の日付 | 何もしない。切り替えない（C9）、通知なし（Q1(a)の場合） |
| S14 | 作業ブランチで、masterでは追跡されているファイルXを削除してコミットし、同じ名前の追跡されていないXを置く | `git switch master` が失敗し、何も変わらない。記録も消えている。N1 |
| S15（任意） | master、「Merge branch 'master' of https://github.com/…」の形のmergeの第2親の側に、PRのmergeがある | 「GitHubのmasterを取り込み（PR #NN を含む…）」と子の行 |

日付は、準備のスクリプトの中で `date +%F` を基準に作る（`GIT_AUTHOR_DATE`・`GIT_COMMITTER_DATE` を使う）。準備と実行は同じ日に行う。

**`criteria.md` のしきい値の分け方**
- 計画どおりかの確認：必須の17場面で、すべての自動の項目を満たすこと。S2・S8を2回実行し、2回とも満たすこと。
- 品質の基準：C7（拒否が無いこと。特に `git switch -`）、C5（作業ツリーとインデックスが変わらないこと）、C4（`last_commit` がmasterの鎖の上にあること）。どれか1つでも外れたら、不合格にする。
- 目で見る項目：S8・S9・S10の日次ログ（C10）と、通知の文。これは評価担当が判断する。ユーザーが見る必要はない（メインが自律的に進めるため）。

### 7.2 評価（evaluator B）

- 予行の全場面を実行し、項目ごとに結果を表にする。拒否がPushNotificationのほかに出た場合は、そのコマンドの形を書く（実装の差し戻しの材料になる）。
- 静的な確認（ii）：`skill-after.md` から抜き出したコマンドの形と、`permission-rules-add.json` と既存のルールとの対応を、独立に作り直して確かめる（implementerの表を写さない）。
- `experiments/` に作るデータは無い。正式な記録は `eval-report-1.md` に残す。予行のログは `temp/rehearsal-27/` に残す（ユーザーが見られる）。
- MATLABは使わない。`runAllTests` は対象外。

### 7.3 メインがすること（評価に合格した後）

1. **反映**：`permission-rules-add.json` をメインのチェックアウトの `settings.local.json` に足す → `update_scheduled_task` で `skill-after.md` を渡す → `SKILL.md` の本文の sha256 を `README.md` に控える。
2. **(iii) 本物の手動実行**
   - 前提：`git worktree list` で、メインのチェックアウトが `master` であることを確かめる。作業ブランチなら、今は行わない（並行のセッションの作業中に切り替えが起きるため）。ユーザーに「メインのチェックアウトのmasterに、進捗ログのコミットが1件増える」と伝えておく。
   - 前：`git rev-parse master`、`git show master:docs/progress/.state.json` を控える。
   - `run_scheduled_task` を実行する。
   - 後：`git log --oneline -3 master`、`git show --stat --format=%s master`（`docs/progress/` だけ）、`git worktree list`（masterのまま）、`git show master:docs/progress/.state.json`（`last_commit` が新しいコミットの第1親）、`git config --get --default none progress-report.return-branch`（`none`）を確かめる。タスクのセッションが承認待ちで止まっていないことも確かめる。
   - 期待：`ba9077d` などが `### 2026-10-22` の下に載る（`246b850` は載らない）。
   - 注意：masterでは、並行のセッションの未コミットの変更があっても続ける設計（Q3(a)）なので、(iii) は「持ち越して通知」の経路の確かめにはならない。その経路は、予行のS3と(iv)で確かめる。
3. **(iv) 作業ブランチでの本物の実行（メインのチェックアウトが空いたとき。ユーザーか、メインのチェックアウトのセッションが行う）**
   1. メインのチェックアウトで `git status --porcelain` が空であることを確かめ、`git switch -c claude/progress-check master` を実行する。
   2. やることがある状態にする（例：#27 のPRをマージして `git pull` した直後なら、そのmergeが載るコミットになる）。やることが無いと、何もせずに終わる（S13の経路）ので、切り替えの確かめにならない。
   3. **先に、持ち越しの経路を確かめる**：追跡されているファイル（例：`README.md`）に1行足し、コミットせずに `run_scheduled_task` を実行する。N1が届き、何も変わらないことを確かめたら、その変更を元に戻す。
   4. きれいな状態で `run_scheduled_task` を実行する。`git log --oneline -3 master`（1件増える）、`git log --oneline master..claude/progress-check`（空）、`git rev-parse --abbrev-ref HEAD`（`claude/progress-check`）、`git status --porcelain`（空）、記録（`none`）、`last_commit` を確かめる。MATLABでダイアログが出ていないかも見る。
   5. `git switch master`、`git branch -d claude/progress-check` で元に戻す。
   - (iv) を行う前に、ユーザーが作業ブランチにいる日の3時の実行で、自然に確かめられることもある。その場合は、翌朝に4の項目を確かめればよい。

## 8. 決定事項（旧：未決事項）

**2026-10-22、main が決定：Q1〜Q9 はすべて推奨どおり**（Q1 (a)、Q2 (a)、Q3 (a)、Q4 (a)、Q5 (a)、Q6 (a)、Q7 (a)、Q8 (a)（`claude -p` が使えなければ (b)）、Q9 4.5のとおり）。Q6 (a) で、作業ブランチやworktreeのセッションが次回予定日を伝えられたときは、`.state.json` を変えず、「masterをチェックアウトしているセッションで更新する必要がある」とユーザーに伝える。以下は検討の記録として残す。

**Q1. タスク自身のコミットを、日次ログに載せるか**
- 背景：`last_commit` はコミットの前のmasterの先端を指すので、次の実行では必ず前回のタスク自身のコミットが新しいコミットになる。今は、それを「進捗ログ自動更新（…分）」として毎日載せている（2.3の1）。
- (a) 載せない。「やること」にも数えない。何もしない日ができ、作業ブランチにいる間の切り替えは、必要な日だけになる。日次ログから、情報の無い行が消える。
- (b) 今のまま載せる。作業ブランチにいる間は、ほぼ毎日切り替える。案Bの利点がほとんど無くなる（案Aと同じになる）。
- 推奨：(a)。切り替えの回数を減らすことが、並行のセッションやMATLABへの影響を減らす最も効く手段で、スライドを作るときの情報も減らないため。

**Q2. PRのマージを、日次ログにどう書くか**
- (a) 親の1行と、中身の子の行（元の日付つき）。
- (b) 親の1行だけ（今の前例「PR #19をmerge（…）」と同じ長さ）。
- (c) first-parentを使わず、中身を平らに並べる（どのPRの中身かが分かりにくい。日付の扱いも難しい）。
- 推奨：(a)。issueのQ2(a)の決定により、作業ブランチの途中経過はマージの後にしか載らない。まとめを作り直すときの材料を残すため。

**Q3. masterをチェックアウト中に、docs/progress 以外に未コミットの変更（ステージ済みを含む）があるとき**
- 背景：issueのQ1(a)の「未コミットの変更があれば持ち越す」は、切り替えるときの話と読んだ（仮定）。
- (a) 続ける。`git commit … -- docs/progress/` で docs/progress だけをコミットする（ほかのステージは残る）。
- (b) 作業ブランチと同じく、持ち越して通知する。masterで作業したまま夜を越すと、進捗ログが止まる。
- 推奨：(a)。今もmasterでは変更があっても続けており、混ざる危険はパス指定で無くなるため。予行のS7・S8でパス指定が期待どおりに動かなければ、(b) に替える。

**Q4. 作業ブランチで、追跡されていないファイルだけがあるとき**
- (a) 切り替える（上書きになる場合は、gitが何も変えずに止まる）。
- (b) 持ち越す（消えないファイルが残っていると、ずっと持ち越しになる）。
- 推奨：(a)。

**Q5. 途中で止まったときの記録**
- (a) `git config progress-report.return-branch`（`.git/config` に書く）。
- (b) `temp/` に印のファイルを置く（Writeのルールが増える。`temp/` が無い環境では作る必要がある）。
- (c) 記録しない（masterに切り替えた後に止まると、元のブランチが分からない。次の実行でも気づけない）。
- 推奨：(a)。

**Q6. 次回予定日の手での更新（`CLAUDE.md` の指示）を、masterに限るか**
- 背景：作業ブランチやworktreeのセッションが `.state.json` を変えると、masterの状態と食い違い、マージのときにぶつかる。
- (a) masterをチェックアウトしているときだけ行う。そうでなければ、ユーザーに伝える。
- (b) 今のまま（どのセッションでも行う）。
- 推奨：(a)。

**Q7. 日中の追いつきの実行や手動の実行でも、切り替えるか**
- 背景：タスクは、スリープの後や手動では、ユーザーや並行のセッションが作業している時間に動く（2.2）。
- (a) 制限しない（追跡されているファイルがきれいかどうかだけで判断する）。
- (b) 0〜6時以外は、作業ブランチなら切り替えずに持ち越す（時刻を得るコマンドが増える。(iv) の手動の確かめもできなくなる）。
- 推奨：(a)。今は毎晩3時台に実行されていて、追いつきの実行はまれなため。問題が出たら(b)を足す。

**Q8. 予行の実行のしかた**
- (a) 砂場でヘッドレスの `claude -p` を、本番と同じ許可ルールで動かす（ロジックと許可の照合の両方を確かめられる）。
- (b) 評価担当が `skill-after.md` を読み、文字どおりに実行する（許可の照合は確かめられない）。
- 推奨：(a)。`claude -p` が使えない（入れ子の実行が許されないなど）場合は(b)にし、`git switch -` の照合は(iv)まで確かめられないことをリスクとして残す。

**Q9. 分担**
- 4.5のとおり（implementer：`skill-after.md`、`permission-rules-add.json`、ドキュメント、impl-report。evaluator A：`criteria.md`、`rehearsal/`。evaluator B：予行の実行。main：反映、(iii)・(iv)）。
- 推奨：このとおりにする。

## 9. リスク

| # | リスク | 対策・代わりの案 |
|---|---|---|
| R1 | `git switch -` がルール `git switch -` に一致せず、masterに切り替えた後で承認待ちになって止まる（最悪の場合） | 予行（S2）で拒否が出ないことを確かめる。一致しなければ `git switch @{-1}`（Bashツールだけ。完全一致のルール）に替えて、予行をやり直す。それも一致しなければ、作業ブランチのときは切り替えずに持ち越す（issueのQ1の(c)と同じ動き）ことにし、メインに相談する |
| R2 | 予定タスクのセッションに `settings.local.json` が効くことは、文書に明記されていない | 今のルールが毎晩効いている実績があるので、同じファイルに足す。読み取りとコミットの形は(iii)で、切り替えの形は(iv)か、最初の作業ブランチでの3時の実行で確かめる |
| R3 | 切り替えている間に、並行のセッションがファイルを変えたりコミットしたりする（特に日中の追いつきの実行で） | 切り替えるのは必要な日だけ（Q1(a)）。masterにいる時間を短くする（下書き）。戻すときに、ほかの変更はgitが持ち帰り、持ち帰れなければN3で知らせる。問題が出たらQ7(b) |
| R4 | MATLAB：開いているファイルやプロジェクトの定義ファイル（`resources/project/`）が一時的に変わり、エディタやプロジェクトが再読み込みの確認を出す。未保存の編集がある状態で「再読み込み」を選ぶと、編集が消える | `docs/staged-development.md` の8章に「夜はエディタの未保存の変更を残さない」を書く。切り替える日を減らす。(iv)でダイアログを見る |
| R5 | Windowsでファイルがロックされていると、`git switch` が途中で失敗するか、「Unlink of file … failed. Should I try again? (y/n)」で入力を待つ | まれ。翌朝に、チェックアウトと記録（N2）で気づける。安く防ぐ手段は無いので、記録だけ残す |
| R6 | `git commit … -- docs/progress/` が `git mv` の改名（S8）やほかのステージ（S7）で期待どおりに動かない | 予行で確かめる。だめなら、Q3を(b)にし、パス指定をやめて「インデックスに docs/progress 以外が無いこと」を確かめてからコミットする形に替える（`git diff --cached --name-only` とそのルールを足す） |
| R7 | LLMがプロンプトから外れる（引数なしの `git status`、`2>&1` を付ける、など） | 読み取りのルールを広めにする。コマンドの一覧を完全な形で書く。予行で拒否を見る |
| R8 | 作業ブランチで作業ツリーが汚れたままだと、やることがある日ごとにN1が届く | 気づける利点もあるので、まずはこのままにする。うるさければ、`git config` に通知した日を記録して間隔を空ける（続きのissue） |
| R9 | masterのrebase・reset（`git pull --rebase` を含む）で `last_commit` が鎖から外れる。masterを、masterを取り込んだブランチへfast-forwardした場合も同じ | N4で止まる（二重に追記はしない）。`docs/git-rules.md` に注意を書く。直し方は、`last_commit` を手でmasterのコミットに書き換える（今回の `ba9077d` と同じ） |
| R10 | ヘッドレスの予行（CLI 2.1.300）と、アプリの予定タスクの動きが違う | (iii)・(iv)で本物を確かめる |
| R11 | 予行の差し替えに失敗し、本物のリポジトリで動いてしまう | 実行の前に、本物のパスが残っていないことを確かめて止める。砂場の `Write`・`Edit` は砂場のパスだけにする。originを外す |
| R12 | ローカルのmasterには毎晩コミットが入るので、GitHubでPRをマージした後の `git pull` は、毎回mergeコミットを作る | 日次ログでは「GitHubのmasterを取り込み」として扱う（S15）。rebaseはしない（R9） |

## 10. 付録

MATLABは使っていない。以下は、worktreeから実行した読み取りのコマンドとその結果（2026-10-22）。

### A. 新しい手順の読み取りのコマンドを、今のmasterで実行した結果

```bash
git show master:docs/progress/.state.json
#  last_commit: 26c6efd4b12271314150a21715766e274245192e, next_report_date: null, next_report_date_last_asked: 2026-10-21
git merge-base 26c6efd4b12271314150a21715766e274245192e master
#  26c6efd4b12271314150a21715766e274245192e   （一致 → masterの祖先）
git log 26c6efd4b12271314150a21715766e274245192e..master --first-parent --date=short --pretty=format:"%H|%ad|%P|%s" --reverse
#  246b8506…|2026-10-22|26c6efd4…|進捗ログ自動更新（2026-10-21分）           ← 1行目の第1親 = last_commit（鎖の上）。タスク自身のコミットなので除く
#  ba9077da…|2026-10-22|246b8506…|進捗ログのlast_commitをmaster上のコミットに直し、案Dに取り残しの例を追記   ← 載せる
git config --get --default none progress-report.return-branch
#  none
git status --porcelain -- docs/progress/        # 出力なし、exit 0
git status --porcelain --untracked-files=no     # 出力なし、exit 0
```

### B. `last_commit` の2つの確かめ方が、過去の事故の形を捕まえること

```bash
git merge-base d4030e1f6ffb0f4afb35eaee718d5d989a01e81e master
#  32df69a…（d4030e1 と一致しない → 祖先でない → N4）
git merge-base 32df69a688c64e6f54e5458f9ecff12995fbef7e master
#  32df69a…（一致 → 祖先ではある）
git log 32df69a688c64e6f54e5458f9ecff12995fbef7e..master --first-parent --date=short --pretty=format:"%h|%ad|%P|%s" --reverse
#  b479770|2026-10-19|cd92072… 32df69a…|Merge pull request #26 …   ← 1行目の第1親 cd92072 ≠ 32df69a → 鎖に無い → N4
```

### C. 履歴の事実

```bash
git log master --first-parent --merges --date=short --pretty=format:"%h|%ad|%cd|%P|%s"
#  b479770 PR #26（10-19）、93bd2e3 PR #24（09-23）、d286241「Merge branch 'master' of https://github.com/MiwaHiroki/myResearch」（09-15）、
#  3672139 PR #19（09-02）、d25d3fb・83b77f7「Merge branch 'master' of …」、cd445e1・c242db8・4890434（ローカルのmerge）
git log master --first-parent --date=short --pretty=format:"%h|%ad|%cd|%s" -60   # Author Date と Commit Date が違うもの
#  26c6efd 10-21/10-22、dfe7e4e 10-21/10-22、5376e05 10-20/10-22（cherry-pick）、c628f72 08-27/09-01、e98e6fc 08-20/09-01
git log cd92072..32df69a --oneline | wc -l              # 21（PR #26 の中身）
git log --no-merges cd92072..32df69a --oneline | wc -l  # 16（うちタスク自身のコミットが7件 → 載せるのは9件）
git config --get pull.rebase                            # false
git --version                                           # git version 2.55.0.windows.2
```

### D. 許可設定とフック

- メインのチェックアウトの `.claude/settings.local.json` と、worktreeの写しは同じ（`diff` で差分なし）。
- `.githooks/post-checkout` の該当部分：`[ "$git_dir" = "$common_dir" ] && exit 0`（メインのチェックアウトでは何もしない）。
- 予定タスクのフォルダ（`~/.claude/scheduled-tasks/progress-report-daily/`）には `SKILL.md`（11204バイト）だけがある。
