---
name: progress-report-daily
description: 毎日深夜3時にgitコミット履歴を読み、docs/progress/配下の進捗ログを自動更新する
---

対象リポジトリ: `C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\myResearch`（このタスクのセッションのカレントディレクトリは常にこのリポジトリのルートである。gitコマンドは`-C`オプションなしでそのまま実行してよい）。
このタスクは、`docs/progress/` 配下の進捗ログを、gitのコミット履歴から自動的に追記・更新するための日次バッチである。ユーザーは2週間に一度これを見てGoogleスライドの進捗報告資料を作る。以下の手順を **順番に、省略せず** 実行すること。会話の記憶はゼロなので、このプロンプトの説明だけで完結させること。

## 前提知識
- 状態ファイルは `docs/progress/.state.json`。フィールド: `current_file`（`docs/progress/`直下の現在の期間ファイル名）、`period_start`（その期間の開始日 `YYYY-MM-DD`）、`next_report_date`（次回の進捗報告・打ち合わせ予定日 `YYYY-MM-DD` またはnull）、`last_commit`（前回処理済みの最新コミットSHA）、`next_report_date_last_asked`（直近でPush通知した日付 `YYYY-MM-DD` またはnull）。
- **ファイル命名規則**: `current_file`は常に`<period_start(YYYY-MMDD形式)>_<X>.md`という`YYYY-MMDD_MMDD`パターンに従う。`X`は、`next_report_date`が設定されていればその`MMDD形式`（例: `1006`）、`next_report_date`が`null`の間は**文字列`MMDD`そのまま**（プレースホルダー、実際の日付ではなく「未定」を示すリテラル文字列）とする。例: 開始日2026-08-10で次回予定日未定なら`2026-0810_MMDD.md`、予定日が2026-10-06に決まれば`2026-0810_1006.md`。この命名は`next_report_date`の値と常に一致していなければならない。このタスクの実行中に`next_report_date`を変更する手順（7b）では、ファイル名もそれに追従させる。
- 各期間ファイルは以下の構成:
  ```markdown
  # 進捗ログ（<period_start> 〜 <next_report_dateがあれば「<next_report_date>予定」、無ければ空欄>）

  ## まとめ
  - (テーマ単位の箇条書き。期間全体を通じた大まかな要約)

  ## 日次ログ

  ### YYYY-MM-DD
  - (その日のコミットの要約、原則1コミット1行)
  ```
- `docs/git-rules.md`に「進捗ログ自動更新に限り、このスケジュールタスクによる自動commitを許可する」という例外規定が明記済み。それ以外のファイルは絶対に無断でcommitしないこと（対象はこのタスクで触るファイルのみ）。push は絶対にしないこと。
- **このタスクは人が承認できない深夜に自動実行される。** 使うツール・コマンドは、事前にユーザーが許可した範囲（`git log`/`git rev-parse`/`git add`/`git commit`/`git mv`と、`docs/progress/`配下へのファイル読み書き、`PushNotification`）に厳密に収め、それ以外の操作が必要になった場合は実行せず、何もせずに終了して次回に持ち越すこと（無理に別の方法で代替しない）。
- **gitの書き込み系コマンドは、許可ルールに一致する決まった形でのみ実行すること**（形が崩れると承認待ちで深夜に止まる）:
  - `git add docs/progress/<ファイル> [docs/progress/<ファイル> ...]`
  - `git mv docs/progress/<旧> docs/progress/<新>`
  - `git commit -m "<タイトル>" [-m "<本文>" ...]` — `commit`の直後は必ず`-m`とし、`-q`・`--quiet`・`-a`等のオプションは付けない。
  - これらは`;`・`&&`・`|`で他のコマンド（`echo`・`git status`・`git log`等）とつなげず、**1回のツール呼び出しにつき1コマンド**で実行する。

## 手順

1. `docs/progress/.state.json` を読む。作業ツリーに未commitの変更が残っていたら（前回実行が途中で中断された可能性がある）、まずその内容を確認し、`.state.json`や進捗ファイルの内容として矛盾がなければ、そのまま今回の分としてcommitに含めてよい（作り直す必要はない）。
2. `git log <last_commit>..HEAD --date=short --pretty=format:"%H|%ad|%s" --reverse` で未処理のコミットを取得する（`last_commit`がnullの場合はその旨だけ記録し、既存の`current_file`の末尾のコミットSHAをおおよその基準にするか、安全のため何もせず処理を中断してユーザーに報告する）。
3. 新規コミットが0件なら、手順4〜6はスキップして手順7（次回予定日の確認・通知判定）だけ行い、その後終了する。
4. 新規コミットが1件以上ある場合:
   a. コミットをAuthor Date（`%ad`）ごとにグルーピングする。
   b. `docs/progress/<current_file>` を読み、「## 日次ログ」セクションの末尾に、日付ごとに `### YYYY-MM-DD` の見出しを追加し、その日のコミットを箇条書きで追記する。**原則1コミット1行、コミットのsubjectをベースに簡潔な日本語で記載する**（生ログが基本）。ただし、`Merge pull request`や`Merge branch`のような統合コミットは「PR #NNをmerge（内容の要約）」のように1行に短く要約してよい。また、内容がほぼ同一とみなせる連続コミット（例:微修正の繰り返し）に限り1行にまとめてよい（例:「〜を微修正（3コミット）」）。**既存の日次ログの内容は絶対に書き換えない**（追記のみ、履歴として不変）。
   c. 追記後の「## 日次ログ」全体を読み直し、「## まとめ」セクションをテーマ単位の箇条書きで**再生成して丸ごと置き換える**（期間全体のダイジェスト。スライド作成時に一番参照される部分なので、簡潔かつ内容が分かるように）。
5. `docs/progress/.state.json` の `last_commit` を、その時点のHEADのフルSHA（`git rev-parse HEAD`）に更新する。
6. 手順4を実行した場合は、変更した進捗ファイルと`.state.json`のみを対象に `git add docs/progress/<current_file> docs/progress/.state.json` した上で、1つのcommitを作る（**push はしない**）。コミットメッセージは1行で渡せる形にする（例: `git commit -m "進捗ログ自動更新（YYYY-MM-DD分） 深夜バッチ（scheduled task: progress-report-daily）による自動commit。docs/git-rules.mdの自動commit例外規定に基づく。 Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"`のように、タイトル・本文・Co-Authored-Byを含む1つの`-m`文字列にまとめる。改行を入れたい場合は`-m`を複数回指定してよい）。
7. 次回予定日の確認・通知判定（コミットの有無に関わらず毎回実施。**b, cは`next_report_date`の値によって排他的に分岐する**）:
   a. 今日の日付を `TODAY` とする。
   b. `.state.json`の`next_report_date`が設定されており（nullでない）、かつ `TODAY >= next_report_date` の場合（期間の区切りに到達）:
      - 目標のファイル名を `docs/progress/<period_start(YYYY-MMDD形式)>_<TODAYのMMDD>.md` とする（`next_report_date`ではなく**実際に処理した日であるTODAY**を使う。両者が同じ日なら現在のファイル名と一致するはずである）。
      - 現在の`current_file`のパスがこの目標ファイル名と異なる場合のみ、`git mv docs/progress/<current_file> <目標ファイル名>` でリネームする（一致していれば何もしない）。
      - リネーム後（またはリネーム不要だった場合はそのまま）、そのファイルの1行目の見出しを `# 進捗ログ（<period_start> 〜 <TODAY>）`（「予定」は付けない。実績の終了日のため）に更新する。
      - 新しい期間ファイル `docs/progress/<TODAYのYYYY-MMDD形式>_MMDD.md`（`next_report_date`はまだ`null`なので、末尾は実日付ではなくプレースホルダー文字列`MMDD`のまま）を、上記のテンプレート（`period_start`はTODAY、見出しは`# 進捗ログ（<TODAY> 〜 ）`、まとめ欄は空の箇条書き1行「(次回追記待ち)」、日次ログ欄は見出しのみ）で新規作成する。
      - `.state.json`の`current_file`を新しいファイル名（`<TODAYのYYYY-MMDD形式>_MMDD.md`）に、`period_start`をTODAYに更新し、`next_report_date`を`null`に戻す。
      - 上記で変更・作成・リネームしたファイルをまとめて`git add`し、「進捗期間を区切り、新しい期間ファイルを開始（YYYY-MM-DD）」という1コミットを作る（手順6と同じ`-m`の書き方）。
      - `next_report_date`が`null`に戻ったので、続けて`PushNotification`ツールで「進捗レポート: 次回の進捗報告・打ち合わせ予定日はいつですか？決まったら教えてください。」（200字以内、日本語、1行）を送信する（`next_report_date_last_asked`の間隔チェックは無視し、今回は必ず送る）。`.state.json`の`next_report_date_last_asked`をTODAYに更新し、変更をcommitに含める。
      - **この場合は次のcを実行しない。**
   c. **bに該当しない場合**（＝`next_report_date`が`null`、または設定済みだが`TODAY`がまだ`next_report_date`未満）のうち、**`next_report_date`が`null`であり、かつ（`next_report_date_last_asked`が`null`、または`TODAY`との差が3日以上）**の場合のみ:
      - `PushNotification`ツールで「進捗レポート: 次回の進捗報告・打ち合わせ予定日はいつですか？決まったら教えてください。」（200字以内、日本語、1行）を送信する。
      - `.state.json`の`next_report_date_last_asked`をTODAYに更新し、変更をcommitする（手順6と同様、1コミットにまとめてよい）。
      - **`next_report_date`が既に設定済み（null でない）でTODAYがまだそれ未満の場合は、通知は送らない（何もしない）。** これが最も多いケースであることに注意。
   d. 上記b・cのいずれにも該当しない場合は何もしない。

## 注意事項
- 各git操作の前に必ず対象ファイルの現在の中身を読み、意図しない上書きをしていないか確認すること。
- 何らかの理由で手順が実行できない・状態ファイルが壊れている等の異常時は、無理に推測で書き換えず、`PushNotification`で「進捗ログ自動更新でエラーが発生しました。確認をお願いします: (エラー内容)」と通知し、ファイルは変更しないこと。
- 絶対にpushしないこと。`docs/progress/`以外のファイルを変更・commitしないこと。