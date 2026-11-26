# coordLib.ps1  並行セッションの台帳を読み書きする共通の関数
# coord.ps1（司令塔・各セッションが使うコマンド）と lockHook.ps1（編集を止めるフック）が読み込む。
# 台帳はメインのチェックアウトの .claude/coordination/ledger.json に1つだけ置く（git の管理外）。
# どの worktree から呼んでも同じ台帳を指すように、git の共通ディレクトリからメインのルートを求める。

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

$script:BASE_BRANCH = 'master'
$script:MUTEX_NAME = 'Global\myResearchCoordinationLedger'

function Invoke-Git {
    param([string]$Dir, [string[]]$GitArgs)
    $out = & git -C $Dir -c core.quotepath=false @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

# 指定したフォルダが属するリポジトリの情報（作業ツリーのルート、ブランチ、メインのルート）を返す。
function Get-RepoInfo {
    param([string]$Dir)
    $top = Invoke-Git $Dir @('rev-parse', '--show-toplevel')
    if (-not $top) { return $null }
    $common = Invoke-Git $Dir @('rev-parse', '--path-format=absolute', '--git-common-dir')
    $branch = Invoke-Git $Dir @('branch', '--show-current')
    if (-not $branch) { $branch = 'HEAD' }
    [pscustomobject]@{
        Top      = ($top | Select-Object -First 1)
        Branch   = ($branch | Select-Object -First 1)
        MainRoot = (Split-Path -Parent ($common | Select-Object -First 1)) -replace '\\', '/'
    }
}

function Get-LedgerPath {
    param([string]$MainRoot)
    Join-Path $MainRoot '.claude/coordination/ledger.json'
}

function Read-Ledger {
    param([string]$MainRoot)
    $path = Get-LedgerPath $MainRoot
    $ledger = [pscustomobject]@{ version = 1; sessions = @(); locks = @() }
    if (Test-Path $path) {
        $raw = Get-Content -Raw -Encoding UTF8 $path
        if ($raw.Trim()) {
            $obj = $raw | ConvertFrom-Json
            $ledger.sessions = @($obj.sessions | Where-Object { $_ })
            $ledger.locks = @($obj.locks | Where-Object { $_ })
        }
    }
    foreach ($s in $ledger.sessions) { $s.files = @($s.files | Where-Object { $_ }) }
    return $ledger
}

function Write-Ledger {
    param([string]$MainRoot, $Ledger)
    $path = Get-LedgerPath $MainRoot
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $json = [pscustomobject]@{
        version  = 1
        sessions = @($Ledger.sessions)
        locks    = @($Ledger.locks)
    } | ConvertTo-Json -Depth 6
    $tmp = "$path.tmp"
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
    Move-Item -Force $tmp $path
}

# 台帳の読み書きを、複数のセッションから同時に行っても壊れないように、名前付きミューテックスで囲む。
function Invoke-WithLedgerLock {
    param([scriptblock]$Body)
    $mutex = New-Object Threading.Mutex($false, $script:MUTEX_NAME)
    try {
        [void]$mutex.WaitOne(10000)
        & $Body
    } finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}

function Get-Hotspots {
    $file = Join-Path $PSScriptRoot '../hotspots.txt'
    if (-not (Test-Path $file)) { return @() }
    @(Get-Content -Encoding UTF8 $file | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
}

# パス（/ 区切り、リポジトリのルートからの相対）がパターンのどれかに一致するか。
function Test-PathMatch {
    param([string]$Path, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        if ($Path -like $p) { return $true }
    }
    return $false
}

# 作業ブランチが master から変えたファイル（コミット済み＋未コミット）を返す。
function Get-ChangedFiles {
    param([string]$WorktreeDir)
    $files = @()
    $committed = Invoke-Git $WorktreeDir @('diff', '--name-only', "$script:BASE_BRANCH...HEAD")
    if ($committed) { $files += $committed }
    $status = Invoke-Git $WorktreeDir @('status', '--porcelain', '--untracked-files=all')
    foreach ($line in @($status)) {
        if (-not $line) { continue }
        $p = $line.Substring(3)
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }
        $files += $p.Trim('"')
    }
    @($files | Sort-Object -Unique)
}

# git worktree list から、各作業ツリーのパスとブランチを返す。
function Get-Worktrees {
    param([string]$MainRoot)
    $lines = Invoke-Git $MainRoot @('worktree', 'list', '--porcelain')
    $list = @()
    $cur = $null
    foreach ($l in @($lines)) {
        if ($l -like 'worktree *') {
            if ($cur) { $list += $cur }
            $cur = [pscustomobject]@{ Path = $l.Substring(9); Branch = 'HEAD' }
        } elseif ($l -like 'branch refs/heads/*') {
            $cur.Branch = $l.Substring(18)
        }
    }
    if ($cur) { $list += $cur }
    return $list
}

function Get-ActiveSessions {
    param($Ledger)
    @($Ledger.sessions | Where-Object { $_.status -ne 'merged' })
}
