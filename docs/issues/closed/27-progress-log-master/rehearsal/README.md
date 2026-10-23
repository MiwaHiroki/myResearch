- 段階: 評価基準（予行の仕組み）
- 作成者: evaluator
- 作成日: 2026-10-22
- 入力: issue #27、[`../README.md`](../README.md)（決定事項）、[`../plan.md`](../plan.md)（承認済み。7.1・7.2・9章）、[`../skill-before.md`](../skill-before.md)、メインの依頼文（モードA、1回目）
- 状態: 下書き

# 予行（issue #27）の手順

`skill-after.md` を、砂場（worktree の `temp/rehearsal-27/` に作る clone）でヘッドレスの `claude -p` に実行させ、場面ごとに前後の状態を比べて判定する（plan.md 7.1、Q8 (a)）。判定の項目としきい値は [`../criteria.md`](../criteria.md) にある。

**結論（2026-10-22 の仕組みの確認）**：(a) の予行は成り立つ。`claude -p` は砂場で動き、許可していないコマンドは承認待ちにならず拒否として記録された。`git switch -` は完全一致のルール `Bash(git switch -)` に一致した。詳しくは末尾の「仕組みの確認の結果」。

## ファイル

| ファイル | 中身 |
|---|---|
| `lib.sh` | 共通の変数と関数（場所、日付、砂場の安全の確かめ、前後の写し、`claude -p` の実行） |
| `setup.sh` | 場面を1つ準備する（clone、origin を外す、gitの状態を場面どおりにする、期待値を `scene.env` に書く） |
| `run.sh` | 許可設定とプロンプトを作り、`claude -p` を実行し、前後を写して `check.sh` を呼ぶ（`--dry-run` で実行の手前まで） |
| `check.sh` | 1回の結果を、自動の項目（R0・Rreal・C1〜C9）と C10 の補助で判定する |
| `run-all.sh` | 必須の場面をすべて順に行い、最後に `summarize.sh` を呼ぶ |
| `summarize.sh` | すべての回の判定を1つの表（Markdown）にまとめる |
| `s0-probe.sh` | S0（仕組みの確認）。許可の設定が効くか、拒否が記録されるか |
| `s0b-write-probe.sh` | S0b（Write・Edit のルールが砂場で効くか）。S0 で見つけたことの切り分け用 |
| `selftest.sh` | LLM を使わない自己確認（全場面の準備と、判定が正しい動きを通し誤った動きを落とすこと） |
| `manual.sh` | (b) の予行（評価担当が手で実行する）の前後の写しと判定 |
| `make-settings.js` | 砂場の `.claude/settings.local.json` を作る |
| `make-prompt.js` | `skill-after.md` から予行のプロンプトを作る（1行目の差し替え、注意書き、本物のパスが残っていないかの確認） |
| `parse-stream.js` | `stream-json` の出力から、呼び出し・拒否・通知・最後の応答を取り出す |
| `rules-check.js` | コマンドの形と、狭いルールの集まりとの照合（C7n と、静的な確認の補助） |
| `c10.js` | 日次ログの機械的な確かめ（C10 の補助） |
| `notify-patterns.json` | 通知の文の種類（N1〜N5・ASK）を見分ける語 |
| `task-rules-existing.json` | plan.md 2.1 の、タスクに関係する既存の許可ルール（C7n と静的な確認で使う） |

## 前提

- Git Bash、`node`、`claude` CLI（`C:\Users\owner\.local\bin\claude`。claude.ai でログイン済み）。MATLAB は使わない。
- 入力（実装の段階で implementer が作る）
  - `docs/issues/27-progress-log-master/skill-after.md`：frontmatter なし。**1行目だけ**に本物のリポジトリの絶対パスを書く（plan.md 4.2）。
  - `docs/issues/27-progress-log-master/permission-rules-add.json`：**`permissions.allow` に足す文字列の JSON 配列そのもの**（例：`["Bash(git status *)", "PowerShell(git status *)", …]`）。要素は `Bash(…)` か `PowerShell(…)` だけ。オブジェクト（`{"allow": […]}` など）は受け付けない。
- 準備と実行は同じ日に行う（日付は `date +%F` を基準に作る。`run.sh` は準備の日と違えば止まる）。
- 記録はすべて `temp/rehearsal-27/` に残る（gitの管理外。ユーザーも見られる）。砂場1つで約65MB。

## 準備：本番の許可設定の写し（base）

砂場の許可設定は「メインのチェックアウトの今の `.claude/settings.local.json`」に `permission-rules-add.json` を足したもの（plan.md 7.1）。その写しを `temp/rehearsal-27/_inputs/base-settings.local.json` に置く。

```bash
# メイン（または、メインが許可した評価担当）が1回だけ行う。読み取りとコピーだけ
mkdir -p temp/rehearsal-27/_inputs
cp "<メインのチェックアウト>/.claude/settings.local.json" temp/rehearsal-27/_inputs/base-settings.local.json
sha256sum temp/rehearsal-27/_inputs/base-settings.local.json
```

- **worktree の `.claude/settings.local.json` を base にしない。** 計画の後に項目が増えていて（`Bash(git add *)`・`Bash(git commit *)` など）、形の崩れが C7 で見えなくなる。広いルールがあると `run.sh` が `settings-report.txt` に「注意: 広いルールがある」と書く。C7n は base に関係なく、狭いルールで照合する。
- `make-settings.js` は base を次のように変える：`Write(…/docs/progress/**)`・`Edit(…/docs/progress/**)` を砂場の `docs/progress/**` に書き換える（ほかの Write・Edit は落とす）、`PushNotification` を allow から落として deny に入れる、`mcp__*` を落とす、`permissions` の allow・deny・ask・defaultMode のほかの項目を落とす。

## 手順（評価担当 B）

作業ディレクトリは worktree のルート。以下の `R=docs/issues/27-progress-log-master/rehearsal`、`I=docs/issues/27-progress-log-master` とする。

1. **自己確認（LLM を使わない。約3分）**
   ```bash
   bash $R/selftest.sh          # 「selftest: 失敗 0 件」になること
   ```
2. **仕組みの確認 S0 を、評価の日にもう一度（LLM 1回、約1分）**：CLI は自動で更新されるため。
   ```bash
   bash $R/s0-probe.sh 2        # 12 の操作のうち、6（either）を除くすべてが期待どおり
   ```
3. **入力の確かめ（LLM を使わない）**
   ```bash
   bash $R/setup.sh S2 1
   bash $R/run.sh S2 1 --dry-run --skill $I/skill-after.md --rules $I/permission-rules-add.json
   ```
   `prompt-report.txt`（1行目の前と後）、`settings-report.txt`（書き換え・落とした項目・広いルールの注意）、`temp/rehearsal-27/S2-1/.claude/settings.local.json` を見る。`--dry-run` の後も、同じ回でそのまま本番の実行ができる。
4. **全場面の実行（LLM 約20回。1時間以上）**：Bash ツールの `run_in_background` で実行する（1回の呼び出しの上限10分を超えるため）。
   ```bash
   bash $R/run-all.sh --skill $I/skill-after.md --rules $I/permission-rules-add.json
   ```
   - 1場面ずつ行う場合：`bash $R/setup.sh S1 1` の後に `bash $R/run.sh S1 1 --skill … --rules …`。S2・S8 は回 1 と 2 の2回。
   - 途中で止まったら、終わっていない場面だけを `--only "S9 S10"` で行う。S15（任意）は `--with-optional`。
5. **一覧**：`bash $R/summarize.sh`（`temp/rehearsal-27/summary-<日時>.md`）。
6. **静的な確認 (ii) の補助**：
   ```bash
   node $R/rules-check.js static $I/skill-after.md $I/permission-rules-add.json $R/task-rules-existing.json
   ```
   `skill-after.md` のバッククォートの中の `git …` を抜き出し、`<…>` を例の値にして、一致する Bash・PowerShell のルールを表にする。これは補助で、抜き出しの漏れがありうる。評価担当は `skill-after.md` を読んで自分で表を作り、この出力と突き合わせる（plan.md 7.2：implementer の表を写さない）。

## 結果の見方（`temp/rehearsal-27/<場面>-<回>.run/`）

| ファイル | 中身 |
|---|---|
| `check.md` | 判定の表、通知、拒否、新しいコミット、日次ログに追記された部分 |
| `check.tsv` | 判定（項目、種類、期待、実際、判定）。`summarize.sh` が読む |
| `calls.tsv` | ツールの呼び出しの一覧（拒否・エラーの印つき） |
| `commands-vs-rules.tsv` | 実行したコマンドごとに、一致した狭いルール（C7n） |
| `notify.txt` | 通知の文と種類、字数 |
| `final.txt` | 最後の応答 |
| `progress.diff`、`daily-added.md` | `docs/progress/` の差分、日次ログに追記された部分（C10 を目で見る材料） |
| `new-commits.txt` | 新しいコミットの件名・本文・変更したファイル |
| `prompt.md`、`settings.local.json` | 実際に使ったプロンプトと許可設定 |
| `before/`、`after/` | 実行の前後の写し（HEAD、ref、status、インデックス、差分のハッシュ、記録のキー、reflog、`.state.json`） |
| `real-before-run.txt`、`real-after-run.txt` | 本物のリポジトリの写し（Rreal） |
| `stream.jsonl`、`stderr.txt`、`exit-code.txt` | `claude -p` の出力そのもの |

## 無効な回とやり直し

- R0（実行が最後まで終わらない）・Rreal（本物のリポジトリの写しが変わった）が NG の回は、原因を `stderr.txt`・`final.txt`・`real-*-run.txt` で調べる。
  - API・ネットワーク・認証のエラー、他のセッションによる本物のリポジトリの変化（毎晩のタスクの実行を含む）なら、その回は無効。新しい回の番号で準備からやり直す（例：`setup.sh S9 2`）。
  - 時間切れ（終了コード 124）や、タスクが途中で止まった（最後の応答に理由がある）なら、無効ではなく、計画どおりかの確認の NG として扱う（criteria.md 4章）。
- **NG が出た回を、やり直して OK に置き換えない。** すべての回の結果を報告する。
- 最初の回で、`git log` のような既存のルールの形まで拒否されていたら、砂場の `settings.local.json` が丸ごと無視された疑いがある（`claude -p` は、検証に失敗した設定ファイルを黙って無視する）。`permission-rules-add.json` の要素の書き方を確かめ、`s0-probe.sh` で仕組みを確かめ直してから続ける。原因が `permission-rules-add.json` の書き方なら、実装の不備（criteria.md の ii-5 の NG）として報告する。原因が予行の仕組み（`make-settings.js` など）なら、その回は無効として扱い、直した内容を報告に書く。

## 安全の仕組み

- 砂場は `git clone --no-hardlinks --branch master <worktree> <砂場>` で作り、すぐに `git remote remove origin` を実行する（push の経路を断つ）。clone の前後で、worktree の `git status --porcelain`・共有の ref・worktree の一覧・記録のキーが変わらないことを確かめる（変われば止まる）。
- 砂場への git はすべて `sbgit` を通す。毎回、砂場が `temp/rehearsal-27/` の下にあり、砂場自身の `.git` を持ち、remote が無いことを確かめる。
- `GIT_CEILING_DIRECTORIES=temp/rehearsal-27` を設定する（子の `claude -p` にも渡る）。砂場の `.git` が無いときに、gitが上の worktree を見つけてしまうことを防ぐ（自己確認で、空のフォルダでgitが止まることを確かめた）。
- `make-prompt.js` は、差し替えの後に本物のリポジトリ（メインのチェックアウト、worktree）のパスや `Users\owner\Documents\HirokiMiwa` で始まるパスが残っていたら、プロンプトを書かずに止める。1行目のほかが `skill-after.md` と同じであることも確かめる。
- 砂場の Write・Edit のルールは砂場の `docs/progress/**` だけ。`PushNotification` は allow に入れず、deny に入れ、`--disallowedTools PushNotification` も付ける。プロンプトの先頭でも「使わない」と指示する。
- `--dangerously-skip-permissions`・`--allowedTools`・`--permission-mode`・`--settings`・`--setting-sources` は付けない（`run.sh` が止める）。
- 本物のリポジトリには読み取りのコマンドだけを使う（`real_snapshot`）。ブランチの切り替え、コミット、push はしない。

## 本番との違い（予行の限界）

| 違い | 理由・影響 |
|---|---|
| CLI 2.1.300（ヘッドレス）。本番はデスクトップアプリの 2.1.304 | アプリがプロンプトを包む文や、許可の扱いが違うかもしれない（plan.md 9章 R10）。(iii)・(iv) で確かめる |
| `--permission-prompts none` | 承認が要る呼び出しを、待たずに拒否する。本番では承認待ちで止まる場面に当たる。拒否は `permission_denials` に残る |
| MCP サーバーを起動しない（`--strict-mcp-config`） | 共有の MATLAB などに触れないため。タスクは MCP を使わない |
| 親のセッションの環境変数 `CLAUDE*` を外す | 独立したセッションとして動かすため（入れ子の起動の制限を避ける） |
| `--no-session-persistence` | `~/.claude/projects/` に会話の記録を残さない（ただし、空の `memory` フォルダは砂場ごとに1つできる） |
| `GIT_CEILING_DIRECTORIES` が子にも渡る | 安全のため。砂場のルートで動く限り、gitの動きは変わらない |
| 砂場の上のフォルダの `CLAUDE.md`（worktree、メインのチェックアウト）も読まれる | 中身はプロジェクトの `CLAUDE.md` と同じ（実装の後の worktree 版を含む） |
| 組み込みの読み取りの許可 | `git status --porcelain` はルールが無くても許された（S0 の6）。読み取りのコマンドのルールの不足は、C7 では見えない。静的な確認と C7n で補う |
| モデル | ユーザーの設定の `opus[1m]`（S0 で `claude-opus-5-5[1m]`）。本番のコミットの `Co-Authored-By: Claude Opus 5.5` と同じ |

## (b) に替える場合の手順（`claude -p` が使えないとき）

評価の日に `claude -p` が動かない（認証、ネットワーク、入れ子の起動の制限、CLI の変更など）場合は、何が起きたか（`stderr.txt` の文、終了コード）を記録し、メインに伝えてから (b) に替える（plan.md Q8）。

1. `bash $R/setup.sh <場面> <回>`
2. `bash $R/manual.sh <場面> <回> begin --skill $I/skill-after.md --rules $I/permission-rules-add.json`（前の写しと `prompt.md` を作る）
3. 評価担当が、砂場をカレントディレクトリにして、`prompt.md` の手順を文字どおりに行う。コマンドは書いてある形のまま、1回に1つ。実行したコマンドを `manual-commands.txt`、書いたファイルを `manual-writes.txt`、送るはずの通知を `manual-notify.txt` に1行ずつ書く。PushNotification は送らない。
   - 評価担当のセッションの隔離の仕組みが、砂場での git の書き込みを止める場合がある。そのときは、コマンドを1つだけ書いた使い捨てのスクリプト（本物のパスを含まないことを確かめたもの）を実行する。
4. `bash $R/manual.sh <場面> <回> end`（後の写しと判定）
- (b) では許可の照合が起きないので、**C7 は確かめられない**。特に、`git switch -` が `Bash(git switch -)` に一致するか（plan.md 9章 R1）は、(b) では確かめられず、(iv) まで残るリスクになる（criteria.md 7章）。C7n（狭いルールとの照合）は `manual-commands.txt` から計算する。
- (b) では、評価担当が手順を読み替えてしまう危険がある（LLM の解釈の揺れを再現しない）。文字どおりに行い、迷った箇所は報告に書く。

## 仕組みの確認の結果（2026-10-22、evaluator A）

worktree `claude/progress-log-master`（`3cf1c0a`）、CLI 2.1.300、モデル `claude-opus-5-5[1m]`、`permissionMode: default`。記録は `temp/rehearsal-27/S0-1.run/`・`S0b-1.run/`。

| 確かめたこと | 結果 |
|---|---|
| 砂場を作れる（`setup.sh S2 1`、その後 `selftest.sh` で全19場面） | 作れた。HEAD・ブランチ・`.state.json`・first-parent の鎖・status が場面どおり。remote は無い。`.claude/settings.local.json` は砂場の `.gitignore` で無視される。clone の前後で worktree の `git status --porcelain` は同じ（`?? docs/issues/27-progress-log-master/rehearsal/` のまま） |
| 砂場で `claude -p` が動く | 動いた（S0：44秒、12回の呼び出し。S0b：37秒）。`CLAUDE*` を外したので入れ子の起動の制限は出なかった |
| 許可していない形は、承認待ちにならず拒否として記録される | `git switch -c x`・`git add --dry-run README.md`・ルールの外への Write が、`permission_denials` に記録された（「Permission for this tool use was denied. It requires approval, and this session …」） |
| 砂場の `settings.local.json` のルールが効く | `git log -1`、`git rev-parse`、`git config progress-report.return-branch s0-probe`（書き込み）、`git switch master`、**`git switch -`**、`git config --unset …` が拒否されなかった。`git switch -` の後は `claude/test` に戻った |
| 親のフォルダの設定が砂場に漏れない | worktree の `Bash(git add *)` に当たる `git add --dry-run README.md` は拒否された |
| 組み込みの読み取りの許可 | ルールの無い `git status --porcelain` は許された |
| Write・Edit のルール | **Write ツールは `Edit(…)` のルールで許される。`Write(…)` だけのルールは効かなかった**（S0 の11、S0b の B・C・E。パスに `.claude` を含まない場所でも同じ）。`Edit(//c/…/docs/progress/**)` があると、Write・Edit とも許された（S0b の A・F）。本番の設定には両方があるので、書き換えた base で動く |
| PushNotification | ヘッドレスのツールの一覧（init の `tools`）に入っていた。S0・S0b では呼ばれなかった。予行では deny と `--disallowedTools` で止める |
| `~/.claude/` への影響 | 会話の記録は残らなかった（`--no-session-persistence`）。砂場ごとに `~/.claude/projects/<砂場のパス>/memory/`（空のフォルダ）ができた。`~/.claude.json` に砂場のパスは書かれなかった |
| 本物のリポジトリ | clone の前後、実行の前後で、worktree の status・共有の ref・worktree の一覧・記録のキーが変わらなかった |
