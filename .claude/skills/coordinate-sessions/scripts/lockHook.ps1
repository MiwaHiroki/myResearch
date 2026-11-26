# lockHook.ps1  Edit・Write・NotebookEdit の前に、ロックを確かめるフック（PreToolUse）
# .claude/settings.json から呼ばれる。どの worktree のセッションでも同じ台帳を見る。
#
# 止める（exit 2）のは次の2つの場合だけ。それ以外と、調べられなかったときは止めない（exit 0）。
#   (1) 編集するファイルを、別のブランチがロックしている。
#   (2) 編集するファイルが共有ファイル（hotspots.txt）で、自分のロックが無く、
#       ほかに作業中のセッションが台帳にある。並行作業をしていないときは、手間を増やさないため止めない。
# Bash・PowerShell からのファイルの書き換えは止められない（docs/parallel-sessions.md の「限界」）。

try {
    . (Join-Path $PSScriptRoot 'coordLib.ps1')
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $stdin = [Console]::In.ReadToEnd()
    $evt = $stdin | ConvertFrom-Json
    $file = $evt.tool_input.file_path
    if (-not $file) { $file = $evt.tool_input.notebook_path }
    if (-not $file) { exit 0 }
    $file = $file -replace '\\', '/'

    # 新しく作るファイルはまだ無いので、存在するフォルダまでさかのぼって git に尋ねる。
    $dir = Split-Path -Parent $file
    while ($dir -and -not (Test-Path $dir)) { $dir = Split-Path -Parent $dir }
    if (-not $dir) { exit 0 }
    $repo = Get-RepoInfo $dir
    if (-not $repo) { exit 0 }

    $top = $repo.Top -replace '\\', '/'
    if (-not $file.StartsWith($top + '/', [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
    $rel = $file.Substring($top.Length + 1)
    $branch = $repo.Branch

    $ledger = Read-Ledger $repo.MainRoot
    $held = $ledger.locks | Where-Object { $_.branch -ne $branch -and $rel -like $_.pattern } | Select-Object -First 1
    if ($held) {
        [Console]::Error.WriteLine("[coordinate-sessions] $rel は、ブランチ $($held.branch) がロックしています（$($held.since) から）。このファイルは変えずに、ユーザーか司令塔のセッションに、ロックが外れるのを待つか作業の範囲を分けるかを相談してください。")
        exit 2
    }

    $others = @(Get-ActiveSessions $ledger | Where-Object { $_.branch -ne $branch })
    if ($others.Count -gt 0 -and (Test-PathMatch $rel (Get-Hotspots))) {
        $mine = @($ledger.locks | Where-Object { $_.branch -eq $branch } | ForEach-Object { $_.pattern })
        if (-not (Test-PathMatch $rel $mine)) {
            $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/coordinate-sessions/scripts/coord.ps1 lock -Paths '$rel'"
            [Console]::Error.WriteLine("[coordinate-sessions] $rel は共有ファイルで、ほかのセッションが並行して作業しています（$(($others | ForEach-Object { $_.branch }) -join ', ')）。先にロックを取ってから編集してください: $cmd")
            exit 2
        }
    }
    exit 0
} catch {
    exit 0
}
