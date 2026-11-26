% checkResultsLayout.m
% issue #28（結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す）の評価スクリプト。
% docs/issues/closed/28-results-by-experiment/criteria.md の項目ごとに、次を確かめて表にする。
%   - 移行（results/ の移動、experiments/ の改名、スライド用の図の git mv）で、移す前の
%     ファイルがすべて対応表どおりの場所に同じ中身で残っていること（manifestBeforeMigration.csv と照らす）
%   - 古い形のフォルダ・古い書き方（mkdirFromDate、results/<MMDD>/ など）が残っていないこと
%   - スクリプトの冒頭（実験名・日付・説明、runConditions・resultDir・figureDir）が計画どおりなこと
%   - .gitignore と git の追跡、文書、変えてはいけないファイル
%   - 実データで実行した結果（criteria.md 8章の手順で作ったもの。パラメータで場所を渡す）
% 何も書き出さない（results/ にも experiments/ にも作らない）。読み取りだけで、表をコマンドウィンドウに出す。
% 判定の表の「判定」は「満たす」「満たさない」「B が判断」「未実施」のどれか。「B が判断」は、
% 評価担当（モードB）が一覧を読んで criteria.md の基準で判断する項目である。
%
% 前提：Research.prj を開いていること。移行と改名が終わっていること。作業ツリーがきれいなこと。
% ワークスペースに変数が残っていると名前がぶつかることがある（height など）ので、clear してから実行する。
% manifestBeforeMigration.csv は、評価基準の段階（2026-11-24）に、移す前の results/・experiments/ の
% すべてのファイル（817個）のルートからのパス・大きさ・SHA-256 を記録したもの（変えない）。
% 2026/11/24作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = string(proj.RootFolder);

%% パラメータ（実行する人が書き換える場所）
BASE_COMMIT = "";                   % criteria.md の <受け入れテストを追加したコミット>（短い形でよい）
MERGE_COMMITS = strings(0,1);       % 評価基準の後に master から取り込んだマージのコミット（その変更は P4・D1 から除く）
APPROVED_LEFTOVERS = strings(0,1);  % 承認B で「移さずに残す」と決めた古い形のフォルダ（ルートからの相対パス）。README の作業履歴に決定があるものだけ
APPROVED_DELETIONS = strings(0,1);  % 承認B で「消す」と決めたファイル・フォルダ（移す前のパス。例 "results/1110/"）。同上
MAPPING_CSV = fullfile(rootFolder, "scripts", "migration", "resultsMapping.csv");   % 対応表（承認B のもの）
MANIFEST_CSV = fullfile(rootFolder, "scripts", "evaluation", "resultsLayout", "manifestBeforeMigration.csv");
COMPUTE_SHA = true;                 % SHA-256 を計算するか（817ファイル、約2.4GB で約20秒）
RUN_MIGRATION_DRYRUN = true;        % migrateResults の試し（何も動かさない）を両方の段階で実行するか

% 実データでの確認（criteria.md 8章の手順で作ったもの。ルートからの相対パス。未実施なら ""）
E1_RUN_DIR = "";      % bilateralOri_centroid_1cycle.m のコピーで作った実行フォルダ（Q10）
E2_RUN_DIR = "";      % 同じ設定で、もう一度 resultDir まで実行して作ったフォルダ（Q11。_2 が付いたもの）
E1_REF_DIR = "results/bilateralFilter/2026-0924_1cycle";   % 出力のファイル名を比べる、移した過去の実行（対応表で名前が変わったら直す）
E3_CHECK_MAT = "";    % pkCentroid_1cycle.m のコピーが保存した ycoords_cnt・ycoords_max・cond の .mat（Q12）
E3_RUN_DIR = "";      % そのコピーが作った実行フォルダ（Q12 の runInfo.json）
E3_REF_MAT = "experiments/2026-1014/cycleResult_origD_2026-1014.mat";   % 比べる相手（1014 の手動選択）
E4_FIG_DIR = "";      % waveformManualVsTrack.m のコピーが図を保存したフォルダ（Q9）

% 計画で決まっているもの（plan.md）
EXPERIMENT_NAMES = ["upsampling","photoshopUpscaling","bilateralFilter","digitalNeedle", ...
    "grooveTracking","multiGroove","grooveBottomDetection","stylus"];          % 8章 Q6
SLIDES_MOVE = ["results/figures/slides/202609asj", "results/figures/202609asj/slides"];   % main が git mv で移す（対応表の CSV には無い）
% 実験のスクリプト23本の、実験名と説明の既定値（plan.md 4.4.1・4.4.2）
EXPECTED_RUN_DEFAULTS = [
    "scripts/pkCentroid_1cycle.m",                                      "upsampling",            ""
    "scripts/pkCentroid_resample_1cycle.m",                             "upsampling",            ""
    "scripts/pkCentroid_interp2_1cycle.m",                              "upsampling",            ""
    "scripts/photoshop_centroid_1cycle.m",                              "photoshopUpscaling",    ""
    "scripts/photoshop_localMax_1cycle.m",                              "photoshopUpscaling",    ""
    "scripts/grooveTrack_1cycle.m",                                     "grooveTracking",        ""
    "scripts/grooveHist_Ncycle.m",                                      "multiGroove",           ""
    "scripts/grooveTrack_Ncycle.m",                                     "multiGroove",           ""
    "scripts/bilateral/bilateralOri_centroid.m",                        "bilateralFilter",       "ori"
    "scripts/bilateral/bilateralOriResample_centroid.m",                "bilateralFilter",       "oriRsmpl"
    "scripts/bilateral/bilateralOriInterp2_centroid.m",                 "bilateralFilter",       "oriIntp"
    "scripts/bilateral/bilateral8x_centroid.m",                         "bilateralFilter",       "photoshop8x"
    "scripts/bilateral/bilateralOri_centroid_1cycle.m",                 "bilateralFilter",       "1cycle"
    "scripts/darkness3d.m",                                             "upsampling",            ""
    "scripts/evaluation/grooveBottomDetection/compareInclBoundToExclBound.m", "grooveBottomDetection", "evaluation"
    "scripts/evaluation/grooveBottomDetection/compareWidthThresh.m",    "grooveBottomDetection", "evaluation"
    "scripts/evaluation/grooveTracking/compareTrackingToManual.m",      "grooveTracking",        "evaluation"
    "scripts/evaluation/multiGroove/compareHistToTracking.m",           "multiGroove",           "evaluation"
    "scripts/evaluation/stylus/sound_from_stylus.m",                    "stylus",                ""
    "scripts/pkCentroidAndLocalMax_resample_1cycle.m",                  "upsampling",            ""
    "scripts/pkCentroid_interp2.m",                                     "upsampling",            ""
    "scripts/pkCentroid_resample.m",                                    "upsampling",            ""
    "scripts/progress/showPhotoshopGrooveExtraction.m",                 "photoshopUpscaling",    ""];
% 計画の読むパス（plan.md 7.4。experiments/ からの相対パス）
READ_PATHS = [
    "2026-0807/cycleResult_rsmplD_2026-0807.mat"
    "2026-1104/cycleResult_origD_hist5_2026-1104.mat"
    "2026-1014/cycleResult_origD_track_2026-1014.mat"
    "2026-1104/cycleResult_origD_track5_2026-1104.mat"
    "2026-1014/cycleResult_origD_2026-1014.mat"
    "2026-0731/cycleResult_origD_2026-0731.mat"
    "2026-0731/cycleResult_intpD_2026-0731.mat"
    "2026-0731/cycleResult_rsmplD_2026-0731.mat"
    "2026-0802/cycleResult_origD_2026-0802.mat"];
% src/ で変えてよいもの（plan.md 4.5）。A は新しく作るもの（すべて要る）、M は変えてよいもの
SRC_ADDED = ["src/resultDir.m","src/runConditions.m","src/figureDir.m","src/collectMeta.m","src/gitState.m"];
SRC_MODIFIED = ["src/cycleConditions.m","src/saveCycleResult.m","src/mkdirFromDate.m","src/experimentDir.m", ...
    "src/cycleResultPath.m","src/cycleResultFileName.m","src/saveFigure.m"];
SRC_COMMENT_ONLY = ["src/mkdirFromDate.m","src/experimentDir.m","src/cycleResultPath.m", ...
    "src/cycleResultFileName.m","src/saveFigure.m"];                        % 説明（コメント）だけを直すもの（D2）
% 変えてはいけない場所（D1）
PROTECTED_PATHS = ["src/archive","scripts/archive","test/archive","docs/issues/closed","docs/progress", ...
    "slides/progress","src/checkFigureName.m","src/figureVocabulary.m","scripts/evaluation/resultsLayout"];
% 検索で、古い書き方が残っていてよい場所（criteria.md 5.2 の (a)）
ALLOWED_RESIDUAL_PREFIXES = ["docs/issues/closed/28-results-by-experiment/","scripts/migration/", ...
    "scripts/evaluation/resultsLayout/","test/unit/ResultLayoutAcceptanceTest.m", ...
    "test/unit/MigrateResultsTest.m","src/mkdirFromDate.m","src/cycleResultPath.m"];

if BASE_COMMIT == ""
    error("checkResultsLayout:baseNotSet", ...
        "BASE_COMMIT を、criteria.md の <受け入れテストを追加したコミット> にしてください。");
end

check = table('Size', [0 5], 'VariableTypes', ["string","string","string","string","string"], ...
    'VariableNames', ["id","metric","threshold","value","verdict"]);

%% 0. 作業ツリーとコミット
headCommit = strtrim(gitOut(rootFolder, "rev-parse --short HEAD"));
branchName = strtrim(gitOut(rootFolder, "rev-parse --abbrev-ref HEAD"));
porcelain = gitLines(rootFolder, "status --porcelain");
fprintf("\n== 評価したコード：%s（%s）、基準のコミット %s ==\n", headCommit, branchName, BASE_COMMIT);
fprintf("git status --porcelain：%d 行\n", numel(porcelain));
if ~isempty(porcelain)
    fprintf("  %s\n", porcelain);
end
excludedByMerge = strings(0,1);
for m = MERGE_COMMITS'
    excludedByMerge = [excludedByMerge; nameStatusPaths(gitLines(rootFolder, "diff --name-status " + m + "^1 " + m))]; %#ok<AGROW>
end
excludedByMerge = unique(excludedByMerge);

%% 1. T2：checkcode の警告（変えた .m は、変える前より増やさない。新しい .m は 0）
changed = gitLines(rootFolder, "diff --name-status -M " + BASE_COMMIT + " HEAD -- ""*.m""");
cc = table('Size', [0 4], 'VariableTypes', ["string","string","double","double"], ...
    'VariableNames', ["file","status","before","after"]);
for k = 1:numel(changed)
    parts = split(changed(k), char(9));
    st = extractBefore(parts(1) + " ", 2);
    file = parts(end);
    if st == "D" || contains(file, "/archive/") || ismember(file, excludedByMerge)
        continue
    end
    after = numel(checkcode(char(fullfile(rootFolder, file))));
    if st == "A"
        before = 0;
    else
        oldFile = parts(2);
        before = numel(checkcode(char(gitShowToTemp(rootFolder, BASE_COMMIT, oldFile))));
    end
    cc(end+1,:) = {file, st, before, after}; %#ok<SAGROW>
end
ccBad = cc(cc.after > cc.before, :);
fprintf("\n== T2 checkcode（変えた .m %d 個） ==\n", height(cc));
disp(cc(cc.before > 0 | cc.after > 0, :));
check = addCheck(check, "T2", "checkcode の警告が変える前より増えた .m（新しい .m は0件が基準）", "0 個", ...
    height(ccBad) + " 個（変える前 " + sum(cc.before) + " 件、後 " + sum(cc.after) + " 件）", verdictOf(height(ccBad) == 0));

%% 2. P4・D1・D2・D4：差分の範囲
ns = gitLines(rootFolder, "diff --name-status -M " + BASE_COMMIT + " HEAD -- src test scripts");
ns = ns(~ismember(nameStatusPaths(ns), excludedByMerge));
scope = strings(0,1);
srcAdded = strings(0,1);
for k = 1:numel(ns)
    parts = split(ns(k), char(9));
    st = extractBefore(parts(1) + " ", 2);
    file = parts(end);
    ok = false;
    if startsWith(file, "src/")
        ok = (st == "A" && ismember(file, SRC_ADDED)) || (st == "M" && ismember(file, SRC_MODIFIED));
        if st == "A", srcAdded(end+1) = file; end %#ok<SAGROW>
    elseif startsWith(file, "test/")
        ok = st == "A" && startsWith(file, "test/unit/") && endsWith(file, "Test.m");
    elseif startsWith(file, "scripts/")
        ok = (st == "M") || (st == "A" && startsWith(file, "scripts/migration/"));
    end
    if ~ok
        scope(end+1) = ns(k); %#ok<SAGROW>
    end
end
missingAdded = setdiff(SRC_ADDED, srcAdded);
fprintf("\n== P4 差分の範囲（src・test・scripts で計画の外にあるもの） ==\n");
fprintf("  %s\n", scope);
if ~isempty(missingAdded), fprintf("  作られていない：%s\n", missingAdded); end
check = addCheck(check, "P4", "src・test・scripts の差分のうち計画の外のもの（D・R、計画に無い src、既存のテストの変更など）、作られていない新しい src", ...
    "0 件（計画に無い scripts の M は B が判断）", (numel(scope) + numel(missingAdded)) + " 件", ...
    verdictOf(isempty(scope) && isempty(missingAdded)));

protectedDiff = strings(0,1);
for p = PROTECTED_PATHS
    protectedDiff = [protectedDiff; gitLines(rootFolder, "diff --name-status " + BASE_COMMIT + " HEAD -- """ + p + """")]; %#ok<AGROW>
end
protectedDiff = [protectedDiff; gitLines(rootFolder, "diff --name-status " + BASE_COMMIT + " HEAD -- ""test/unit/*AcceptanceTest.m""")];
existingTests = gitLines(rootFolder, "diff --name-status --diff-filter=MDR " + BASE_COMMIT + " HEAD -- test");
protectedDiff = unique([protectedDiff; existingTests]);
protectedDiff = protectedDiff(~ismember(nameStatusPaths(protectedDiff), excludedByMerge));
fprintf("\n== D1 変えてはいけないファイルの差分 ==\n");
fprintf("  %s\n", protectedDiff);
check = addCheck(check, "D1", "archive・過去の記録・図の名前の関数・受け入れテスト・既存のテスト・この評価のフォルダの差分", ...
    "0 件", numel(protectedDiff) + " 件", verdictOf(isempty(protectedDiff)));

nonComment = table('Size', [0 2], 'VariableTypes', ["string","double"], 'VariableNames', ["file","codeLines"]);
for f = SRC_COMMENT_ONLY
    d = gitShowDiff(rootFolder, BASE_COMMIT, f);
    nonComment(end+1,:) = {f, countCodeDiffLines(d)}; %#ok<SAGROW>
end
mkdirKept = isfile(fullfile(rootFolder, "src", "mkdirFromDate.m"));
fprintf("\n== D2 説明だけを直す src（コメントでない差分の行数） ==\n");
disp(nonComment);
check = addCheck(check, "D2", "mkdirFromDate・experimentDir・cycleResultPath・cycleResultFileName・saveFigure のコメントでない差分。mkdirFromDate が残る", ...
    "0 行、残る", sum(nonComment.codeLines) + " 行、mkdirFromDate " + string(mkdirKept), ...
    verdictOf(sum(nonComment.codeLines) == 0 && mkdirKept));

progressDiff = gitLines(rootFolder, "diff --name-status " + BASE_COMMIT + " HEAD -- results/figures/progress");
check = addCheck(check, "D4a", "results/figures/progress/ の git の差分", "0 件", numel(progressDiff) + " 件", ...
    verdictOf(isempty(progressDiff)));

%% 3. P1・P2・Q7：実験のスクリプト23本の冒頭
expScripts = baseGrepFiles(rootFolder, BASE_COMMIT, "mkdirFromDate");
cycleScripts = baseGrepFiles(rootFolder, BASE_COMMIT, "cycleConditions(");
fprintf("\n== P1・P2・Q7 実験のスクリプト（基準のコミットで mkdirFromDate を使っていた %d 本、うち cycleConditions を呼ぶ %d 本） ==\n", ...
    numel(expScripts), numel(cycleScripts));
p1 = table('Size', [0 9], 'VariableTypes', repmat("string", 1, 9), 'VariableNames', ...
    ["script","nResultDir","nRunConditions","experiment","label","date","condArg","cycleFirstArg","problem"]);
for s = expScripts'
    txt = readText(fullfile(rootFolder, s));
    st = codeStatements(txt);
    rdCalls = callsIn(st, "resultDir");
    rcStmts = st(contains([st.text], regexpPattern("(?<![\w.])runConditions\s*\(")));
    rcVar = "";
    if ~isempty(rcStmts)
        tok = regexp(rcStmts(1).text, "(\w+)\s*=\s*runConditions\s*\(", "tokens", "once");
        if ~isempty(tok), rcVar = string(tok{1}); end
    end
    problem = strings(0,1);
    expName = ""; labelVal = ""; dateVals = ""; condArg = ""; cycFirst = "";
    if numel(rdCalls) ~= 1
        problem(end+1) = "resultDir が " + numel(rdCalls) + " 回"; %#ok<SAGROW>
    end
    if numel(rcStmts) ~= 1
        problem(end+1) = "runConditions が " + numel(rcStmts) + " 回"; %#ok<SAGROW>
    end
    if ~isempty(rdCalls)
        a = rdCalls{1};
        if numel(a) >= 4
            expName = resolveValue(a(2), st);
            dateVals = strjoin(resolveAll(a(3), st), " / ");
            condArg = a(4);
            lab = nameValueArg(a, "Label", 4);
            if lab == ""
                labelVal = "";
            else
                labelVal = resolveValue(lab, st);
            end
            k = find(EXPECTED_RUN_DEFAULTS(:,1) == s);
            if isempty(k)
                problem(end+1) = "計画の表に無いスクリプト"; %#ok<SAGROW>
            else
                if expName ~= EXPECTED_RUN_DEFAULTS(k,2), problem(end+1) = "実験名が計画と違う"; end %#ok<SAGROW>
                if labelVal ~= EXPECTED_RUN_DEFAULTS(k,3), problem(end+1) = "説明が計画と違う"; end %#ok<SAGROW>
            end
            if ~ismember(expName, EXPERIMENT_NAMES), problem(end+1) = "実験名が一覧に無い"; end %#ok<SAGROW>
            if rcVar == "" || condArg ~= rcVar, problem(end+1) = "resultDir の第4引数が runConditions の出力でない"; end %#ok<SAGROW>
            if dateVals ~= "YYYY-MMDD", problem(end+1) = "Q7：出力の日付が YYYY-MMDD でない"; end %#ok<SAGROW>
        else
            problem(end+1) = "resultDir の引数が4つ未満"; %#ok<SAGROW>
        end
    end
    if ismember(s, cycleScripts)
        ccCalls = callsIn(st, "cycleConditions");
        if numel(ccCalls) ~= 1
            problem(end+1) = "P2：cycleConditions が " + numel(ccCalls) + " 回"; %#ok<SAGROW>
        else
            cycFirst = ccCalls{1}(1);
            if rcVar == "" || cycFirst ~= rcVar
                problem(end+1) = "P2：cycleConditions の第1引数が runConditions の出力でない"; %#ok<SAGROW>
            end
        end
    end
    p1(end+1,:) = {s, string(numel(rdCalls)), string(numel(rcStmts)), expName, labelVal, dateVals, ...
        condArg, cycFirst, strjoin(problem, "; ")}; %#ok<SAGROW>
end
disp(p1(:, ["script","experiment","label","date","condArg","cycleFirstArg","problem"]));
isP2 = contains(p1.problem, "P2：");
isQ7 = p1.date ~= "YYYY-MMDD";
p1Problems = erase(erase(p1.problem, regexpPattern("P2：[^;]*;?\s*")), regexpPattern("Q7：[^;]*;?\s*"));
nP1 = sum(strtrim(p1Problems) ~= "");
check = addCheck(check, "P1", "実験のスクリプト：resultDir・runConditions を1回ずつ、第4引数が runConditions の出力、実験名・説明の既定値が計画どおり", ...
    "外れるもの 0 本（" + height(EXPECTED_RUN_DEFAULTS) + " 本）", nP1 + " 本（対象 " + height(p1) + " 本）", ...
    verdictOf(nP1 == 0 && height(p1) == height(EXPECTED_RUN_DEFAULTS)));
check = addCheck(check, "P2", "1周分のスクリプト：cycleConditions の第1引数が runConditions の出力", ...
    "外れるもの 0 本（8 本）", sum(isP2) + " 本（対象 " + numel(cycleScripts) + " 本）", ...
    verdictOf(~any(isP2) && numel(cycleScripts) == 8));
check = addCheck(check, "Q7", "実験のスクリプト：resultDir に渡す日付の値が ""YYYY-MMDD"" だけ（出力の日付を書き込まない）", ...
    "外れるもの 0 本", sum(isQ7) + " 本", verdictOf(~any(isQ7)));

%% 4. P3：図のスクリプト32本の保存先
figScripts = baseGrepFiles(rootFolder, BASE_COMMIT, """results"" *, *""figures""", true);
p3 = table('Size', [0 5], 'VariableTypes', repmat("string", 1, 5), ...
    'VariableNames', ["script","before","after","nFigureDir","problem"]);
for s = figScripts'
    baseTxt = readText(gitShowToTemp(rootFolder, BASE_COMMIT, s));
    baseSt = codeStatements(baseTxt);
    before = strings(0,1);
    for c = callsIn(baseSt, "fullfile")
        a = c{1};
        idx = find(a == """results""", 1);
        if ~isempty(idx) && numel(a) >= idx + 3 && a(idx+1) == """figures"""
            before(end+1) = resolveValue(a(idx+2), baseSt) + "/" + resolveValue(a(idx+3), baseSt); %#ok<SAGROW>
        end
    end
    before = unique(before);
    st = codeStatements(readText(fullfile(rootFolder, s)));
    fd = callsIn(st, "figureDir");
    after = strings(0,1);
    for c = fd
        a = c{1};
        if numel(a) >= 3
            after(end+1) = resolveValue(a(2), st) + "/" + resolveValue(a(3), st); %#ok<SAGROW>
        end
    end
    after = unique(after);
    problem = "";
    if ~isequal(sort(before), sort(after))
        problem = "用途・名前が元の保存先と違う";
    end
    if numel(fd) ~= 1
        problem = strjoin([problem "figureDir が " + numel(fd) + " 回"], "; ");
    end
    p3(end+1,:) = {s, strjoin(before, ", "), strjoin(after, ", "), string(numel(fd)), problem}; %#ok<SAGROW>
end
fprintf("\n== P3 図のスクリプト（基準のコミットで ""results"",""figures"" を組み立てていた %d 本） ==\n", numel(figScripts));
disp(p3);
nP3 = sum(p3.problem ~= "");
check = addCheck(check, "P3", "図のスクリプト：figureDir を1回、用途と名前が元の保存先と同じ", ...
    "外れるもの 0 本（32 本）", nP3 + " 本（対象 " + height(p3) + " 本）", verdictOf(nP3 == 0 && height(p3) == 32));

%% 5. Q6：古い書き方の検索（issue の「対象ファイル」の4つと、その補い）
tracked = gitLines(rootFolder, "ls-files");
isText = ~endsWith(tracked, [".png",".fig",".pdf",".jpg",".jpeg",".wav",".mat",".mlx",".slx",".xlsx",".docx"]);
inScripts = startsWith(tracked, "scripts/") & endsWith(tracked, ".m") & ~contains(tracked, "/archive/") ...
    & ~startsWith(tracked, ["scripts/migration/","scripts/evaluation/resultsLayout/"]);
s1 = searchFiles(rootFolder, tracked(inScripts), "mkdirFromDate", false);
s2 = searchFiles(rootFolder, tracked(inScripts), """results""\s*,\s*""figures""", false);
s3 = searchFiles(rootFolder, tracked(inScripts), "DATE *= *""[0-9]{4}""|experiments"",""[0-9]{4}""|_[0-9]{4}\.mat", false);
s3b = searchFiles(rootFolder, tracked(inScripts), """\d{4}""", true);
s3b = s3b(~contains(s3b.text, """pictures"""), :);
s3c = searchFiles(rootFolder, tracked(inScripts), """MMDD""", true);
docScope = tracked(isText & ~startsWith(tracked, ["docs/issues/closed/","docs/progress/","slides/progress/"]));
s4 = searchFiles(rootFolder, docScope, ...
    "results/<日付>|results/<MMDD>|results/[0-9]{4}/|experiments/<MMDD>|experiments/[0-9]{4}/|figures/(paper|slides)/|mkdirFromDate", false);
readmeMapRange = sectionRange(readText(fullfile(rootFolder, "README.md")), "対応表");
s4.class = repmat("要確認", height(s4), 1);
for k = 1:height(s4)
    if contains(s4.file(k), "/archive/") || startsWith(s4.file(k), ALLOWED_RESIDUAL_PREFIXES)
        s4.class(k) = "許される場所";
    elseif s4.file(k) == "README.md" && ~isempty(readmeMapRange) && s4.line(k) >= readmeMapRange(1) && s4.line(k) <= readmeMapRange(2)
        s4.class(k) = "README の対応表";
    end
end
fprintf("\n== Q6 古い書き方の検索 ==\n");
fprintf("検索1（scripts の mkdirFromDate）：%d 行\n", height(s1)); disp(s1);
fprintf("検索2（scripts の ""results"",""figures""）：%d 行\n", height(s2)); disp(s2);
fprintf("検索3（scripts の 4桁の読み込みの日付）：%d 行\n", height(s3)); disp(s3);
fprintf("補い（scripts のコードにある ""dddd"" の文字列。写真のフォルダ ""pictures"" の行を除く）：%d 行\n", height(s3b)); disp(s3b);
fprintf("補い（scripts のコードにある ""MMDD"" の印）：%d 行\n", height(s3c)); disp(s3c);
fprintf("検索4（文書を含むリポジトリ全体）：%d 行（許される場所 %d、README の対応表 %d、要確認 %d）\n", height(s4), ...
    sum(s4.class == "許される場所"), sum(s4.class == "README の対応表"), sum(s4.class == "要確認"));
disp(s4(s4.class == "要確認", :));
nS13 = height(s1) + height(s2) + height(s3) + height(s3b) + height(s3c);
check = addCheck(check, "Q6a", "検索1〜3 と補い（scripts。archive・scripts/migration・この評価のフォルダを除く）に当たる行", ...
    "0 行", nS13 + " 行", verdictOf(nS13 == 0));
check = addCheck(check, "Q6b", "検索4 の「要確認」の行のうち、新しい出力・読み込みに古い置き場所を使うように書いている行", ...
    "0 行（B が判断）", sum(s4.class == "要確認") + " 行が要確認", "B が判断");

%% 6. Q9：図の名前とタイトルに書くデータの日付（4桁）
q9 = table('Size', [0 3], 'VariableTypes', ["string","double","string"], 'VariableNames', ["file","line","text"]);
readTokens = ["experimentDir(","cycleResultPath(","cycleResult",".mat","""experiments""","extractAfter(","extractBefore(","loadCycleResult("];
for s = [figScripts; tracked(startsWith(tracked, "scripts/evaluation/") & endsWith(tracked, ".m") & ~startsWith(tracked, "scripts/evaluation/resultsLayout/"))]'
    if ~isfile(fullfile(rootFolder, s)), continue; end
    st = codeStatements(readText(fullfile(rootFolder, s)));
    vars = strings(0,1);
    for k = 1:numel(st)
        tok = regexp(st(k).text, "(?<![\w.])(\w*DATES?\w*)\s*=\s*\[?\s*""\d{4}-\d{4}""", "tokens");
        vars = [vars; string(cellfun(@(t) t{1}, tok, "UniformOutput", false))']; %#ok<AGROW>
    end
    vars = unique(vars);
    for k = 1:numel(st)
        usesVar = false;
        for v = vars'
            if ~isempty(regexp(st(k).text, "(?<![\w.])" + v + "(?!\w)", "once")) && ...
                    isempty(regexp(st(k).text, "^\s*" + v + "\s*=", "once"))
                usesVar = true;
            end
        end
        if usesVar && ~contains(st(k).text, readTokens)
            q9(end+1,:) = {s, st(k).line, strtrim(st(k).text)}; %#ok<SAGROW>
        end
    end
end
fprintf("\n== Q9 YYYY-MMDD の日付の変数を、読み込みのパス以外で使っている文（図の名前・タイトルの候補） ==\n");
disp(q9);

%% 7. P5・Q8：読むパス
p5Missing = READ_PATHS(~arrayfun(@(p) isfile(fullfile(rootFolder, "experiments", p)), READ_PATHS));
fprintf("\n== P5 計画の読むパス（plan.md 7.4）：無いもの %d 個 ==\n", numel(p5Missing));
fprintf("  experiments/%s\n", p5Missing);
check = addCheck(check, "P5", "plan.md 7.4 の読むパス（9個）", "無いもの 0 個", numel(p5Missing) + " 個", verdictOf(isempty(p5Missing)));

allScripts = tracked(startsWith(tracked, "scripts/") & endsWith(tracked, ".m") & ~contains(tracked, "/archive/") ...
    & ~startsWith(tracked, ["scripts/migration/","scripts/evaluation/resultsLayout/"]));
dateLits = searchFiles(rootFolder, allScripts, """\d{4}-\d{4}""", true);
q8 = table('Size', [0 3], 'VariableTypes', ["string","double","string"], 'VariableNames', ["file","line","missing"]);
for k = 1:height(dateLits)
    for d = string(regexp(dateLits.text(k), "(?<="")\d{4}-\d{4}(?="")", "match"))
        if ~isfolder(fullfile(rootFolder, "experiments", d))
            q8(end+1,:) = {dateLits.file(k), dateLits.line(k), "experiments/" + d + "/"}; %#ok<SAGROW>
        end
    end
end
fileLits = searchFiles(rootFolder, allScripts, "cycleResult_\w+?_\d{4}-\d{4}(_\d+)?\.mat", false);
for k = 1:height(fileLits)
    for f = string(regexp(fileLits.text(k), "cycleResult_\w+?_(\d{4}-\d{4})(_\d+)?\.mat", "match"))
        d = string(regexp(f, "\d{4}-\d{4}", "match", "once"));
        if ~isfile(fullfile(rootFolder, "experiments", d, f))
            q8(end+1,:) = {fileLits.file(k), fileLits.line(k), "experiments/" + d + "/" + f}; %#ok<SAGROW>
        end
    end
end
fprintf("\n== Q8 スクリプトに書かれた日付のフォルダ・cycleResult のファイル名で、無いもの ==\n");
disp(q8);
check = addCheck(check, "Q8", "スクリプト（コメントを含む）に書かれた YYYY-MMDD の日付の experiments/ のフォルダと cycleResult のファイル", ...
    "無いもの 0 個", height(q8) + " 個（日付 " + height(dateLits) + " 行、ファイル名 " + height(fileLits) + " 行を確かめた）", ...
    verdictOf(height(q8) == 0));

%% 8. P6・P7：README と文書
readme = readText(fullfile(rootFolder, "README.md"));
rl = splitlines(readme);
secRange = sectionRange(readme, "結果の置き場所と実行記録");
p6 = strings(0,1);
if isempty(secRange)
    p6(end+1) = "「結果の置き場所と実行記録」の節が無い";
    sec = "";
else
    sec = strjoin(rl(secRange(1):secRange(2)), newline);
    for e = EXPERIMENT_NAMES
        if isempty(regexp(sec, "(?<![A-Za-z0-9])" + e + "(?![A-Za-z0-9])", "once"))
            p6(end+1) = "実験名が無い：" + e; %#ok<SAGROW>
        end
    end
    RUNINFO_KEYS = ["schemaVersion","experiment","script","note","images","files","region","segmentation", ...
        "numImages","numSegments","lMask","preprocessing","bilateral","kernelSizes","spatialSigmas", ...
        "degreeOfSmoothing","upsampling","kind","queryStep","interpMethod","grooveBottom","methods","dThresh", ...
        "widthThresh","grooveSelection","method","replayFrom","tracking","tolerance","fitLength","snapRadius", ...
        "initLength","maxGapLength","minFitPoints","numGrooves","minSeedGap","reclickImages","histogram", ...
        "binWidth","thHistRatio","bandTol","manual","thHist","tol","hPrl","detrend","polyDegree","scope", ...
        "audio","rpm","ampDiv","other","meta","createdAt","commit","branch","dirty","matlabRelease","computerName"];
    for key = RUNINFO_KEYS
        if isempty(regexp(sec, "(?<![A-Za-z0-9])" + key + "(?![A-Za-z0-9])", "once"))
            p6(end+1) = "runInfo.json のキーが無い：" + key; %#ok<SAGROW>
        end
    end
end
slugLine = rl(contains(rl, "slug") & contains(rl, "すでにある") & contains(rl, "合わせる"));
if isempty(slugLine), p6(end+1) = "実験名の決め方の1行（slug が既存の名前と違うときは既存の名前に合わせる）が無い"; end
mapRange = sectionRange(readme, "対応表");
if isempty(mapRange)
    p6(end+1) = "「対応表」の節が無い";
else
    mapSec = strjoin(rl(mapRange(1):mapRange(2)), newline);
    oldFolders = ["0710","0721","0724","0731","0802","0807","0817","0820","0831","0924","1013","1014", ...
        "1022","1026","1028","1104","1110","1111","1118"];
    for o = oldFolders
        if ~contains(mapSec, o), p6(end+1) = "対応表に古いフォルダが無い：" + o; end %#ok<SAGROW>
    end
    if ~contains(mapSec, "slides/202609asj"), p6(end+1) = "対応表にスライド用の図の移動が無い"; end
end
reverseLine = rl(~cellfun(@isempty, regexp(cellstr(rl), "階層.*逆|逆.*階層", "once")));
if isempty(reverseLine), p6(end+1) = "スクリプトと図とで階層の順が逆になることの記述が見つからない"; end
fprintf("\n== P6 README ==\n");
fprintf("  実験名の決め方の1行：%s\n", slugLine);
fprintf("  階層の順の記述：%s\n", reverseLine);
fprintf("  外れ：%s\n", p6);
check = addCheck(check, "P6", "README：節、実験名8つ、決め方の1行（Q6）、runInfo.json のキー、版の表、対応表、階層の順", ...
    "外れ 0 件（版の表と記述の中身は B が読む）", numel(p6) + " 件", verdictOf(isempty(p6)));

p7 = strings(0,1);
figuresMd = readText(fullfile(rootFolder, "docs", "rules", "figures.md"));
if ~contains(figuresMd, "figureDir"), p7(end+1) = "figures.md に figureDir が無い"; end
if ~contains(figuresMd, "resultDir"), p7(end+1) = "figures.md に resultDir が無い"; end
fl = splitlines(figuresMd);
if ~any(contains(fl, "#28") & contains(fl, "例外")), p7(end+1) = "figures.md に #28 の例外の記録が無い"; end
cf = readText(fullfile(rootFolder, "docs", "refactoring", "common-functions.md"));
f1 = sectionText(cf, "F1");
h1 = sectionText(cf, "H1");
if ~(contains(f1, "#28") && contains(f1, "figureDir")), p7(end+1) = "common-functions.md の F1 に #28・figureDir が無い"; end
if ~contains(h1, "resultDir"), p7(end+1) = "common-functions.md の H1 に resultDir が無い"; end
for f = ["CLAUDE.md","docs/rules/data.md","docs/rules/coding.md","docs/rules/evaluation.md"]
    if ~contains(readText(fullfile(rootFolder, f)), "resultDir"), p7(end+1) = f + " に resultDir が無い"; end %#ok<SAGROW>
end
gi = strtrim(splitlines(readText(fullfile(rootFolder, ".gitignore"))));
GITIGNORE_RULES = ["/results/*","!/results/figures/","/results/figures/*","!/results/figures/*/", ...
    "/results/figures/*/*","!/results/figures/*/slides/","!/results/figures/progress/*"];
pos = arrayfun(@(r) find(gi == r, 1), GITIGNORE_RULES, "UniformOutput", false);
if any(cellfun(@isempty, pos)) || ~issorted(cell2mat(pos))
    p7(end+1) = ".gitignore に issue の規則（7行）が、この順に無い";
end
if sum(gi == "# editor") ~= 1 || sum(gi == "/.vscode") ~= 1
    p7(end+1) = ".gitignore の # editor・/.vscode が1つずつでない";
end
fprintf("\n== P7 ほかの文書と .gitignore ==\n");
fprintf("  外れ：%s\n", p7);
check = addCheck(check, "P7", "figures.md・common-functions.md（F1・H1）・CLAUDE.md・data.md・coding.md・evaluation.md・.gitignore", ...
    "外れ 0 件", numel(p7) + " 件", verdictOf(isempty(p7)));

%% 9. Q5：git の追跡
lsAll = gitLines(rootFolder, "ls-files results");
nSlides = sum(startsWith(lsAll, SLIDES_MOVE(2) + "/"));
nProgress = sum(startsWith(lsAll, "results/figures/progress/"));
nOther = numel(lsAll) - nSlides - nProgress;
resDiff = gitLines(rootFolder, "diff -M --name-status " + BASE_COMMIT + " HEAD -- results");
renameOk = 0;
for k = 1:numel(resDiff)
    parts = split(resDiff(k), char(9));
    if numel(parts) == 3 && parts(1) == "R100" && startsWith(parts(2), SLIDES_MOVE(1) + "/") && ...
            parts(3) == SLIDES_MOVE(2) + "/" + extractAfter(parts(2), strlength(SLIDES_MOVE(1)) + 1)
        renameOk = renameOk + 1;
    end
end
IGNORE_CASES = [
    "results/figures/202609asj/paper/x.png",            "無視"
    "results/figures/202702thesis/paper/fig.pdf",       "無視"
    "results/grooveTracking/2026-1014/x.png",           "無視"
    "results/upsampling/2026-0731_origD/a.wav",         "無視"
    "results/0731/a.wav",                               "無視"
    "results/figures/x.png",                            "無視"
    "results/figures/202609asj/x.png",                  "無視"
    "experiments/2026-1014/x.mat",                      "無視"
    "temp/x.m",                                         "無視"
    "results/figures/202609asj/slides/x.png",           "追跡"
    "results/figures/202609asj/slides/sub/y.png",       "追跡"
    "results/figures/202702thesis/slides/a.png",        "追跡"
    "results/figures/progress/grooveTracking/x.png",    "追跡"
    "results/figures/progress/x.png",                   "追跡"];
actual = strings(size(IGNORE_CASES,1), 1);
for k = 1:size(IGNORE_CASES,1)
    st = system(sprintf('git -C "%s" check-ignore -q --no-index "%s"', rootFolder, IGNORE_CASES(k,1)));
    actual(k) = ifelse(st == 0, "無視", "追跡");
end
ign = table(IGNORE_CASES(:,1), IGNORE_CASES(:,2), actual, 'VariableNames', ["path","expected","actual"]);
fprintf("\n== Q5 git の追跡 ==\n");
fprintf("git ls-files results：%d（スライド用 %d、進捗報告用 %d、ほか %d）\n", numel(lsAll), nSlides, nProgress, nOther);
fprintf("git diff -M %s HEAD -- results：%d 行（R100 でスライド用の図の移動 %d 行）\n", BASE_COMMIT, numel(resDiff), renameOk);
disp(ign);
q5ok = numel(lsAll) == 144 && nSlides == 52 && nProgress == 92 && numel(resDiff) == 52 && renameOk == 52 ...
    && all(ign.expected == ign.actual) && isempty(porcelain);
check = addCheck(check, "Q5", "git ls-files results（144＝スライド用52＋進捗報告用92）、差分が R100 の移動52行だけ、check-ignore の14の例、作業ツリーがきれい", ...
    "すべて満たす", sprintf("%d（%d＋%d、ほか %d）、差分 %d 行（R100 %d）、例の不一致 %d、porcelain %d 行", ...
    numel(lsAll), nSlides, nProgress, nOther, numel(resDiff), renameOk, sum(ign.expected ~= ign.actual), numel(porcelain)), ...
    verdictOf(q5ok));

%% 10. 移行：P8・Q1・Q2・Q3・Q4・D3・D4
manifest = readManifest(MANIFEST_CSV);
mapping = readMapping(MAPPING_CSV);
expected = mapLocations(manifest.path, mapping, SLIDES_MOVE);
grp = groupOf(manifest.path);
moved = expected ~= manifest.path;

% P8：移すファイルの数
countTbl = table(["results の日付のフォルダ";"原稿用の図";"スライド用の図";"進捗報告用の図";"experiments（archive 以外）";"experiments/archive"], ...
    [603;55;52;92;12;3], [603;55;52;0;12;0], 'VariableNames', ["group","files","plannedMoved"]);
countTbl.actualFiles = arrayfun(@(g) sum(grp == g), countTbl.group);
countTbl.actualMoved = arrayfun(@(g) sum(grp == g & moved), countTbl.group);
fprintf("\n== P8 移すファイルの数（移す前の記録 %d 個と、対応表から求めた移し先） ==\n", height(manifest));
disp(countTbl);
destTbl = groupsummary(table(folderOf(expected(moved)), 'VariableNames', "destination"), "destination");
fprintf("行き先のフォルダごとの数（README の対応表・mapping-draft.md の「数」と比べる）：\n");
disp(destTbl);
leftover = manifest.path(~moved & ismember(grp, ["results の日付のフォルダ";"原稿用の図";"スライド用の図";"experiments（archive 以外）"]));
leftoverOk = all(startsWith(leftover, APPROVED_LEFTOVERS + "/"));
p8ok = isequal(countTbl.actualMoved, countTbl.plannedMoved) || (leftoverOk && ~isempty(APPROVED_LEFTOVERS));
check = addCheck(check, "P8", "対応表で移すファイルの数（results 603・原稿用 55・スライド用 52・experiments 12、進捗報告用 92 と archive 3 は動かさない）", ...
    "計画の数と同じ（承認B で残すと決めたものを除く）", strjoin(countTbl.group + " " + countTbl.actualMoved, "、"), verdictOf(p8ok));

% Q1・D3・D4：移した先にあり、中身が同じ
exists = arrayfun(@(p) isfile(fullfile(rootFolder, p)), expected);
sizeOk = false(size(expected));
shaOk = false(size(expected));
for k = 1:numel(expected)
    if exists(k)
        info = dir(fullfile(rootFolder, expected(k)));
        sizeOk(k) = info.bytes == manifest.bytes(k);
        if COMPUTE_SHA
            shaOk(k) = sha256File(fullfile(rootFolder, expected(k))) == manifest.sha256(k);
        else
            shaOk(k) = sizeOk(k); %#ok<UNRCH> COMPUTE_SHA で切り替える
        end
    end
end
approvedDel = false(size(expected));
if ~isempty(APPROVED_DELETIONS)
    approvedDel = startsWith(manifest.path, APPROVED_DELETIONS);
end
bad = ~(exists & sizeOk & shaOk) & ~approvedDel;
fprintf("\n== Q1 移す前のファイル %d 個：移し先に無い %d、大きさが違う %d、SHA-256 が違う %d（承認B で消すと決めたもの %d 個を除く） ==\n", ...
    numel(expected), sum(~exists & ~approvedDel), sum(exists & ~sizeOk), sum(exists & sizeOk & ~shaOk), sum(approvedDel));
disp(table(manifest.path(bad), expected(bad), exists(bad), 'VariableNames', ["before","expectedAfter","exists"]));
if any(approvedDel)
    fprintf("承認B で消すと決めたもの：\n");
    fprintf("  %s（移し先にある：%s）\n", [manifest.path(approvedDel), string(exists(approvedDel))]');
end
check = addCheck(check, "Q1", "移す前のファイル（817個）が、対応表どおりの場所に同じ大きさ・SHA-256 である" + ifelse(COMPUTE_SHA, "", "（SHA-256 は計算していない）"), ...
    "817/817（承認B で消すと決めたものを除く）", sum(~bad & ~approvedDel) + "/" + sum(~approvedDel) + ifelse(any(approvedDel), "（除いたもの " + sum(approvedDel) + "）", ""), ...
    verdictOf(~any(bad) && numel(bad) == 817 && COMPUTE_SHA));
isExp = startsWith(manifest.path, "experiments/");
check = addCheck(check, "D3", "experiments/ の15ファイル（改名したもの12、archive 3）の SHA-256 が改名の前と同じ", ...
    "15/15", sum(~bad & isExp) + "/" + sum(isExp), verdictOf(~any(bad & isExp) && sum(isExp) == 15 && COMPUTE_SHA));
isProg = startsWith(manifest.path, "results/figures/progress/");
check = addCheck(check, "D4b", "results/figures/progress/ の92ファイルが、同じ場所に同じ SHA-256 である", ...
    "92/92", sum(~bad & isProg & ~moved) + "/" + sum(isProg), verdictOf(~any(bad & isProg) && ~any(moved & isProg) && sum(isProg) == 92));

% Q2：移し先と experiments/ に、余計なファイルが無い
destFolders = unique([mapping.destination(mapping.phase == "results" & ismember(mapping.kind, ["dir","files"])); SLIDES_MOVE(2)]);
destFolders = destFolders(destFolders ~= "");
actualInDest = strings(0,1);
for d = destFolders'
    actualInDest = [actualInDest; listFiles(rootFolder, d)]; %#ok<AGROW>
end
actualInDest = unique(actualInDest);
expectedInDest = expected(startsWith(expected, destFolders + "/"));
extraDest = setdiff(actualInDest, expectedInDest);
actualExp = listFiles(rootFolder, "experiments");
extraExp = setdiff(actualExp, expected(isExp));
fprintf("\n== Q2 余計なファイル：移し先 %d 個、experiments/ %d 個 ==\n", numel(extraDest), numel(extraExp));
fprintf("  %s\n", [extraDest; extraExp]);
check = addCheck(check, "Q2", "対応表の移し先のフォルダと experiments/ にある、移す前の記録に無いファイル", ...
    "0 個", (numel(extraDest) + numel(extraExp)) + " 個", verdictOf(isempty(extraDest) && isempty(extraExp)));

% Q3：試しがすべて done、古い形のフォルダが残っていない
dryVerdict = "未実施"; %#ok<NASGU> RUN_MIGRATION_DRYRUN で切り替える
dryValue = "実行していない（RUN_MIGRATION_DRYRUN = false）"; %#ok<NASGU>
if RUN_MIGRATION_DRYRUN
    migrationDir = fullfile(rootFolder, "scripts", "migration");
    addpath(migrationDir);
    cleanupPath = onCleanup(@() rmpath(migrationDir));
    statuses = strings(0,1);
    for ph = ["results","experiments"]
        a = migrateResults(rootFolder, MAPPING_CSV, Phase=ph);
        statuses = [statuses; string(a.status)]; %#ok<AGROW>
    end
    clear cleanupPath
    dryValue = numel(statuses) + " 行のうち done 以外 " + sum(statuses ~= "done") + " 行";
    dryVerdict = verdictOf(all(statuses == "done"));
end
oldFolders = strings(0,1);
for parent = ["results","experiments"]
    l = dir(fullfile(rootFolder, parent));
    l = l([l.isdir] & ~ismember({l.name}, {'.','..'}));
    names = string({l.name});
    oldFolders = [oldFolders; parent + "/" + names(matches(names, regexpPattern("\d{4}")))']; %#ok<AGROW>
end
for d = ["results/figures/paper","results/figures/slides"]
    if isfolder(fullfile(rootFolder, d)), oldFolders(end+1) = d; end %#ok<SAGROW>
end
oldFolders = setdiff(oldFolders, APPROVED_LEFTOVERS);
fprintf("\n== Q3 migrateResults の試し：%s。古い形のフォルダ（承認B で残すもの %d 個を除く）：%d 個 ==\n", ...
    dryValue, numel(APPROVED_LEFTOVERS), numel(oldFolders));
fprintf("  %s\n", oldFolders);
check = addCheck(check, "Q3a", "migrateResults の試し（results・experiments の両方）の status", "すべて done", dryValue, dryVerdict);
check = addCheck(check, "Q3b", "古い形のフォルダ（results/・experiments/ の4桁の日付、results/figures/paper・slides）", ...
    "0 個（承認B で残すと決めたものを除く）", numel(oldFolders) + " 個", verdictOf(isempty(oldFolders)));

% Q4：名前の規則
q4 = strings(0,1);
RUN_PATTERN = "^\d{4}-\d{4}(_[A-Za-z0-9]*[A-Za-z][A-Za-z0-9]*)*(_\d+)?$";
for e = dirNames(rootFolder, "results", false)'
    q4(end+1) = "results/ の直下のファイル：" + e; %#ok<SAGROW>
end
for e = dirNames(rootFolder, "results", true)'
    if e == "figures" || ismember(e, APPROVED_LEFTOVERS.extractAfter("results/"))
        continue
    end
    if ~ismember(e, EXPERIMENT_NAMES)
        q4(end+1) = "実験名の一覧に無いフォルダ：results/" + e; %#ok<SAGROW>
        continue
    end
    for f = dirNames(rootFolder, "results/" + e, false)'
        q4(end+1) = "実験名のフォルダの直下のファイル：results/" + e + "/" + f; %#ok<SAGROW>
    end
    for r = dirNames(rootFolder, "results/" + e, true)'
        if ~matches(r, regexpPattern(RUN_PATTERN)) || ~isValidDate(extractBefore(r, 10))
            q4(end+1) = "実行フォルダの名前が規則に合わない：results/" + e + "/" + r; %#ok<SAGROW>
        end
    end
end
for f = dirNames(rootFolder, "results/figures", false)'
    q4(end+1) = "results/figures/ の直下のファイル：" + f; %#ok<SAGROW>
end
for v = dirNames(rootFolder, "results/figures", true)'
    if v == "progress", continue; end
    if ~matches(v, regexpPattern("^\d{6}[a-z]+$"))
        if ~ismember("results/figures/" + v, APPROVED_LEFTOVERS) && ~ismember(v, ["paper","slides"])
            q4(end+1) = "発表名の形でないフォルダ：results/figures/" + v; %#ok<SAGROW>
        end
        continue
    end
    others = setdiff([dirNames(rootFolder, "results/figures/" + v, true); dirNames(rootFolder, "results/figures/" + v, false)], ["paper";"slides"]);
    for o = others'
        q4(end+1) = "発表名のフォルダに paper・slides 以外がある：results/figures/" + v + "/" + o; %#ok<SAGROW>
    end
end
for f = dirNames(rootFolder, "experiments", false)'
    q4(end+1) = "experiments/ の直下のファイル：" + f; %#ok<SAGROW>
end
for d = dirNames(rootFolder, "experiments", true)'
    if d == "archive" || ismember("experiments/" + d, APPROVED_LEFTOVERS), continue; end
    if ~matches(d, regexpPattern("^\d{4}-\d{4}$")) || ~isValidDate(d)
        q4(end+1) = "experiments/ の日付のフォルダの名前が規則に合わない：" + d; %#ok<SAGROW>
        continue
    end
    for f = listFiles(rootFolder, "experiments/" + d)'
        [~, nm, ext] = fileparts(f);
        if startsWith(nm, "cycleResult_") && ~matches(nm + ext, regexpPattern("^cycleResult_\w+_" + d + "(_\d+)?(_dValue)?\.mat$"))
            q4(end+1) = "cycleResult のファイル名の日付がフォルダと違う：" + f; %#ok<SAGROW>
        end
    end
end
fprintf("\n== Q4 名前の規則：外れ %d 件 ==\n", numel(q4));
fprintf("  %s\n", q4);
check = addCheck(check, "Q4", "results/ の直下が実験名8つと figures だけ、実行フォルダ・発表名・experiments の日付・cycleResult の名前が規則どおり", ...
    "外れ 0 件", numel(q4) + " 件", verdictOf(isempty(q4)));

%% 11. 実データでの確認：Q10・Q11・Q12・Q9（E4）
% Q10（E1）：bilateralOri_centroid_1cycle.m のコピーで作った実行フォルダ
if E1_RUN_DIR == ""
    check = addCheck(check, "Q10", "実データの実行フォルダ・出力の名前・runInfo.json の値（bilateralOri_centroid_1cycle.m）", ...
        "8章のとおり", "E1_RUN_DIR が空", "未実施");
else
    q10 = strings(0,1);
    runAbs = fullfile(rootFolder, E1_RUN_DIR);
    [~, runName] = fileparts(E1_RUN_DIR);
    if ~startsWith(E1_RUN_DIR, "results/bilateralFilter/") || ~matches(runName, regexpPattern("^\d{4}-\d{4}_1cycle$"))
        q10(end+1) = "実行フォルダが results/bilateralFilter/<YYYY-MMDD>_1cycle でない：" + E1_RUN_DIR;
    end
    newNames = sort(setdiff(string({dir(fullfile(runAbs, "*.*")).name}), [".",".."]));
    refNames = sort(setdiff(string({dir(fullfile(rootFolder, E1_REF_DIR, "*.*")).name}), [".",".."]));
    if ~isequal(newNames, sort([refNames "runInfo.json"]))
        q10(end+1) = "出力のファイル名が " + E1_REF_DIR + " ＋ runInfo.json と違う（多い：" + ...
            strjoin(setdiff(newNames, [refNames "runInfo.json"]), ", ") + "／少ない：" + strjoin(setdiff([refNames "runInfo.json"], newNames), ", ") + "）";
    end
    info = jsondecode(readText(fullfile(runAbs, "runInfo.json")));
    fprintf("\n== Q10 %s/runInfo.json ==\n", E1_RUN_DIR);
    disp(flattenStruct(info, ""));
    imgs = "DSC1111-0000" + (1:8) + "-ori";
    prev = "experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat";
    expect = {
        "schemaVersion", 1
        "experiment", "bilateralFilter"
        "run", string(runName)
        "script", "scripts/bilateral/bilateralOri_centroid_1cycle.m"
        "inputs.images", imgs(:)
        "inputs.files", prev
        "conditions.segmentation.numImages", 8
        "conditions.segmentation.numSegments", 10
        "conditions.segmentation.lMask", 20
        "conditions.preprocessing.bilateral.kernelSizes", [3;5;9]
        "conditions.preprocessing.bilateral.spatialSigmas", [0.5;1;2]
        "conditions.preprocessing.bilateral.degreeOfSmoothing", 0.01*255^2
        "conditions.upsampling.kind", "origD"
        "conditions.grooveBottom.dThresh", 0.6
        "conditions.grooveBottom.widthThresh", 8
        "conditions.grooveSelection.manual.thHist", 150
        "conditions.grooveSelection.manual.tol", 3
        "conditions.grooveSelection.manual.binWidth", 5
        "conditions.grooveSelection.manual.hPrl", 8
        "meta.git.commit", headCommit
        "meta.git.dirty", false};
    optional = {
        "conditions.grooveBottom.methods", "centroid"
        "conditions.grooveSelection.method", "manual"
        "conditions.grooveSelection.replayFrom", prev};
    q10 = [q10(:); compareFields(info, expect, true); compareFields(info, optional, false)];
    fprintf("  外れ：%s\n", q10);
    check = addCheck(check, "Q10", "実データの実行フォルダ・出力の名前・runInfo.json の値（bilateralOri_centroid_1cycle.m）", ...
        "外れ 0 件", numel(q10) + " 件", verdictOf(isempty(q10)));
end

% Q11（E2）：同じ設定でもう一度実行したフォルダ
if E2_RUN_DIR == "" || E1_RUN_DIR == ""
    check = addCheck(check, "Q11", "同じ設定の2回目の実行が _2 の付いたフォルダになる（警告 resultDir:folderExists は B が記録）", ...
        "_2 が付き、runInfo.json の run も同じ", "E1_RUN_DIR・E2_RUN_DIR が空", "未実施");
else
    [~, n1] = fileparts(E1_RUN_DIR);
    [~, n2] = fileparts(E2_RUN_DIR);
    ok11 = string(n2) == string(n1) + "_2" && isfile(fullfile(rootFolder, E2_RUN_DIR, "runInfo.json"));
    if ok11
        info2 = jsondecode(readText(fullfile(rootFolder, E2_RUN_DIR, "runInfo.json")));
        ok11 = string(info2.run) == string(n2);
    end
    check = addCheck(check, "Q11", "同じ設定の2回目の実行が _2 の付いたフォルダになる（警告 resultDir:folderExists は B が記録）", ...
        "_2 が付き、runInfo.json の run も同じ", string(n2), verdictOf(ok11));
end

% Q12（E3）：pkCentroid_1cycle.m の書き換えで数値の出力が変わらない
if E3_CHECK_MAT == ""
    check = addCheck(check, "Q12", "pkCentroid_1cycle.m（1014 の手動選択の再現）の ycoords と conditions", ...
        "ycoords が isequal、conditions が isequaln（date・saveDir・experimentDir を除く）", "E3_CHECK_MAT が空", "未実施");
else
    chk = load(fullfile(rootFolder, E3_CHECK_MAT), "ycoords_cnt", "ycoords_max", "cond");
    ref = load(fullfile(rootFolder, E3_REF_MAT), "result");
    ref = ref.result;
    eqCnt = isequal(chk.ycoords_cnt, ref.centroid.ycoords);
    eqMax = isequal(chk.ycoords_max, ref.localMax.ycoords);
    DROP = ["date","saveDir","experimentDir"];
    eqCond = isequaln(rmfield(chk.cond, DROP), rmfield(ref.conditions, DROP));
    q12 = strings(0,1);
    if ~eqCnt, q12(end+1) = "ycoords（重心法）が違う"; end
    if ~eqMax, q12(end+1) = "ycoords（局所的最大値法）が違う"; end
    if ~eqCond
        q12(end+1) = "conditions が違う（フィールド：" + strjoin(diffFields(rmfield(chk.cond, DROP), rmfield(ref.conditions, DROP)), ", ") + "）";
    end
    if E3_RUN_DIR ~= ""
        info3 = jsondecode(readText(fullfile(rootFolder, E3_RUN_DIR, "runInfo.json")));
        c = chk.cond;
        expect3 = {
            "conditions.segmentation.lMask", c.lMask
            "conditions.grooveBottom.dThresh", c.dThresh
            "conditions.grooveBottom.widthThresh", c.wTh
            "conditions.grooveSelection.manual.thHist", c.thHist
            "conditions.grooveSelection.manual.tol", c.tol
            "conditions.grooveSelection.manual.binWidth", c.binWidth
            "conditions.grooveSelection.manual.hPrl", c.hPrl
            "conditions.upsampling.kind", "origD"
            "inputs.files", E3_REF_MAT
            "inputs.images", c.filenames(:)};
        q12 = [q12(:); compareFields(info3, expect3, true)];
        fprintf("\n== Q12 %s/runInfo.json ==\n", E3_RUN_DIR);
        disp(flattenStruct(info3, ""));
    else
        q12(end+1) = "E3_RUN_DIR が空（runInfo.json と cycleResult の conditions の照合をしていない）";
    end
    fprintf("\n== Q12：%s ==\n", strjoin(q12, "; "));
    check = addCheck(check, "Q12", "pkCentroid_1cycle.m（1014 の手動選択の再現）の ycoords・conditions と、runInfo.json の値", ...
        "ycoords が isequal、conditions が isequaln（date・saveDir・experimentDir を除く）、runInfo.json が conditions と同じ値", ...
        numel(q12) + " 件の外れ", verdictOf(isempty(q12)));
end

% Q9（E4）：図の名前のデータの日付
if E4_FIG_DIR == ""
    check = addCheck(check, "Q9", "図の名前のデータの日付が4桁（waveformManualVsTrack.m のコピー）と、日付の変数を使う文の一覧", ...
        "名前に _1014 があり 2026- が無い。一覧に図の名前・タイトルの文が無い（B が判断）", ...
        "E4_FIG_DIR が空。一覧 " + height(q9) + " 文", "未実施");
else
    l = dir(fullfile(rootFolder, E4_FIG_DIR));
    figNames = string({l(~[l.isdir]).name});
    okNames = ~isempty(figNames) && all(contains(figNames, "_1014")) && ~any(contains(figNames, "2026-"));
    fprintf("\n== Q9 %s の図 %d 個 ==\n", E4_FIG_DIR, numel(figNames));
    fprintf("  %s\n", figNames);
    check = addCheck(check, "Q9", "図の名前のデータの日付が4桁（waveformManualVsTrack.m のコピー）と、日付の変数を使う文の一覧", ...
        "名前に _1014 があり 2026- が無い。一覧に図の名前・タイトルの文が無い（B が判断）", ...
        "図 " + numel(figNames) + " 個で " + ifelse(okNames, "満たす", "満たさない") + "。一覧 " + height(q9) + " 文", ...
        ifelse(okNames, "B が判断", "満たさない"));
end

%% 12. U1：移した後の results/ の並び（ユーザーが見る）
fprintf("\n== U1 results/ の並び（実験名／実行フォルダ：ファイルの数） ==\n");
for e = dirNames(rootFolder, "results", true)'
    if e == "figures", continue; end
    runs = dirNames(rootFolder, "results/" + e, true);
    fprintf("%s/\n", e);
    for r = runs'
        fprintf("    %-45s %4d\n", r, numel(listFiles(rootFolder, "results/" + e + "/" + r)));
    end
end
fprintf("figures/\n");
for v = dirNames(rootFolder, "results/figures", true)'
    for u = dirNames(rootFolder, "results/figures/" + v, true)'
        fprintf("    %-45s %4d\n", v + "/" + u, numel(listFiles(rootFolder, "results/figures/" + v + "/" + u)));
    end
end

%% 13. 判定の表
check = addCheck(check, "T1", "cd test; results = runAllTests; の失敗・未完了", "0 件", "このスクリプトでは実行しない", "B が確かめる");
check = addCheck(check, "Q13", "書き換えていない bilateralOri_centroid_1cycle.m を実行すると resultDir:dateNotSet で止まり、何も作らない", ...
    "止まる、作らない", "このスクリプトでは実行しない", "B が確かめる");
ORDER = ["T","P","Q","D","U"];
[~, idCat] = ismember(extractBefore(check.id, 2), ORDER);
num = str2double(regexp(check.id, "\d+", "match", "once"));
[~, idx] = sortrows([idCat, num, double(endsWith(check.id, "b"))]);
check = check(idx, :);
fprintf("\n== 判定の表（%s、評価したコード %s） ==\n", string(datetime("now"), "yyyy-MM-dd HH:mm"), headCommit);
disp(check(:, ["id","threshold","value","verdict"]));
fprintf("（指標の文は criteria.md の同じ ID の行を見る）\n");
fprintf("満たさない：%d、B が判断・確かめる：%d、未実施：%d\n", sum(check.verdict == "満たさない"), ...
    sum(startsWith(check.verdict, "B が")), sum(check.verdict == "未実施"));


%% ローカル関数

function check = addCheck(check, id, metric, threshold, value, verdict)
    check(end+1,:) = {string(id), string(metric), string(threshold), string(value), string(verdict)};
end

function v = verdictOf(ok)
    if ok
        v = "満たす";
    else
        v = "満たさない";
    end
end

function v = ifelse(c, a, b)
    if c
        v = a;
    else
        v = b;
    end
end

function out = gitOut(rootFolder, args)
% git を実行して標準出力を返す（ASCII の出力に使う。日本語の中身は readText で読む）
    [status, out] = system(sprintf('git -C "%s" -c core.quotepath=false %s', rootFolder, args));
    if status ~= 0
        error("checkResultsLayout:gitFailed", "git %s が失敗しました：%s", args, out);
    end
    out = string(out);
end

function lines = gitLines(rootFolder, args)
    lines = splitlines(strtrim(gitOut(rootFolder, args)));
    lines = lines(lines ~= "");
end

function paths = nameStatusPaths(lines)
% git diff --name-status の行から、パスをすべて取り出す（名前を変えたものは両方）
    paths = strings(0,1);
    for k = 1:numel(lines)
        parts = split(lines(k), char(9));
        paths = [paths; parts(2:end)]; %#ok<AGROW>
    end
end

function tmp = gitShowToTemp(rootFolder, rev, path)
% 基準のコミットのファイルを、同じ名前で一時フォルダに書き出す（checkcode と UTF-8 の読み取りのため）
    [~, name, ext] = fileparts(path);
    folder = tempname;
    mkdir(folder);
    tmp = string(fullfile(folder, name + ext));
    status = system(sprintf('git -C "%s" show "%s:%s" > "%s"', rootFolder, rev, path, tmp));
    if status ~= 0
        error("checkResultsLayout:gitFailed", "git show %s:%s が失敗しました。", rev, path);
    end
end

function d = gitShowDiff(rootFolder, rev, path)
    tmp = string(tempname) + ".diff";
    system(sprintf('git -C "%s" diff -U0 %s HEAD -- "%s" > "%s"', rootFolder, rev, path, tmp));
    d = readText(tmp);
    delete(tmp);
end

function n = countCodeDiffLines(diffText)
% 差分のうち、コメント・空行でない行の数（+++・--- と @@ の行は数えない）
    lines = splitlines(string(diffText));
    body = lines(startsWith(lines, ["+","-"]) & ~startsWith(lines, ["+++","---"]));
    body = strtrim(extractAfter(body, 1));
    n = sum(body ~= "" & ~startsWith(body, "%"));
end

function files = baseGrepFiles(rootFolder, rev, pattern, isRegex)
% 基準のコミットで、pattern を含む scripts/ の .m（archive を除く）を返す
    if nargin < 4
        isRegex = false;
    end
    patFile = string(tempname) + ".txt";
    writelines(pattern, patFile, Encoding="UTF-8");
    flag = ifelse(isRegex, "-E", "-F");
    [status, out] = system(sprintf('git -C "%s" grep -l %s -f "%s" %s -- scripts ":!*/archive/*"', ...
        rootFolder, flag, patFile, rev));
    delete(patFile);
    if status > 1
        error("checkResultsLayout:gitFailed", "git grep が失敗しました：%s", out);
    end
    files = splitlines(strtrim(string(out)));
    files = files(files ~= "");
    files = extractAfter(files, rev + ":");
end

function txt = readText(path)
    txt = string(fileread(path, Encoding="UTF-8"));
end

function [code, isCont] = stripComment(line)
% 1行から、文字列の外の % 以降と ... 以降を除く。... があれば isCont = true
    chars = char(line);
    inDouble = false;
    inSingle = false;
    isCont = false;
    cutAt = numel(chars) + 1;
    k = 1;
    while k <= numel(chars)
        c = chars(k);
        if inDouble
            if c == '"'
                if k < numel(chars) && chars(k+1) == '"'
                    k = k + 1;
                else
                    inDouble = false;
                end
            end
        elseif inSingle
            if c == ''''
                if k < numel(chars) && chars(k+1) == ''''
                    k = k + 1;
                else
                    inSingle = false;
                end
            end
        elseif c == '"'
            inDouble = true;
        elseif c == ''''
            prev = strtrim(chars(1:k-1));
            if isempty(prev) || ~(isstrprop(prev(end), 'alphanum') || any(prev(end) == ')]}.''_"'))
                inSingle = true;
            end
        elseif c == '%'
            cutAt = k;
            break
        elseif c == '.' && k + 2 <= numel(chars) && all(chars(k:k+2) == '...')
            cutAt = k;
            isCont = true;
            break
        end
        k = k + 1;
    end
    code = string(chars(1:cutAt-1));
end

function st = codeStatements(txt)
% コメントを除き、続きの行（...）をつないだ文の一覧。.text と .line（最初の行の番号）
    lines = splitlines(string(txt));
    st = struct("text", {}, "line", {});
    buf = "";
    startLine = 0;
    inBlock = false;
    for k = 1:numel(lines)
        t = strtrim(lines(k));
        if t == "%{"
            inBlock = true;
            continue
        end
        if inBlock
            if t == "%}"
                inBlock = false;
            end
            continue
        end
        [code, isCont] = stripComment(lines(k));
        if buf == ""
            startLine = k;
        end
        buf = buf + " " + code;
        if ~isCont
            if strtrim(buf) ~= ""
                st(end+1) = struct("text", strtrim(buf), "line", startLine); %#ok<AGROW>
            end
            buf = "";
        end
    end
end

function calls = callsIn(st, fname)
% 文の一覧から fname(...) の呼び出しを探し、呼び出しごとに引数の文字列の配列を返す
    calls = {};
    for k = 1:numel(st)
        txt = char(st(k).text);
        [~, opens] = regexp(txt, "(?<![\w.])" + fname + "\s*\(", "start", "end");
        for o = opens
            calls{end+1} = splitArgs(txt, o); %#ok<AGROW>
        end
    end
end

function args = splitArgs(txt, openIdx)
% txt(openIdx) の '(' に対応する ')' までを、一番外のカンマで分ける
    depth = 0;
    inDouble = false;
    args = strings(1,0);
    cur = "";
    for k = openIdx:numel(txt)
        c = txt(k);
        if inDouble
            cur = cur + c;
            if c == '"'
                inDouble = false;
            end
            continue
        end
        switch c
            case '"'
                inDouble = true;
                cur = cur + c;
            case {'(','[','{'}
                depth = depth + 1;
                if depth > 1
                    cur = cur + c;
                end
            case {')',']','}'}
                depth = depth - 1;
                if depth == 0
                    args(end+1) = strtrim(cur); %#ok<AGROW>
                    return
                end
                cur = cur + c;
            case ','
                if depth == 1
                    args(end+1) = strtrim(cur); %#ok<AGROW>
                    cur = "";
                else
                    cur = cur + c;
                end
            otherwise
                cur = cur + c;
        end
    end
    args(end+1) = strtrim(cur);
end

function v = nameValueArg(args, name, nPositional)
% 引数の配列から name=値 か "name",値 の値の文字列を返す（無ければ ""）
    v = "";
    for k = nPositional+1:numel(args)
        tok = regexp(args(k), "^(\w+)\s*=(?!=)\s*(.+)$", "tokens", "once");
        if ~isempty(tok) && tok(1) == name
            v = tok(2);
            return
        end
        if matches(args(k), """" + name + """") && k < numel(args)
            v = args(k+1);
            return
        end
    end
end

function vals = resolveAll(expr, st)
% 文字列のリテラルならその値、変数ならすべての代入の右辺（リテラルなら値）を返す
    expr = strtrim(expr);
    lit = regexp(expr, "^""([^""]*)""$", "tokens", "once");
    if ~isempty(lit)
        vals = string(lit{1});
        return
    end
    if isempty(regexp(expr, "^[A-Za-z]\w*$", "once"))
        vals = "（式）" + expr;
        return
    end
    vals = strings(1,0);
    for k = 1:numel(st)
        tok = regexp(st(k).text, "(?:^|[;,]\s*)" + expr + "\s*=(?!=)\s*([^;]+)", "tokens");
        for t = tok
            rhs = strtrim(string(t{1}{1}));
            lit = regexp(rhs, "^""([^""]*)""$", "tokens", "once");
            if isempty(lit)
                vals(end+1) = "（式）" + rhs; %#ok<AGROW>
            else
                vals(end+1) = string(lit{1}); %#ok<AGROW>
            end
        end
    end
    if isempty(vals)
        vals = "（代入なし）" + expr;
    end
    vals = unique(vals, "stable");
end

function v = resolveValue(expr, st)
    vals = resolveAll(expr, st);
    v = strjoin(vals, " / ");
end

function T = searchFiles(rootFolder, files, pattern, codeOnly)
% ファイルの各行（codeOnly なら、コメントを除いたコード）で pattern を探す
    T = table('Size', [0 3], 'VariableTypes', ["string","double","string"], 'VariableNames', ["file","line","text"]);
    for f = files(:)'
        p = fullfile(rootFolder, f);
        if ~isfile(p)
            continue
        end
        lines = splitlines(readText(p));
        for k = 1:numel(lines)
            target = lines(k);
            if codeOnly
                target = stripComment(target);
            end
            if ~isempty(regexp(target, pattern, "once"))
                T(end+1,:) = {f, k, strtrim(lines(k))}; %#ok<AGROW>
            end
        end
    end
end

function r = sectionRange(txt, keyword)
% 見出しに keyword を含む最初の節の、見出しから次の同じか上の階層の見出しの前までの行番号
    lines = splitlines(string(txt));
    level = zeros(numel(lines),1);
    inFence = false;
    for k = 1:numel(lines)
        if startsWith(strtrim(lines(k)), "```")
            inFence = ~inFence;
        end
        tok = regexp(lines(k), "^(#+)\s", "tokens", "once");
        if ~inFence && ~isempty(tok)
            level(k) = strlength(tok(1));
        end
    end
    r = [];
    h = find(level > 0 & contains(lines, keyword), 1);
    if isempty(h)
        return
    end
    nxt = find(level > 0 & level <= level(h) & (1:numel(lines))' > h, 1);
    if isempty(nxt)
        nxt = numel(lines) + 1;
    end
    r = [h, nxt - 1];
end

function s = sectionText(txt, keyword)
    r = sectionRange(txt, keyword);
    lines = splitlines(string(txt));
    if isempty(r)
        s = "";
    else
        s = strjoin(lines(r(1):r(2)), newline);
    end
end

function hex = sha256File(p)
% ファイルの SHA-256 を16進の小文字で返す（16MB ずつ読む）。sha256sum と同じ値になることを確かめてある
    md = java.security.MessageDigest.getInstance("SHA-256");
    fid = fopen(p, "r");
    if fid < 0
        error("checkResultsLayout:cannotOpen", "開けません：%s", p);
    end
    c = onCleanup(@() fclose(fid));
    while true
        buf = fread(fid, 2^24, "*uint8");
        if isempty(buf)
            break
        end
        md.update(typecast(buf, "int8"));
    end
    h = typecast(md.digest(), "uint8");
    hex = lower(string(reshape(dec2hex(h, 2)', 1, [])));
end

function M = readManifest(path)
    io = detectImportOptions(path, "FileType", "text", "Delimiter", ",", "Encoding", "UTF-8");
    io = setvartype(io, ["path","sha256"], "string");
    io = setvartype(io, "bytes", "double");
    M = readtable(path, io);
end

function M = readMapping(path)
% 対応表（phase,kind,source,destination,note）を読む。空の欄は ""
    io = detectImportOptions(path, "FileType", "text", "Delimiter", ",", "Encoding", "UTF-8");
    io = setvartype(io, "string");
    M = readtable(path, io);
    for v = ["phase","kind","source","destination"]
        x = M.(v);
        x(ismissing(x)) = "";
        M.(v) = strtrim(x);
    end
end

function loc = mapLocations(paths, M, slidesMove)
% 移す前のパスに、対応表の行を順に当てはめて、移した後のパスを求める。
% files の行のパターンは、MATLAB の dir（Windows）と同じく * だけを使い、大文字・小文字を区別しない
    loc = paths;
    for r = 1:height(M)
        src = M.source(r);
        dst = M.destination(r);
        switch M.kind(r)
            case "dir"
                hit = startsWith(loc, src + "/");
                loc(hit) = dst + "/" + extractAfter(loc(hit), strlength(src) + 1);
            case "file"
                loc(loc == src) = dst;
            case "files"
                slash = strfind(src, "/");
                folder = extractBefore(src, slash(end));
                pat = extractAfter(src, slash(end));
                rx = "^" + replace(regexptranslate("escape", pat), "\*", ".*") + "$";
                names = extractAfter(loc, folder + "/");
                hit = startsWith(loc, folder + "/") & ~contains(names, "/");
                hit(hit) = ~cellfun(@isempty, regexpi(cellstr(names(hit)), rx, "once"));
                loc(hit) = dst + "/" + names(hit);
        end
    end
    hit = startsWith(loc, slidesMove(1) + "/");
    loc(hit) = slidesMove(2) + "/" + extractAfter(loc(hit), strlength(slidesMove(1)) + 1);
end

function g = groupOf(paths)
    g = strings(size(paths));
    g(startsWith(paths, "results/") & ~startsWith(paths, "results/figures/")) = "results の日付のフォルダ";
    g(startsWith(paths, "results/figures/paper/")) = "原稿用の図";
    g(startsWith(paths, "results/figures/slides/")) = "スライド用の図";
    g(startsWith(paths, "results/figures/progress/")) = "進捗報告用の図";
    g(startsWith(paths, "experiments/") & ~startsWith(paths, "experiments/archive/")) = "experiments（archive 以外）";
    g(startsWith(paths, "experiments/archive/")) = "experiments/archive";
end

function f = folderOf(paths)
    f = strings(size(paths));
    for k = 1:numel(paths)
        slash = strfind(paths(k), "/");
        f(k) = extractBefore(paths(k), slash(end));
    end
end

function files = listFiles(rootFolder, rel)
% rel の下のすべてのファイル（ルートからの / 区切りの相対パス）
    files = strings(0,1);
    p = fullfile(rootFolder, rel);
    if ~isfolder(p)
        return
    end
    l = dir(fullfile(p, "**", "*"));
    l = l(~[l.isdir]);
    if isempty(l)
        return
    end
    abs = string(fullfile({l.folder}, {l.name}))';
    files = replace(extractAfter(abs, strlength(rootFolder) + 1), "\", "/");
end

function names = dirNames(rootFolder, rel, wantDirs)
% rel の直下のフォルダ（wantDirs）かファイルの名前
    names = strings(0,1);
    p = fullfile(rootFolder, rel);
    if ~isfolder(p)
        return
    end
    l = dir(p);
    l = l(~ismember({l.name}, {'.','..'}));
    l = l([l.isdir] == wantDirs);
    names = string({l.name})';
end

function ok = isValidDate(d)
    try
        datetime(d, "InputFormat", "yyyy-MMdd");
        ok = true;
    catch
        ok = false;
    end
end

function T = flattenStruct(s, prefix)
% runInfo.json を「キー：値」の表にする（表示用）
    T = table('Size', [0 2], 'VariableTypes', ["string","string"], 'VariableNames', ["key","value"]);
    for f = string(fieldnames(s))'
        key = prefix + f;
        v = s.(f);
        if isstruct(v) && isscalar(v)
            T = [T; flattenStruct(v, key + ".")]; %#ok<AGROW>
        else
            T(end+1,:) = {key, valueText(v)}; %#ok<AGROW>
        end
    end
end

function t = valueText(v)
    if iscell(v)
        t = "[" + strjoin(cellfun(@(x) string(valueText(x)), v), ", ") + "]";
    elseif ischar(v) || isstring(v)
        t = string(v);
    elseif islogical(v)
        t = strjoin(string(v), ", ");
    elseif isempty(v)
        t = "[]";
    else
        t = strjoin(string(v(:)'), ", ");
    end
end

function problems = compareFields(info, expect, required)
% runInfo.json の値を、期待する値と比べる（数は 1e-9 まで、文字列の一覧は順も比べる）
    problems = strings(0,1);
    for k = 1:size(expect, 1)
        key = string(expect{k,1});
        want = expect{k,2};
        [has, got] = getPath(info, key);
        if ~has
            if required
                problems(end+1,1) = key + " が無い"; %#ok<AGROW>
            end
            continue
        end
        if isnumeric(want) || islogical(want)
            ok = (isnumeric(got) || islogical(got)) && numel(got) == numel(want) && ...
                all(abs(double(got(:)) - double(want(:))) <= 1e-9);
        else
            if iscell(got) || ischar(got)
                got = string(got);   % jsondecode は文字列を char、文字列の一覧を cell にする
            end
            ok = isstring(got) && isequal(got(:), string(want(:)));
        end
        if ~ok
            problems(end+1,1) = key + " が " + valueText(got) + "（期待 " + valueText(want) + "）"; %#ok<AGROW>
        end
    end
end

function [has, v] = getPath(s, key)
    v = s;
    has = true;
    for p = split(key, ".")'
        if isstruct(v) && isfield(v, p)
            v = v.(p);
        else
            has = false;
            v = [];
            return
        end
    end
end

function f = diffFields(a, b)
    f = strings(0,1);
    names = union(string(fieldnames(a)), string(fieldnames(b)));
    for n = names'
        if ~isfield(a, n) || ~isfield(b, n) || ~isequaln(a.(n), b.(n))
            f(end+1) = n; %#ok<AGROW>
        end
    end
end
