# coord.ps1  並行セッションの台帳を操作し、ファイルの重なりを調べるコマンド
# 使い方は docs/parallel-sessions.md と .claude/skills/coordinate-sessions/SKILL.md を参照。
#
#   register    セッションを台帳に載せる（テーマ、issue、変える予定のファイル）
#   lock        共有ファイルのロックを取る（別のブランチが持っていれば断る）
#   unlock      ロックを外す
#   set-status  セッションの状態を変える（active / merge-ready / merged）
#   release     セッションとそのロックを台帳から消す
#   status      全 worktree の変更ファイル、重なり、宣言外の変更、ロックを表示する
#   check-merge 1つのブランチをマージしてよいかを調べる
#   hotspots    共有ファイルの一覧を表示する
#
# -Branch を省くと、カレントディレクトリのブランチを使う。

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('register', 'lock', 'unlock', 'set-status', 'release', 'status', 'check-merge', 'hotspots')]
    [string]$Command,
    [string]$Branch,
    [string]$Theme = '',
    [int]$Issue = 0,
    [string[]]$Files = @(),
    [string[]]$Paths = @(),
    [ValidateSet('active', 'merge-ready', 'merged')]
    [string]$Status = 'active',
    [string]$Note = ''
)

. (Join-Path $PSScriptRoot 'coordLib.ps1')

$repo = Get-RepoInfo (Get-Location).Path
if (-not $repo) { Write-Error 'git リポジトリの中で実行してください。'; exit 1 }
$mainRoot = $repo.MainRoot
if (-not $Branch) { $Branch = $repo.Branch }
$now = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

# 複数の値を , 区切りの1つの文字列で渡されたときにも分ける（bash から呼ぶとき用）。
$Files = @($Files | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() -replace '\\', '/' } | Where-Object { $_ })
$Paths = @($Paths | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() -replace '\\', '/' } | Where-Object { $_ })

function Find-WorktreePath {
    param([string]$B)
    $wt = Get-Worktrees $mainRoot | Where-Object { $_.Branch -eq $B } | Select-Object -First 1
    if ($wt) { return $wt.Path }
    return $null
}

# ブランチごとの変更ファイルを集める（台帳に載っているか、worktree があるブランチ）。
function Get-BranchChanges {
    param($Ledger)
    $result = @{}
    foreach ($wt in Get-Worktrees $mainRoot) {
        $result[$wt.Branch] = [pscustomobject]@{ Branch = $wt.Branch; Path = $wt.Path; Files = @(Get-ChangedFiles $wt.Path) }
    }
    foreach ($s in Get-ActiveSessions $Ledger) {
        if (-not $result.ContainsKey($s.branch)) {
            # worktree が無いブランチ（push 済みで worktree を消したものなど）はコミット済みの差分だけを見る。
            $diff = Invoke-Git $mainRoot @('diff', '--name-only', "$BASE_BRANCH...$($s.branch)")
            $result[$s.branch] = [pscustomobject]@{ Branch = $s.branch; Path = '(worktree なし)'; Files = @($diff) }
        }
    }
    return $result
}

function Get-Overlaps {
    param($Changes, [string]$B)
    $mine = @($Changes[$B].Files)
    $out = @()
    foreach ($other in $Changes.Values) {
        if ($other.Branch -eq $B) { continue }
        foreach ($f in $mine) {
            if (@($other.Files) -contains $f) { $out += [pscustomobject]@{ File = $f; Other = $other.Branch } }
        }
    }
    return $out
}

switch ($Command) {
    'hotspots' {
        Get-Hotspots
    }

    'register' {
        Invoke-WithLedgerLock {
            $ledger = Read-Ledger $mainRoot
            $wtPath = Find-WorktreePath $Branch
            $existing = $ledger.sessions | Where-Object { $_.branch -eq $Branch } | Select-Object -First 1
            if ($existing) {
                if ($Theme) { $existing.theme = $Theme }
                if ($Issue) { $existing.issue = $Issue }
                if ($Files.Count) { $existing.files = @(@($existing.files) + $Files | Sort-Object -Unique) }
                if ($Note) { $existing.note = $Note }
                if ($wtPath) { $existing.worktree = $wtPath }
                Write-Output "更新しました: $Branch"
            } else {
                $ledger.sessions = @($ledger.sessions) + [pscustomobject]@{
                    branch = $Branch; worktree = $wtPath; theme = $Theme; issue = $Issue
                    files = @($Files); status = 'active'; registered = $now; note = $Note
                }
                Write-Output "登録しました: $Branch"
            }
            Write-Ledger $mainRoot $ledger
            # 宣言したファイルが、ほかの作業中のセッションの宣言と重なっていたら知らせる。
            foreach ($o in Get-ActiveSessions $ledger | Where-Object { $_.branch -ne $Branch }) {
                foreach ($f in $Files) {
                    foreach ($g in @($o.files)) {
                        if ($f -like $g -or $g -like $f) { Write-Output "注意: $f は $($o.branch) の宣言（$g）と重なります。" }
                    }
                }
            }
        }
    }

    'lock' {
        if (-not $Paths.Count) { Write-Error '-Paths を指定してください。'; exit 1 }
        $denied = $false
        Invoke-WithLedgerLock {
            $ledger = Read-Ledger $mainRoot
            foreach ($p in $Paths) {
                # 同じパターンか、互いに一致するパターンを別のブランチが持っていたら断る。
                $held = $ledger.locks | Where-Object {
                    $_.branch -ne $Branch -and ($p -like $_.pattern -or $_.pattern -like $p)
                } | Select-Object -First 1
                if ($held) {
                    Write-Output "断りました: $p は $($held.branch) がロック中です（$($held.since) から）。"
                    $script:denied = $true
                    continue
                }
                if (-not ($ledger.locks | Where-Object { $_.branch -eq $Branch -and $_.pattern -eq $p })) {
                    $ledger.locks = @($ledger.locks) + [pscustomobject]@{ pattern = $p; branch = $Branch; since = $now }
                }
                Write-Output "ロックしました: $p ($Branch)"
            }
            Write-Ledger $mainRoot $ledger
        }
        if ($script:denied) { exit 2 }
    }

    'unlock' {
        Invoke-WithLedgerLock {
            $ledger = Read-Ledger $mainRoot
            $ledger.locks = @($ledger.locks | Where-Object {
                    -not ($_.branch -eq $Branch -and ($Paths.Count -eq 0 -or $Paths -contains $_.pattern))
                })
            Write-Ledger $mainRoot $ledger
            Write-Output "ロックを外しました: $Branch $($Paths -join ', ')"
        }
    }

    'set-status' {
        Invoke-WithLedgerLock {
            $ledger = Read-Ledger $mainRoot
            $s = $ledger.sessions | Where-Object { $_.branch -eq $Branch } | Select-Object -First 1
            if (-not $s) { Write-Error "台帳にありません: $Branch"; return }
            $s.status = $Status
            if ($Status -eq 'merged') { $ledger.locks = @($ledger.locks | Where-Object { $_.branch -ne $Branch }) }
            Write-Ledger $mainRoot $ledger
            Write-Output "状態を $Status にしました: $Branch"
        }
    }

    'release' {
        Invoke-WithLedgerLock {
            $ledger = Read-Ledger $mainRoot
            $ledger.sessions = @($ledger.sessions | Where-Object { $_.branch -ne $Branch })
            $ledger.locks = @($ledger.locks | Where-Object { $_.branch -ne $Branch })
            Write-Ledger $mainRoot $ledger
            Write-Output "台帳から消しました: $Branch"
        }
    }

    'status' {
        $ledger = Read-Ledger $mainRoot
        $hot = Get-Hotspots
        $changes = Get-BranchChanges $ledger
        Write-Output "台帳: $(Get-LedgerPath $mainRoot)"
        Write-Output ''
        foreach ($c in $changes.Values | Sort-Object Branch) {
            $s = $ledger.sessions | Where-Object { $_.branch -eq $c.Branch } | Select-Object -First 1
            $label = if ($s) { "[$($s.status)] $($s.theme)" + $(if ($s.issue) { " (#$($s.issue))" } else { '' }) } else { '[台帳になし]' }
            Write-Output "== $($c.Branch)  $label"
            Write-Output "   場所: $($c.Path)"
            Write-Output "   変更ファイル: $(@($c.Files).Count) 件"
            $myLocks = @($ledger.locks | Where-Object { $_.branch -eq $c.Branch } | ForEach-Object { $_.pattern })
            if ($myLocks.Count) { Write-Output "   ロック: $($myLocks -join ', ')" }
            foreach ($f in $c.Files) {
                $marks = @()
                if ($s -and -not (Test-PathMatch $f (@($s.files) + $myLocks))) { $marks += '宣言外' }
                if ((Test-PathMatch $f $hot) -and -not (Test-PathMatch $f $myLocks) -and $c.Branch -ne $BASE_BRANCH) { $marks += '共有ファイル・ロックなし' }
                foreach ($o in Get-Overlaps $changes $c.Branch | Where-Object { $_.File -eq $f }) { $marks += "重なり:$($o.Other)" }
                if ($marks.Count) { Write-Output "   ! $f  <$($marks -join ' / ')>" }
            }
            Write-Output ''
        }
        $stale = @($ledger.sessions | Where-Object { $_.status -ne 'merged' -and -not $changes.ContainsKey($_.branch) })
        foreach ($s in $stale) { Write-Output "台帳にあるがブランチが見つからない: $($s.branch)" }
    }

    'check-merge' {
        $ledger = Read-Ledger $mainRoot
        $changes = Get-BranchChanges $ledger
        if (-not $changes.ContainsKey($Branch)) { Write-Error "ブランチが見つかりません: $Branch"; exit 1 }
        $ok = $true
        Write-Output "== マージの確認: $Branch"
        $wt = $changes[$Branch].Path
        $dir = if (Test-Path $wt) { $wt } else { $mainRoot }
        $dirty = if (Test-Path $wt) { Invoke-Git $wt @('status', '--porcelain') } else { $null }
        if ($dirty) { Write-Output 'NG  worktree に未コミットの変更がある。'; $ok = $false }
        else { Write-Output 'OK  未コミットの変更はない。' }
        & git -C $mainRoot merge-base --is-ancestor $BASE_BRANCH $Branch 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Output "NG  $BASE_BRANCH の最新を取り込んでいない（$BASE_BRANCH を merge してテストをやり直す）。"; $ok = $false }
        else { Write-Output "OK  $BASE_BRANCH の最新を取り込んでいる。" }
        $overlaps = @(Get-Overlaps $changes $Branch | Where-Object { $_.Other -ne $BASE_BRANCH })
        if ($overlaps.Count) {
            Write-Output 'NG  ほかの作業中のブランチと同じファイルを変えている（マージの順番と、後のブランチへの取り込みを決める）。'
            $overlaps | ForEach-Object { Write-Output "      $($_.File)  <- $($_.Other)" }
            $ok = $false
        } else { Write-Output 'OK  ほかの作業中のブランチと重なるファイルはない。' }
        $foreign = @()
        foreach ($f in $changes[$Branch].Files) {
            $held = $ledger.locks | Where-Object { $_.branch -ne $Branch -and $f -like $_.pattern } | Select-Object -First 1
            if ($held) { $foreign += "$f <- $($held.branch)" }
        }
        if ($foreign.Count) { Write-Output 'NG  ほかのブランチがロックしているファイルを変えている。'; $foreign | ForEach-Object { Write-Output "      $_" }; $ok = $false }
        Write-Output ''
        if ($ok) { Write-Output '判定: マージしてよい（CI の結果は別に確かめる）。'; exit 0 }
        Write-Output '判定: まだマージしない。'
        exit 3
    }
}
