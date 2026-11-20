% compareWidthThresh.m
% issue #35 の評価スクリプト。自動追跡の3つのスクリプト（grooveTrack_1cycle.m・grooveHist_Ncycle.m・
% grooveTrack_Ncycle.m）で、溝底区間の幅（最後の行 − 最初の行）の上限 WIDTH_THRESH を 8（直す前）から
% 4（直した後）にしたときに、正規化した振幅が1付近の外れ値（溝底点の跳び）が消えるか、外れ値でない
% 点を変えていないかを、保存したクリック位置で ginput なしに作り直して比べる。
% 評価の項目・しきい値は docs/issues/closed/35-wide-bottom-outliers/criteria.md（ID は同じ）。
%
% 比べるデータ（どれも読むだけ。experiments/ には何も書かない）
%   t1014：experiments/1014/cycleResult_origD_track_1014.mat（grooveTrack_1cycle.m、1周）
%   h1104：experiments/1104/cycleResult_origD_hist5_1104.mat（grooveHist_Ncycle.m、5周。本実装）
%   t1104：experiments/1104/cycleResult_origD_track5_1104.mat（grooveTrack_Ncycle.m、5周。正解データ）
%   m1014：experiments/1014/cycleResult_origD_1014.mat（pkCentroid_1cycle.m の従来法。参考の比較だけ）
% 手順
%   1. 写真を reconstructImage で読み直し、3つのスクリプトの検出のループと同じ処理（ローカル関数
%      detectPhoto）で、幅の上限 8 と 4 のそれぞれで溝底点（重心法・局所的最大値法）と点ごとの幅を
%      求める。幅の上限 8 の点が、保存した pts と一致することを確かめる（R1・R2）。
%   2. 保存したクリック位置とパラメータで、それぞれのスクリプトと同じ溝の選択（trackGroove・
%      extractMultiGroove）をやり直し、写真ごとの9次デトレンドと振幅を作る。幅の上限 8 の結果が、
%      保存した yAbs・found・audio.signal と一致することを確かめる（R3・R4）。
%   3. 外れ値（局所的なずれ > 1 px）、|振幅| > 0.8・1、幅5以上の選んだ点、変わった列などを数え、
%      判定の表と一覧の表を表示する。
%   4. SAVE_OUTPUTS が true なら、表を CSV で、図（criteria.md の U1〜U4）を results/<OUT_DATE>/ に保存する。
% 局所的なずれ：選んだ点のデトレンド前の y から、前後10列（合わせて21列）で点を採れた列の y の
% 中央値を引いた値（plan-2.md 2.1）。点を採れずに補間した列では求めない。
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること）。
%       自動追跡の3つのスクリプトだけを対象にし、高解像度化しない画像（origD）だけを扱う。
% 2026/11/14作成（評価担当、issue #35）

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ（実行する人が書き換える場所）
OUT_DATE = "MMDD";        % 評価の日。図・表は results/<OUT_DATE>/
SAVE_OUTPUTS = true;      % 図（U1〜U4）と表（CSV）を results/<OUT_DATE>/ に保存する
% 直したスクリプトを temp/ のコピーで実行した結果（ワークスペースの y_comb_cnt・y_comb_max・cond を
% save した .mat のパス）。t1014 は grooveTrack_1cycle.m、h1104 は grooveHist_Ncycle.m、t1104 は
% grooveTrack_Ncycle.m。空文字のデータは R5 を確かめない（criteria.md 8章の手順4）
SCRIPT_CHECK_PATHS = struct("t1014", "", "h1104", "", "t1104", "");

%% パラメータ（評価の定義。変えるときは criteria.md の承認を取り直す）
DATA_KEYS  = ["t1014", "h1104", "t1104"];
DATA_DATES = ["1014", "1104", "1104"];
DATA_FILES = ["cycleResult_origD_track_1014.mat", "cycleResult_origD_hist5_1104.mat", ...
    "cycleResult_origD_track5_1104.mat"];
DATA_KIND  = ["track", "hist", "track"];  % 溝の選び方（図の名前の語にもなる）
MANUAL_DATE = "1014";                     % 従来法（参考の比較 S1）
MANUAL_FILE = "cycleResult_origD_1014.mat";

W_BEFORE = 8;           % 直す前の溝底区間の幅の上限 [px]（3つのスクリプトの今の値）
W_AFTER = 4;            % 直した後の値（issue #35）
WIDE_MIN = W_AFTER + 1; % 幅がこれ以上の選んだ点を「幅の広い点」（原因の量）とする [px]
DEV_WINDOW = 21;        % 局所的なずれの移動中央値の窓 [列]
DEV_TH = 1;             % 外れ値とする局所的なずれの絶対値 [px]（これを超えたら外れ値）
AMP_TH = [0.8 1];       % 参考に数える |振幅| のしきい値
RUN_JOIN_GAP = 2;       % 幅の広い点が続く区間で、つなぐすき間の列の数
EXACT = 1e-9;           % 一致・変わっていないとみなす誤差
NUM_SEGMENTS = 10;      % 写真1枚あたりの区間の数
METHODS = ["centroid", "localMax"];
BOUND = "inclBound";    % 溝底の判定。3つのデータは ad46b44 以降のコードで作った（criteria.md 2章）

% 品質の基準（criteria.md 4.4）
TH.MAX_GAP_PX = 40;     % 最も長い連続欠損 [px]（trackGroove の MaxGapLength。#25・#30 の基準）
TH.SHAPE_RMSE = 0.15;   % 直す前と後の溝形状（デトレンド後）の RMSE [px]。写真×溝ごと・全体（#25・#30 の基準）
TH.SHAPE_CORR = 0.80;   % 同、写真×溝ごとの相関係数（#25・#30 の基準）
TH.SHAPE_CORR_ALL = 0.90;  % 同、全体の相関係数（#25・#30 の基準）
% 幅の広い点の列での、重心法と局所的最大値法（直す前）の |差| の平均の上限は、変わらなかった
% 幅4以下の列（ふつうの列）の |差| の 平均 + LM_SE_MULT × 標準誤差（列の数は、幅の広い点の列の数）
TH.LM_SE_MULT = 3;

% 計画の値（plan-2.md 7.3・plan.md 7.3 と、評価基準の段階の試行。criteria.md 3.1）。値は直す前・直した後。
% 数えた値は一致、それ以外の値は差が PLAN_TOL 以下なら同じとみなす
PLAN_TOL = 5e-4;
PLAN.outliers   = struct("t1014", [1 0],  "h1104", [26 0],  "t1104", [25 0]);
PLAN.amp08      = struct("t1014", [2 1],  "h1104", [56 9],  "t1104", [55 9]);
PLAN.amp1       = struct("t1014", [1 0],  "h1104", [32 0],  "t1104", [31 0]);
PLAN.wide       = struct("t1014", [7 0],  "h1104", [104 0], "t1104", [103 0]);
PLAN.changed    = struct("t1014", [7 0 0], "h1104", [104 2 0], "t1104", [103 3 0]);  % (i)/(ii)/(iii)
PLAN.ampUnch    = struct("t1014", 0.0066, "h1104", 0.0245, "t1104", 0.0236);
PLAN.lmChanged  = 33;            % h1104 の局所的最大値法で変わった列
PLAN.lmAmp08    = [112 100];     % 同、|振幅| > 0.8
PLAN.lmAmp1     = [0 0];         % 同、|振幅| > 1
PLAN.maxGapCols = [10 15];       % h1104 の重心法の最も長い連続欠損 [列]
PLAN.dyOut      = 1.3912;        % h1104：外れ値だった列の y の変化の中央値 [px]
PLAN.dyNot      = [0.4504 1.2393];  % h1104：外れ値でなかった幅の広い点の列の、変化の中央値・最大 [px]
PLAN.lmMean     = struct("t1014", [0.7390 0.2689], "h1104", [0.8744 0.2161], "t1104", [0.8653 0.2174]);
PLAN.lmMax      = struct("t1014", [1.3935 0.4472], "h1104", [2.3201 0.6026], "t1104", [2.3201 0.6026]);

% 図（criteria.md 5章）
X_MARGIN = 30;          % 切り出しの、区間の両端から外への幅 [px]
Y_HALF = 14;            % 切り出しの、溝の y を中心にした高さの半分 [px]（隣の溝の手前まで）
MERGE_GAP = 30;         % これより近い区間は1枚の切り出しにまとめる [列]
LONG_RUN = 11;          % U3 の波形を作る区間の長さ [列]（外れ値を含まなくても、これ以上続けば作る）
WAVE_MARGIN_MS = 1;     % U3 の波形の、区間の両端から外への時間 [ms]
NUM_BOUNDARY_FIGS = 3;  % U4：データごとに、写真の境目の跳びの変化が大きい順に作る数
BOUNDARY_HALF_MS = 1;   % U4：境目の前後の時間 [ms]
STYLE = struct("figSizeCrop", [16 13], "figSizeWave", [16 8], "markerSize", 18, ...
    "colorAll", "cyan", "colorBefore", "yellow", "colorAfter", "magenta", ...
    "colorWaveBefore", [0.85 0.33 0.10], "colorWaveAfter", [0 0.45 0.74]);
% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD", "original", "inclBound", "inclusive bounds", "centroid", "centroid", ...
    "localMax", "local maximum", "track", "tracking", "hist", "histogram", ...
    "before", "width threshold " + W_BEFORE + " px", "after", "width threshold " + W_AFTER + " px");

%% 読み込み
if OUT_DATE == "MMDD"
    error("compareWidthThresh:dateNotSet", ...
        "OUT_DATE を評価の日（MMDD）にしてください。results/<日付>/ に同じ名前の図が無いことを確かめてください。");
end
if SAVE_OUTPUTS
    outDir = mkdirFromDate(rootFolder, OUT_DATE);
end

R = struct();
for d = 1:numel(DATA_KEYS)
    path = fullfile(experimentDir(rootFolder, DATA_DATES(d), Create=false), DATA_FILES(d));
    R.(DATA_KEYS(d)) = loadCycleResult(path);
    meta = R.(DATA_KEYS(d)).meta;
    fprintf("%s：%s\n       commit %s、gitDirty %d、スクリプト %s\n", DATA_KEYS(d), path, ...
        meta.gitCommit, meta.gitDirty, meta.scriptName);
end
manualPath = fullfile(experimentDir(rootFolder, MANUAL_DATE, Create=false), MANUAL_FILE);
manual = loadCycleResult(manualPath);
fprintf("m1014：%s\n       commit %s、gitDirty %d\n", manualPath, manual.meta.gitCommit, manual.meta.gitDirty);

% 4つのデータは、同じ写真・同じ検出のパラメータで作ったことを確かめる（写真は1度だけ読む）
cond = R.h1104.conditions;
for res = {R.t1014, R.t1104, manual}
    c = res{1}.conditions;
    if c.dThresh ~= cond.dThresh || c.lMask ~= cond.lMask || c.wTh ~= W_BEFORE || ...
            ~isequal(c.filenames, cond.filenames) || c.numImages ~= cond.numImages || ...
            c.numSegments ~= NUM_SEGMENTS || c.upsampling.kind ~= "origD"
        error("compareWidthThresh:conditionsMismatch", ...
            "データの検出の条件（dThresh・lMask・wTh・写真・区間の数・高解像度化）が同じではありません。");
    end
end
numImages = cond.numImages;
queryStep = R.h1104.grooveSelection.tracking.queryStep;
fs = R.h1104.centroid.audio.fs;

%% 1. 溝底点の検出（幅の上限 8 と 4）
fprintf("\n=== 溝底点の検出 ===\n");
DET = struct("before", {cell(numImages,1)}, "after", {cell(numImages,1)});
photos = cell(numImages,1);   % 写真1枚分の画素値（図に使う）
for i = 1:numImages
    imgs = reconstructImage(cond, i);
    photos{i} = [imgs.img];
    DET.before{i} = detectPhoto(imgs, cond.dThresh, W_BEFORE, queryStep);
    DET.after{i} = detectPhoto(imgs, cond.dThresh, W_AFTER, queryStep);
    fprintf("写真%d：溝底点 %d → %d 点（幅%d以上の点 %d）\n", i, size(DET.before{i}.pks.centroid,1), ...
        size(DET.after{i}.pks.centroid,1), WIDE_MIN, nnz(DET.before{i}.width >= WIDE_MIN));
end

rows = cell(0,6);   % 判定の表 {ID, 区分, 指標, しきい値, 実測値, 合格}

% R1：幅の上限 8 の点が、保存した pts と一致する（4つのファイル、両手法）
errR1 = 0;
for res = {R.t1014, R.h1104, R.t1104, manual}
    for m = METHODS
        for i = 1:numImages
            ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
            saved = mergeSegmentPoints(res{1}.(m).pts(ks), QueryStep=queryStep);
            errR1 = max(errR1, pointsError(saved, DET.before{i}.pks.(m)));
        end
    end
end
rows(end+1,:) = {"R1", "整合", "幅の上限 " + W_BEFORE + " で検出した溝底点と、4つのファイルの保存した pts（両手法・写真8枚）", ...
    "差 <= 1e-9（点の数も同じ）", sprintf("%.1e", errR1), errR1 <= EXACT};

% R2：幅の上限 4 の点は、幅の上限 8 の点のうち幅4以下のもの（並びも同じ）
okR2 = true;
for i = 1:numImages
    keep = DET.before{i}.width <= W_AFTER;
    for m = METHODS
        okR2 = okR2 && isequal(DET.after{i}.pks.(m), DET.before{i}.pks.(m)(keep,:));
    end
    okR2 = okR2 && isequal(DET.after{i}.width, DET.before{i}.width(keep));
end
rows(end+1,:) = {"R2", "整合", "幅の上限 " + W_AFTER + " の点 = 幅の上限 " + W_BEFORE + " の点のうち幅" + W_AFTER + "以下のもの（両手法、並びも同じ）", ...
    "isequal", string(okR2), okR2};

%% 2. 溝の選択とデトレンド（直す前と後）
fprintf("\n=== 溝の選択 ===\n");
SEL = struct();   % SEL.(データ).(before/after).(手法)：選択の結果
T = struct();     % T.(データ).(before/after).(手法)：列ごとの表（再生順）
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    trk = R.(key).grooveSelection.tracking;
    for p = ["before", "after"]
        for m = METHODS
            sel = selectGrooves(R.(key), DATA_KIND(d), DET.(p), m, NUM_SEGMENTS);
            shapes = cell(size(sel.yAbs));
            for k = 1:numel(sel.yAbs)
                [i, ~] = ind2sub(size(sel.yAbs), k);
                dt = detrendTrackedShape([DET.(p){i}.xQuery, sel.yAbs{k}], PolyDegree=trk.polyDegree);
                shapes{k} = dt(:,2);
            end
            yc = vertcat(shapes{:});   % 再生順（1本目の写真1〜8、2本目の写真1〜8、…）
            amp = (yc - mean(yc)) / trk.ampDivisor;
            SEL.(key).(p).(m) = sel;
            T.(key).(p).(m) = columnTable(sel, DET.(p), shapes, amp, fs, m, DEV_WINDOW);
            fprintf("%s・%s・%s：警告 %d 件\n", key, p, m, numel(sel.warnings));
            if ~isempty(sel.warnings)
                fprintf("    %s\n", sel.warnings);
            end
        end
    end
end

% R3・R4：直す前が、保存した結果を再現する
errY = 0; errF = 0; errC = 0; errA = 0;
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    gs = R.(key).grooveSelection;
    for m = METHODS
        sfx = suffixOf(m);
        if isfield(gs, "multiGroove")
            yS = gs.multiGroove.("yAbs" + sfx); fS = gs.multiGroove.("found" + sfx);
        else
            yS = gs.tracking.("yAbs" + sfx); fS = gs.tracking.("found" + sfx);
        end
        sel = SEL.(key).before.(m);
        for k = 1:numel(yS)
            errY = max(errY, max(abs(sel.yAbs{k} - yS{k})));
            errF = errF + nnz(sel.found{k} ~= fS{k});
        end
        if DATA_KIND(d) == "hist"
            errC = max(errC, max(abs(sel.centers - gs.multiGroove.("centers" + sfx)), [], "all"));
        end
        errA = max(errA, max(abs(T.(key).before.(m).amp - R.(key).(m).audio.signal)));
    end
end
rows(end+1,:) = {"R3", "整合", "直す前の溝の選択が、保存した yAbs・found（h1104 は centers も）を再現（3つのデータ、両手法）", ...
    "y・centers の差 <= 1e-9、found の不一致 0", sprintf("y %.1e、found %d、centers %.1e", errY, errF, errC), ...
    errY <= EXACT && errF == 0 && errC <= EXACT};
rows(end+1,:) = {"R4", "整合", "直す前の振幅が、保存した audio.signal を再現（3つのデータ、両手法）", ...
    "差 <= 1e-9", sprintf("%.1e", errA), errA <= EXACT};

% R5：直したスクリプト（temp/ のコピー）の結果が、このスクリプトの直した後と同じ
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    checkPath = string(SCRIPT_CHECK_PATHS.(key));
    if checkPath == ""
        continue
    end
    chk = load(checkPath, "y_comb_cnt", "y_comb_max", "cond");
    errS = max([abs(chk.y_comb_cnt - T.(key).after.centroid.shape); ...
        abs(chk.y_comb_max - T.(key).after.localMax.shape)]);
    okS = errS <= EXACT && chk.cond.wTh == W_AFTER;
    rows(end+1,:) = {"R5-" + key, "整合", key + "：直したスクリプト（" + chk.cond.scriptName + "）の y_comb（両手法）と conditions.wTh", ...
        "差 <= 1e-9、wTh = " + W_AFTER, sprintf("%.1e、wTh = %g", errS, chk.cond.wTh), okS}; %#ok<SAGROW>
end

%% 3. 数える
fprintf("\n=== 数える ===\n");
M = struct();
outlierList = table();
ampList = table();
runList = table();
shapeList = table();
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    for m = METHODS
        B = T.(key).before.(m);
        A = T.(key).after.(m);
        s = struct();
        s.outliers = [nnz(abs(B.dev) > DEV_TH), nnz(abs(A.dev) > DEV_TH)];
        s.amp08 = [nnz(abs(B.amp) > AMP_TH(1)), nnz(abs(A.amp) > AMP_TH(1))];
        s.amp1 = [nnz(abs(B.amp) > AMP_TH(2)), nnz(abs(A.amp) > AMP_TH(2))];
        s.wide = [nnz(B.found & B.width >= WIDE_MIN), nnz(A.found & A.width >= WIDE_MIN)];

        % 変わった列（デトレンド前の y の差が 1e-9 を超える列）を、直す前の列の状態で分ける
        ch = abs(A.y - B.y) > EXACT;
        s.changed = [nnz(ch & B.found & B.width >= WIDE_MIN), nnz(ch & ~B.found), ...
            nnz(ch & B.found & B.width <= W_AFTER)];
        s.numChanged = nnz(ch);
        dy = abs(A.y - B.y);
        isOut = abs(B.dev) > DEV_TH;
        notOut = B.found & B.width >= WIDE_MIN & ~isOut;
        s.dyOut = [median(dy(isOut)), max([dy(isOut); NaN])];
        s.dyNot = [median(dy(notOut)), max([dy(notOut); NaN])];
        s.numOutCols = nnz(isOut);
        s.numNotCols = nnz(notOut);
        s.ampUnch = max(abs(A.amp(~ch) - B.amp(~ch)));

        % 欠損と警告
        [s.missMax, s.maxGapCols] = deal([0 0]);
        for q = 1:2
            if q == 1, X = B; else, X = A; end
            g = findgroups(X.groove, X.photo);
            s.missMax(q) = max(splitapply(@(f) nnz(~f), X.found, g));
            s.maxGapCols(q) = max(splitapply(@longestRun, ~X.found, g));
        end
        s.warnings = [numel(SEL.(key).before.(m).warnings), numel(SEL.(key).after.(m).warnings)];

        % 溝形状（写真×溝ごと、デトレンド後）の RMSE・相関（直す前 vs 直した後）
        g = findgroups(B.groove, B.photo);
        [gr, ph] = splitapply(@(a, b) deal(a(1), b(1)), B.groove, B.photo, g);
        rm = splitapply(@(a, b) sqrt(mean((a - b).^2)), B.shape, A.shape, g);
        cr = splitapply(@corrOf, B.shape, A.shape, g);
        nCh = splitapply(@nnz, ch, g);
        shapeList = [shapeList; table(repmat(key, numel(gr), 1), repmat(m, numel(gr), 1), gr, ph, ...
            nCh, rm, cr, splitapply(@(f) nnz(~f), A.found, g), splitapply(@longestRun, ~A.found, g), ...
            'VariableNames', ["data","method","groove","photo","changedCols","rmse","corr", ...
            "missingAfter","maxGapColsAfter"])]; %#ok<AGROW>
        s.shapeRmseMax = max(rm);
        s.shapeCorrMin = min(cr);
        s.shapeAll = [sqrt(mean((A.shape - B.shape).^2)), corrOf(A.shape, B.shape)];

        % 外れ値と |振幅| > 0.8 の一覧
        for q = 1:2
            if q == 1, X = B; ph = "before"; else, X = A; ph = "after"; end
            k = find(abs(X.dev) > DEV_TH);
            outlierList = [outlierList; listRows(X, k, key, ph, m)]; %#ok<AGROW>
            k = find(abs(X.amp) > AMP_TH(1));
            ampList = [ampList; listRows(X, k, key, ph, m)]; %#ok<AGROW>
        end

        % 原因の量：直す前の幅の広い点が続く区間（RUN_JOIN_GAP 列以下のすき間はつなぐ）
        if m == "centroid"
            for gk = unique(g)'
                idx = find(g == gk);
                runs = runsOf(B.found(idx) & B.width(idx) >= WIDE_MIN, RUN_JOIN_GAP);
                for r = 1:size(runs,1)
                    k = idx(runs(r,1):runs(r,2));
                    runList = [runList; table(key, B.groove(k(1)), B.photo(k(1)), B.x(k(1)), B.x(k(end)), ...
                        numel(k), nnz(B.found(k) & B.width(k) >= WIDE_MIN), nnz(abs(B.dev(k)) > DEV_TH), ...
                        max(abs(B.dev(k)), [], "omitnan"), max(abs(B.amp(k))), max(abs(A.amp(k))), ...
                        max(dy(k)), B.timeMs(k(1)), B.timeMs(k(end)), ...
                        'VariableNames', ["data","groove","photo","xStart","xEnd","numCols","numWide", ...
                        "numOutliers","maxAbsDev","maxAbsAmpBefore","maxAbsAmpAfter","maxDy", ...
                        "tStartMs","tEndMs"])]; %#ok<AGROW>
                end
            end
        end
        M.(key).(m) = s;
    end

    % 重心法の点と、局所的最大値法の点（直す前）の差：幅の広い点の列と、変わらなかった幅4以下の列
    B = T.(key).before.centroid;
    A = T.(key).after.centroid;
    L = T.(key).before.localMax;
    ch = abs(A.y - B.y) > EXACT;
    sel = B.found & B.width >= WIDE_MIN & L.found;
    base = B.found & B.width <= W_AFTER & L.found & ~ch;
    dB = abs(B.y(sel) - L.y(sel));
    dA = abs(A.y(sel) - L.y(sel));
    d0 = abs(B.y(base) - L.y(base));
    M.(key).lm = struct("n", nnz(sel), "mean", [mean(dB), mean(dA)], "max", [max([dB; NaN]), max([dA; NaN])], ...
        "base", [mean(d0), prctile(d0, [50 75 90 95 99]), max(d0)], "nBase", nnz(base), ...
        "limit", mean(d0) + TH.LM_SE_MULT * std(d0) / sqrt(nnz(sel)));

    % ヒストグラムの山の中心と、帯の中に2点以上あった列
    if DATA_KIND(d) == "hist"
        for m = METHODS
            M.(key).(m).centersSame = max(abs(SEL.(key).after.(m).centers - SEL.(key).before.(m).centers), [], "all");
            M.(key).(m).numDup = [sum(SEL.(key).before.(m).numDup, "all"), sum(SEL.(key).after.(m).numDup, "all")];
        end
    end
end

% 1104 の hist5 と track5 は、直した後に同じになる（plan-2.md 2.3）
sameHT = struct();
for m = METHODS
    sameHT.(m) = isequal(T.h1104.after.(m).y, T.t1104.after.(m).y) && ...
        isequal(T.h1104.after.(m).found, T.t1104.after.(m).found);
end

%% 4. 判定の表
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    s = M.(key).centroid;
    rows(end+1,:) = planRow("P1-" + key, key + "・重心法：外れ値（局所的なずれ > " + DEV_TH + " px）の数", PLAN.outliers.(key), s.outliers); %#ok<SAGROW>
    rows(end+1,:) = planRow("P2-" + key, key + "・重心法：|振幅| > " + AMP_TH(1) + " のサンプル", PLAN.amp08.(key), s.amp08); %#ok<SAGROW>
    rows(end+1,:) = planRow("P3-" + key, key + "・重心法：|振幅| > " + AMP_TH(2) + " のサンプル", PLAN.amp1.(key), s.amp1); %#ok<SAGROW>
    rows(end+1,:) = planRow("P4-" + key, key + "・重心法：幅" + WIDE_MIN + "以上の選んだ点", PLAN.wide.(key), s.wide); %#ok<SAGROW>
    rows(end+1,:) = {"P5-" + key, "計画", key + "・重心法：変わった列（(i) 幅の広い点の列／(ii) 補間していた列／(iii) 幅" + W_AFTER + "以下の点の列）", ...
        mat2str(PLAN.changed.(key)), mat2str(s.changed), isequal(s.changed, PLAN.changed.(key))}; %#ok<SAGROW>
    rows(end+1,:) = {"P6-" + key, "計画", key + "・重心法：y が変わらなかった列の、振幅の変化の最大", ...
        sprintf("%.4f（差 <= %g）", PLAN.ampUnch.(key), PLAN_TOL), sprintf("%.5f", s.ampUnch), ...
        abs(s.ampUnch - PLAN.ampUnch.(key)) <= PLAN_TOL}; %#ok<SAGROW>
end
rows(end+1,:) = {"P7", "計画", "直した後の h1104 と t1104 の、デトレンド前の y と点を採れた列（重心法）", ...
    "isequal", sprintf("重心法 %d（参考：局所的最大値法 %d）", sameHT.centroid, sameHT.localMax), sameHT.centroid};
sc = M.h1104.centroid; sl = M.h1104.localMax;
okP8 = sc.centersSame <= EXACT && sl.centersSame <= EXACT && isequal(sc.numDup, [0 0]) && ...
    isequal(sc.maxGapCols, PLAN.maxGapCols);
rows(end+1,:) = {"P8", "計画", "h1104：山の中心（両手法）が変わらない、帯の中に2点以上ある列（重心法）、最も長い連続欠損（重心法）[列]", ...
    "差 <= 1e-9、0 → 0、" + PLAN.maxGapCols(1) + " → " + PLAN.maxGapCols(2), ...
    sprintf("差 %.1e・%.1e、%d → %d、%d → %d", sc.centersSame, sl.centersSame, sc.numDup, sc.maxGapCols), okP8};
okP9 = sl.numChanged == PLAN.lmChanged && isequal(sl.amp08, PLAN.lmAmp08) && isequal(sl.amp1, PLAN.lmAmp1);
rows(end+1,:) = {"P9", "計画", "h1104・局所的最大値法：変わった列、|振幅| > 0.8、|振幅| > 1", ...
    sprintf("%d、%d → %d、%d → %d", PLAN.lmChanged, PLAN.lmAmp08, PLAN.lmAmp1), ...
    sprintf("%d、%d → %d、%d → %d", sl.numChanged, sl.amp08, sl.amp1), okP9};
okP10 = all(abs([sc.dyOut(1), sc.dyNot] - [PLAN.dyOut, PLAN.dyNot]) <= PLAN_TOL);
rows(end+1,:) = {"P10", "計画", "h1104・重心法：y の変化 [px]。外れ値だった列の中央値／外れ値でなかった幅の広い点の列の中央値・最大", ...
    sprintf("%.4f／%.4f・%.4f（差 <= %g）", PLAN.dyOut, PLAN.dyNot, PLAN_TOL), ...
    sprintf("%.4f（%d列）／%.4f・%.4f（%d列）", sc.dyOut(1), sc.numOutCols, sc.dyNot, sc.numNotCols), okP10};
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    lm = M.(key).lm;
    okP11 = all(abs([lm.mean, lm.max] - [PLAN.lmMean.(key), PLAN.lmMax.(key)]) <= PLAN_TOL);
    rows(end+1,:) = {"P11-" + key, "計画", key + "：幅の広い点の列での、重心法と局所的最大値法（直す前）の |差| の平均・最大 [px]（直す前 → 後）", ...
        sprintf("平均 %.4f → %.4f、最大 %.4f → %.4f（差 <= %g）", PLAN.lmMean.(key), PLAN.lmMax.(key), PLAN_TOL), ...
        sprintf("平均 %.4f → %.4f、最大 %.4f → %.4f（%d列）", lm.mean, lm.max, lm.n), okP11}; %#ok<SAGROW>
end

for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    s = M.(key).centroid;
    rows(end+1,:) = {"Q1-" + key, "品質", key + "・重心法：直した後の外れ値（局所的なずれ > " + DEV_TH + " px）の数", ...
        "0", string(s.outliers(2)), s.outliers(2) == 0}; %#ok<SAGROW>
    c3 = [M.(key).centroid.changed(3), M.(key).localMax.changed(3)];
    rows(end+1,:) = {"Q2-" + key, "品質", key + "：変わった列のうち、直す前に幅" + W_AFTER + "以下の点を採っていた列（重心法・局所的最大値法）", ...
        "0・0", sprintf("%d・%d", c3), all(c3 == 0)}; %#ok<SAGROW>
    gapPx = [M.(key).centroid.maxGapCols(2), M.(key).localMax.maxGapCols(2)] * queryStep;
    wn = [M.(key).centroid.warnings(2), M.(key).localMax.warnings(2)];
    rows(end+1,:) = {"Q3-" + key, "品質", key + "：直した後の最も長い連続欠損 [px] と、溝の選択の警告（重心法・局所的最大値法）", ...
        "<= " + TH.MAX_GAP_PX + " px、警告 0", sprintf("%g・%g px、警告 %d・%d", gapPx, wn), ...
        all(gapPx <= TH.MAX_GAP_PX) && all(wn == 0)}; %#ok<SAGROW>
    lm = M.(key).lm;
    rows(end+1,:) = {"Q4-" + key, "品質", key + "：幅の広い点の列での、直した後の重心法と局所的最大値法（直す前）の |差| の平均 [px]", ...
        sprintf("<= %.3f（ふつうの列の平均 %.3f + %g × 標準誤差）", lm.limit, lm.base(1), TH.LM_SE_MULT), ...
        sprintf("%.3f（%d列。直す前 %.3f）", lm.mean(2), lm.n, lm.mean(1)), lm.mean(2) <= lm.limit}; %#ok<SAGROW>
    okQ5 = true; txt = strings(0,1);
    for m = METHODS
        s = M.(key).(m);
        okQ5 = okQ5 && s.shapeRmseMax <= TH.SHAPE_RMSE && s.shapeCorrMin >= TH.SHAPE_CORR && ...
            s.shapeAll(1) <= TH.SHAPE_RMSE && s.shapeAll(2) >= TH.SHAPE_CORR_ALL;
        txt(end+1) = sprintf("%s：RMSE 最大 %.4f・全体 %.4f、相関 最小 %.4f・全体 %.4f", m, ...
            s.shapeRmseMax, s.shapeAll(1), s.shapeCorrMin, s.shapeAll(2)); %#ok<SAGROW>
    end
    rows(end+1,:) = {"Q5-" + key, "品質", key + "：直す前と後の溝形状（デトレンド後）の RMSE [px]・相関（写真×溝ごと・全体、両手法）", ...
        "RMSE <= " + TH.SHAPE_RMSE + "（写真×溝ごと・全体）、相関 >= " + TH.SHAPE_CORR + "（写真×溝ごと）・" + ...
        TH.SHAPE_CORR_ALL + "（全体）", strjoin(txt, "／"), okQ5}; %#ok<SAGROW>
end

% 参考（判定には使わない）
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    s = M.(key).localMax;
    rows(end+1,:) = {"S2-" + key, "参考", key + "・局所的最大値法：外れ値、|振幅| > 0.8、|振幅| > 1、幅の広い点、変わった列", "—", ...
        sprintf("%d → %d、%d → %d、%d → %d、%d → %d、%d（%s）", s.outliers, s.amp08, s.amp1, s.wide, ...
        s.numChanged, mat2str(s.changed)), true}; %#ok<SAGROW>
    s = M.(key).centroid;
    rows(end+1,:) = {"S3-" + key, "参考", key + "・重心法：写真×溝ごとの点を採れなかった列の最大（直す前 → 後）", "—", ...
        sprintf("%d → %d", s.missMax), true}; %#ok<SAGROW>
    lm = M.(key).lm;
    rows(end+1,:) = {"S4-" + key, "参考", key + "：変わらなかった幅4以下の列での、重心法と局所的最大値法の |差|（平均・中央値・75・90・95・99パーセンタイル・最大）[px]", "—", ...
        sprintf("%s（%d列）", mat2str(round(lm.base, 3)), lm.nBase), true}; %#ok<SAGROW>
end

%% 従来法との比較（参考 S1。1014 の1本目だけ）
mp = manualPoints(manual, numImages, NUM_SEGMENTS, queryStep);
cmpTxt = strings(0,1);
for p = ["before", "after"]
    X = T.t1014.(p).centroid;
    cnt = zeros(1,4);   % 同じ点／追跡だけ／従来法だけ／違う点
    for i = 1:numImages
        Xi = X(X.photo == i, :);
        hasM = false(height(Xi),1); yM = NaN(height(Xi),1);
        [tf, loc] = ismember(mp{i}(:,1), Xi.x);
        hasM(loc(tf)) = true; yM(loc(tf)) = mp{i}(tf,2);
        same = Xi.found & hasM & abs(Xi.y - yM) <= EXACT;
        cnt = cnt + [nnz(same), nnz(Xi.found & ~hasM), nnz(~Xi.found & hasM), nnz(Xi.found & hasM & ~same)];
    end
    cmpTxt(end+1) = sprintf("%s：同じ点 %d、追跡だけ %d、従来法だけ %d、違う点 %d", p, cnt); %#ok<SAGROW>
end
rows(end+1,:) = {"S1", "参考", "t1014・重心法と従来法（m1014）の、同じ列で選んだ点", "—", strjoin(cmpTxt, "／"), true};

%% 写真の境目の跳び（参考 S5、U4 の図を選ぶ）
boundaryList = table();
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    B = T.(key).before.centroid;
    A = T.(key).after.centroid;
    last = find(diff([B.groove; NaN]) ~= 0 | diff([B.photo; NaN]) ~= 0);
    last = last(1:end-1);   % 最後のサンプルは境目ではない
    jB = B.amp(last+1) - B.amp(last);
    jA = A.amp(last+1) - A.amp(last);
    boundaryList = [boundaryList; table(repmat(key, numel(last), 1), B.groove(last), B.photo(last), ...
        B.groove(last+1), B.photo(last+1), B.timeMs(last), jB, jA, jA - jB, ...
        'VariableNames', ["data","grooveFrom","photoFrom","grooveTo","photoTo","timeMs", ...
        "jumpBefore","jumpAfter","jumpChange"])]; %#ok<AGROW>
    k = boundaryList.data == key;
    rows(end+1,:) = {"S5-" + key, "参考", key + "・重心法：写真の境目の振幅の跳びの変化（直した後 − 直す前）の最大の絶対値", "—", ...
        sprintf("%.4f（境目 %d か所）", max(abs(boundaryList.jumpChange(k))), nnz(k)), true}; %#ok<SAGROW>
end

%% 表示
resultTable = cell2table(rows, 'VariableNames', ["ID","区分","指標","しきい値","実測値","合格"]);
fprintf("\n=== 判定（数値の項目） ===\n");
disp(resultTable);
for kind = ["整合", "計画", "品質"]
    k = resultTable.("区分") == kind;
    fprintf("%s：%d/%d を満たす\n", kind, nnz(resultTable.("合格")(k)), nnz(k));
end
fprintf("\n=== 外れ値の一覧（局所的なずれ > %g px） ===\n", DEV_TH); disp(outlierList);
fprintf("\n=== 幅%d以上の選んだ点が続く区間（直す前、重心法。%d列以下のすき間はつなぐ） ===\n", WIDE_MIN, RUN_JOIN_GAP);
disp(runList);
fprintf("\n=== |振幅| > %g のサンプル ===\n", AMP_TH(1)); disp(ampList);
fprintf("\n=== 写真×溝ごと（直す前 vs 直した後） ===\n"); disp(shapeList);

if ~SAVE_OUTPUTS
    return %#ok<UNRCH> SAVE_OUTPUTS で切り替える
end

%% 5. 表と図を保存する
writetable(resultTable, fullfile(outDir, "evalWidthThresh_summary.csv"), "Encoding", "UTF-8");
writetable(outlierList, fullfile(outDir, "evalWidthThresh_outliers.csv"));
writetable(runList, fullfile(outDir, "evalWidthThresh_wideRuns.csv"));
writetable(ampList, fullfile(outDir, "evalWidthThresh_amp.csv"));
writetable(shapeList, fullfile(outDir, "evalWidthThresh_shapes.csv"));
writetable(boundaryList, fullfile(outDir, "evalWidthThresh_boundaries.csv"));

vsName = "wTh" + W_BEFORE + "VsWTh" + W_AFTER;
vsTitle = LABEL.before + " vs " + LABEL.after;
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    nG = size(SEL.(key).before.centroid.yAbs, 2);
    if nG > 1
        cycName = "_" + nG + "cyc"; cycTitle = ", " + nG + " cycles";
    else
        cycName = ""; cycTitle = "";
    end
    condName = "origD_" + BOUND + "_centroid_" + DATA_KIND(d) + cycName + "_" + DATA_DATES(d);
    condTitle = LABEL.origD + ", " + LABEL.(BOUND) + ", " + LABEL.centroid + ", " + ...
        LABEL.(DATA_KIND(d)) + cycTitle + ", data " + DATA_DATES(d);
    B = T.(key).before.centroid;
    A = T.(key).after.centroid;

    % 切り出す場所：幅の広い点が続く区間。t1104 は、h1104 と同じ場所（直す前に選んだ点がほぼ同じ）を除く
    crops = runList(runList.data == key, :);
    if key == "t1104"
        covered = false(height(crops),1);
        H = runList(runList.data == "h1104", :);
        for r = 1:height(crops)
            covered(r) = any(H.groove == crops.groove(r) & H.photo == crops.photo(r) & ...
                H.xStart <= crops.xEnd(r) & H.xEnd >= crops.xStart(r));
        end
        crops = crops(~covered, :);
    end
    crops = mergeCrops(crops, MERGE_GAP);

    for r = 1:height(crops)
        c = crops(r,:);
        i = c.photo; j = c.groove;
        k = find(B.groove == j & B.photo == i);
        xQ = B.x(k);
        xr = max(1, c.xStart - X_MARGIN) : min(numel(xQ), c.xEnd + X_MARGIN);
        yMid = round(median(B.y(k(xr))));
        yr = max(1, yMid - Y_HALF) : min(size(photos{i},1), yMid + Y_HALF);
        msRange = [floor(c.tStartMs), max(ceil(c.tEndMs), floor(c.tStartMs) + 1)];
        partName = "_img" + i;
        partTitle = "photo " + i;
        if nG > 1
            partName = partName + "_groove" + j;
            partTitle = partTitle + ", groove " + j;
        end
        selB = [B.x(k(B.found(k))), B.y(k(B.found(k)))];
        selA = [A.x(k(A.found(k))), A.y(k(A.found(k)))];
        % タイトルは図の幅に収まらないので3行に分ける（書く情報と順は、名前と同じ）
        fig = plotCrop(photos{i}, xr, yr, DET.before{i}.pks.centroid, selB, selA, [A.x(k), A.y(k)], ...
            STYLE, LABEL, ["Groove on image: " + vsTitle, "(" + condTitle + ",", ...
            partTitle + sprintf(", %d-%d ms)", msRange)]);
        saveAndClose(fig, outDir, "grooveOnImage_" + vsName + "_" + condName + partName + ...
            sprintf("_%d-%dms", msRange));

        % U3：外れ値を含む区間と、LONG_RUN 列以上続く区間の波形
        if c.numOutliers > 0 || c.numCols >= LONG_RUN
            tr = [floor(c.tStartMs - WAVE_MARGIN_MS), ceil(c.tEndMs + WAVE_MARGIN_MS)];
            fig = plotWave(B, A, tr, EXACT, STYLE, LABEL, ["Waveform: " + vsTitle, ...
                "(" + condTitle + ", " + partTitle + sprintf(", %d-%d ms)", tr)]);
            saveAndClose(fig, outDir, "waveform_" + vsName + "_" + condName + partName + ...
                sprintf("_%d-%dms", tr));
        end
    end

    % U4：写真の境目（跳びの変化が大きい順に NUM_BOUNDARY_FIGS か所）
    if key ~= "t1104"
        bl = boundaryList(boundaryList.data == key, :);
        [~, ord] = sort(abs(bl.jumpChange), "descend");
        for r = ord(1:min(NUM_BOUNDARY_FIGS, numel(ord)))'
            tr = [floor(bl.timeMs(r) - BOUNDARY_HALF_MS), ceil(bl.timeMs(r) + BOUNDARY_HALF_MS)];
            fig = plotWave(B, A, tr, EXACT, STYLE, LABEL, ["Waveform: " + vsTitle, ...
                "(" + condTitle + sprintf(", %d-%d ms)", tr)]);
            saveAndClose(fig, outDir, "waveform_" + vsName + "_" + condName + sprintf("_%d-%dms", tr));
        end
    end
end
fprintf("\n図・表の出力先：%s\n", outDir);


%% ローカル関数
function det = detectPhoto(imgs, dThresh, widthThresh, queryStep)
% 写真1枚分（区間の ImageData の配列 imgs）の溝底点を、自動追跡の3つのスクリプトの検出のループ
% （grooveHist_Ncycle.m の L128–145 など）と同じ処理で求め、mergeSegmentPoints で写真1枚分の
% [x y] にする。点ごとの溝底区間の幅（最後の行 − 最初の行 [px]。origD なので行の数のまま）も、
% 同じ並びで返す。出力 det のフィールド：pks.centroid・pks.localMax、width、xQuery、counts
    numSeg = numel(imgs);
    allPts_cnt(numSeg,1) = GroovePointCloud();
    allPts_max(numSeg,1) = GroovePointCloud();
    widthCells = cell(numSeg,1);
    for jSegment = 1:numSeg
        origImg = imgs(jSegment);
        origD = DarknessMap(origImg);
        origD = origD.setDiffTF(dThresh);

        pts_cnt = GroovePointCloud(origD);
        pts_max = GroovePointCloud(origD);
        colWidths = cell(origImg.width,1);

        extractor = GrooveExtractor(origD);
        for x = 1:origImg.width
            [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
            [extractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
                extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,widthThresh);

            centroidY = extractor.extractByCentroid(origD,x);
            maxY = extractor.extractByLocalMax(origD,x);

            pts_cnt.peakCells{x} = [x*ones(numPeaks,1), centroidY];
            pts_max.peakCells{x} = [x*ones(numPeaks,1), maxY];
            colWidths{x} = reshape(btmLastIdx - btmFirstIdx, [], 1);
        end

        allPts_cnt(jSegment) = pts_cnt;
        allPts_max(jSegment) = pts_max;
        widthCells{jSegment} = vertcat(zeros(0,1), colWidths{:});
    end
    [pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt, QueryStep=queryStep);
    pksMax = mergeSegmentPoints(allPts_max, QueryStep=queryStep);
    det = struct();
    det.pks = struct("centroid", pksCnt, "localMax", pksMax);
    det.width = vertcat(widthCells{:});
    det.xQuery = xQuery;
    det.counts = counts;
    if numel(det.width) ~= size(pksCnt,1)
        error("compareWidthThresh:widthCount", "幅の数（%d）が点の数（%d）と違います。", ...
            numel(det.width), size(pksCnt,1));
    end
end

function sel = selectGrooves(result, kind, det, method, numSegments)
% 保存したクリック位置とパラメータで、データを作ったスクリプトと同じ溝の選択をやり直す。
%   kind "hist"：extractMultiGroove（grooveHist_Ncycle.m）。始点は trackingSeeds の y
%   kind "track"：trackGroove。5周分（multiGroove.seedsY がある）は溝ごとに（grooveTrack_Ncycle.m）、
%                1周分は trackingSeeds の y で（grooveTrack_1cycle.m）
% 始点の x は、スクリプトと同じく写真の1列目にする。溝の選択の警告（trackGroove:longGap など）は、
% 呼び出しごとに lastwarn で拾って sel.warnings に書く。
    gs = result.grooveSelection;
    trk = gs.tracking;
    numImages = numel(det);
    trackArgs = {"Tolerance", trk.tolerance, "FitLength", trk.fitLength, "SnapRadius", trk.snapRadius, ...
        "InitLength", trk.initLength, "MaxGapLength", trk.maxGapLength};
    if kind == "hist"
        mg = gs.multiGroove;
        nG = mg.numGrooves;
        seeds = trackingSeeds(gs, numSegments);
        seedsY = seeds(:,2);
    elseif isfield(gs, "multiGroove")
        nG = gs.multiGroove.numGrooves;
        seedsY = gs.multiGroove.seedsY;
    else
        nG = 1;
        seeds = trackingSeeds(gs, numSegments);
        seedsY = seeds(:,2);
    end
    sel = struct();
    sel.yAbs = cell(numImages, nG);
    sel.found = cell(numImages, nG);
    sel.centers = NaN(numImages, nG);
    sel.numDup = zeros(numImages, nG);
    sel.warnings = strings(0,1);
    for i = 1:numImages
        pks = det{i}.pks.(method);
        xQ = det{i}.xQuery;
        if kind == "hist"
            lastwarn("");
            [~, info] = extractMultiGroove(pks, [xQ(1) seedsY(i)], xQ, nG, "TrackTolerance", trk.tolerance, ...
                "FitLength", trk.fitLength, "SnapRadius", trk.snapRadius, "InitLength", trk.initLength, ...
                "MaxGapLength", trk.maxGapLength, "PolyDegree", mg.polyDegree, "BinWidth", mg.binWidth, ...
                "MinPeakRatio", mg.thHistRatio, "BandTolerance", mg.bandTol);
            sel.warnings = [sel.warnings; warningText(i, 1)];
            for j = 1:nG
                sel.yAbs{i,j} = info.yAbs(:,j);
                sel.found{i,j} = info.found(:,j);
            end
            sel.centers(i,:) = info.centers';
            sel.numDup(i,:) = info.numDuplicateCols;
        else
            for j = 1:nG
                lastwarn("");
                [points, found] = trackGroove(pks, [xQ(1) seedsY(i,j)], xQ, trackArgs{:});
                sel.warnings = [sel.warnings; warningText(i, j)];
                sel.yAbs{i,j} = points(:,2);
                sel.found{i,j} = found;
            end
        end
    end
end

function s = warningText(iImg, jGroove)
% 直前の呼び出しで警告が出ていれば、その識別子と文を返す（無ければ空）
    [msg, id] = lastwarn;
    if isempty(msg)
        s = strings(0,1);
    else
        s = sprintf("写真%d・%d本目：%s（%s）", iImg, jGroove, id, msg);
    end
end

function T = columnTable(sel, det, shapes, amp, fs, method, devWindow)
% 列ごとの表を、再生順（1本目の写真1〜8、2本目の写真1〜8、…）に作る。
% 列：groove・photo・x（写真の中の列）、y（デトレンド前、補間済み）、found（点を採れたか）、
% width（採った点の溝底区間の幅。採れなかった列は NaN）、dev（局所的なずれ。採れなかった列は NaN）、
% shape（デトレンド後）、amp（正規化した振幅）、sample（サンプルの番号）、timeMs（sample/fs [ms]）
    [numImages, nG] = size(sel.yAbs);
    parts = cell(numImages, nG);
    for j = 1:nG
        for i = 1:numImages
            xQ = det{i}.xQuery;
            n = numel(xQ);
            y = sel.yAbs{i,j};
            f = sel.found{i,j};
            w = NaN(n,1);
            [tf, loc] = ismember([xQ(f) y(f)], det{i}.pks.(method), "rows");
            if ~all(tf)
                error("compareWidthThresh:pointNotDetected", ...
                    "写真%d・%d本目：選んだ点の中に、検出した溝底点に無い点があります。", i, j);
            end
            w(f) = det{i}.width(loc);
            yf = y;
            yf(~f) = NaN;
            dev = yf - movmedian(yf, devWindow, "omitnan");
            parts{i,j} = table(repmat(j,n,1), repmat(i,n,1), xQ, y, f, w, dev, shapes{i,j}, ...
                'VariableNames', ["groove","photo","x","y","found","width","dev","shape"]);
        end
    end
    T = vertcat(parts{:});
    T.amp = amp;
    T.sample = (1:height(T))';
    T.timeMs = T.sample / fs * 1e3;
end

function L = listRows(X, k, key, phase, method)
% 列ごとの表 X の行 k を、一覧の表の形にする
    n = numel(k);
    L = table(repmat(key,n,1), repmat(phase,n,1), repmat(method,n,1), X.groove(k), X.photo(k), X.x(k), ...
        X.width(k), X.dev(k), X.amp(k), X.timeMs(k), ...
        'VariableNames', ["data","phase","method","groove","photo","x","width","dev","amp","timeMs"]);
end

function pts = manualPoints(manual, numImages, numSegments, queryStep)
% 従来法（fitGroove で区間ごとに選んだ溝）が選んだ溝底点（重心法）を、保存したクリック位置で
% ginput なしに選び直し、写真1枚分の座標 [x y] で返す（scripts/progress/grooveOnImageManualAndTrack.m
% と同じ選び方）。選んだ点から作り直した y が、保存した ycoords と一致することを確かめる
    c = manual.conditions;
    sel = manual.grooveSelection;
    pts = cell(numImages,1);
    for i = 1:numImages
        ks = (i-1)*numSegments + (1:numSegments);
        [~, ~, ~, xOffsets] = mergeSegmentPoints(manual.centroid.pts(ks), QueryStep=queryStep);
        cells = cell(numSegments,1);
        for jSegment = 1:numSegments
            k = ks(jSegment);
            segPts = manual.centroid.pts(k);
            segPks = vertcat(segPts.peakCells{:});
            [p1, ~, pksCorCell] = fitGroove(jSegment, [], zeros(1,2), segPts.width, c.hPrl, {segPks}, ...
                P1=sel.p1(k,:), P2=sel.p2(k,:));
            pksCor = pksCorCell{1};
            grooveCenter = findGrooveCenter(pksCor, p1(2), BinWidth=c.binWidth, MinPeakHeight=c.thHist);
            inGroove = (pksCor(:,2) >= grooveCenter - c.tol) & (pksCor(:,2) <= grooveCenter + c.tol);
            shape = extractGrooveShape(pksCor, grooveCenter, (1:segPts.width)', Tolerance=c.tol);
            shape = detrendGrooveShape(shape, PolyDegree=c.polyDegree);
            if max(abs(shape(:,2) - manual.centroid.ycoords{k})) > 1e-9
                error("compareWidthThresh:manualMismatch", ...
                    "従来法の写真%d・区間%d：作り直した y が、保存した ycoords と違います。", i, jSegment);
            end
            cells{jSegment} = [segPks(inGroove,1) + xOffsets(jSegment), segPks(inGroove,2)];
        end
        pts{i} = vertcat(cells{:});
    end
end

function row = planRow(id, what, planned, measured)
% 「計画」の区分の行（直す前 → 直した後の数が、計画の値と同じか）
    row = {id, "計画", what + "（直す前 → 後）", sprintf("%d → %d", planned), ...
        sprintf("%d → %d", measured), isequal(planned, measured)};
end

function e = pointsError(a, b)
% 2つの点群 [x y] の差の最大（点の数が違えば Inf）
    if ~isequal(size(a), size(b))
        e = Inf;
    else
        e = max([abs(a - b); 0 0], [], "all");
    end
end

function runs = runsOf(mask, joinGap)
% mask が true の所を、joinGap 列以下のすき間をつないで区間にする。[始め 終わり]（mask の番号）
    idx = find(mask(:));
    if isempty(idx)
        runs = zeros(0,2);
        return
    end
    brk = find(diff(idx) > joinGap + 1);
    runs = [idx([1; brk+1]), idx([brk; numel(idx)])];
end

function n = longestRun(tf)
% true が続く最も長い長さ
    d = diff([0; tf(:); 0]);
    lens = find(d == -1) - find(d == 1);
    if isempty(lens)
        n = 0;
    else
        n = max(lens);
    end
end

function c = corrOf(a, b)
% Pearson の相関係数（同じなら1）
    if isequal(a, b)
        c = 1;
    else
        cc = corrcoef(a, b);
        c = cc(1,2);
    end
end

function s = suffixOf(method)
% grooveSelection の tracking・multiGroove のフィールド名の終わり（重心法 Cnt、局所的最大値法 Max）
    if method == "centroid"
        s = "Cnt";
    else
        s = "Max";
    end
end

function crops = mergeCrops(runs, mergeGap)
% 同じ溝・写真で、mergeGap 列より近い区間を1つにまとめる（1枚の切り出しにするため）
    crops = runs([],:);
    for r = 1:height(runs)
        c = runs(r,:);
        if ~isempty(crops) && crops.groove(end) == c.groove && crops.photo(end) == c.photo && ...
                c.xStart - crops.xEnd(end) <= mergeGap
            crops.xEnd(end) = c.xEnd;
            crops.numCols(end) = crops.xEnd(end) - crops.xStart(end) + 1;
            crops.numWide(end) = crops.numWide(end) + c.numWide;
            crops.numOutliers(end) = crops.numOutliers(end) + c.numOutliers;
            crops.tEndMs(end) = c.tEndMs;
        else
            crops = [crops; c]; %#ok<AGROW>
        end
    end
end

function fig = plotCrop(photo, xr, yr, pksAll, selB, selA, pathA, style, label, titleLines)
% 上の段に写真だけ、下の段に写真と、すべての溝底点（幅の上限 8）・直す前に選んだ点・直した後に選んだ点・
% 直した後の経路（補間した列を含む）を描く（docs/groove-on-image.md）。直した後の点を後に描くので、
% 直す前の色が見える点は、直したことで除いた点である
    fig = createFigure([0 0 style.figSizeCrop]);
    fig.Visible = "off";
    tl = tiledlayout(fig, 2, 1, Padding="compact", TileSpacing="compact");
    for t = 1:2
        ax = nexttile(tl);
        imagesc(ax, photo(yr, xr), XData=xr([1 end]), YData=yr([1 end]));
        colormap(ax, gray); clim(ax, [0 255]);   % 撮影画像の表示範囲は [0 255] に固定する
        axis(ax, "image");
        ylabel(ax, "$y$ [px]");
        ax.Toolbar.Visible = "off";
    end
    title(tl, titleLines, Interpreter="latex");
    inView = @(p) p(p(:,1) >= xr(1) & p(:,1) <= xr(end) & p(:,2) >= yr(1) & p(:,2) <= yr(end), :);
    pksAll = inView(pksAll);
    selB = inView(selB);
    selA = inView(selA);
    inX = pathA(:,1) >= xr(1) & pathA(:,1) <= xr(end);
    hold(ax, "on");
    h = gobjects(4,1);
    h(1) = scatter(ax, pksAll(:,1), pksAll(:,2), style.markerSize*0.5, style.colorAll, "filled");
    h(2) = scatter(ax, selB(:,1), selB(:,2), style.markerSize, style.colorBefore, "filled");
    h(3) = scatter(ax, selA(:,1), selA(:,2), style.markerSize, style.colorAfter, "filled");
    h(4) = plot(ax, pathA(inX,1), pathA(inX,2), "-", Color=style.colorAfter, LineWidth=0.8);
    hold(ax, "off");
    xlabel(ax, "$x$ [px]");
    lgd = legend(ax, h, ["all groove-bottom points", label.before, label.after, ...
        label.after + " (interpolated)"], Location="best", NumColumns=2, FontSize=7);
    lgd.ItemHitFcn = @togglevisibility;
end

function fig = plotWave(B, A, tr, exact, style, label, titleLines)
% 時間 tr [ms] の範囲の、直す前と後の振幅を重ねる。y が変わった列を印で示し、写真の境目に縦の点線を引く
    k = find(B.timeMs >= tr(1) & B.timeMs <= tr(2));
    fig = createFigure([0 0 style.figSizeWave]);
    fig.Visible = "off";
    tl = tiledlayout(fig, 1, 1, Padding="compact");
    ax = nexttile(tl);
    hold(ax, "on");
    h = gobjects(0,1);
    names = strings(0,1);
    h(end+1) = plot(ax, B.timeMs(k), B.amp(k), "-", Color=style.colorWaveBefore, LineWidth=1.2);
    names(end+1) = label.before;
    h(end+1) = plot(ax, A.timeMs(k), A.amp(k), "-", Color=style.colorWaveAfter, LineWidth=1);
    names(end+1) = label.after;
    ch = k(abs(A.y(k) - B.y(k)) > exact);
    if ~isempty(ch)
        h(end+1) = plot(ax, A.timeMs(ch), A.amp(ch), "o", Color=style.colorWaveAfter, MarkerSize=4);
        names(end+1) = "changed columns";
    end
    edges = k(diff([B.photo(k); NaN]) ~= 0 | diff([B.groove(k); NaN]) ~= 0);
    edges = edges(edges < k(end));
    hb = gobjects(0,1);
    for e = edges'
        hb(end+1) = xline(ax, (B.timeMs(e) + B.timeMs(e+1))/2, "k:", LineWidth=1); %#ok<AGROW>
    end
    if ~isempty(hb)
        h(end+1) = hb(1);
        names(end+1) = "photo boundary";
    end
    hold(ax, "off");
    grid(ax, "on");
    xlim(ax, tr);
    xlabel(ax, "Time [ms]");
    ylabel(ax, "Amplitude");
    title(ax, titleLines);
    legend(ax, h, names, Location="best", FontSize=8);
    ax.Toolbar.Visible = "off";
end

function saveAndClose(fig, outDir, name)
% saveFigure で png と fig を保存して閉じる。見えない図のまま fig を保存すると、開いたときにも
% 見えないので、開いたときに見えるようにしておく
    fig.CreateFcn = "set(gcbo,'Visible','on')";
    saveFigure(fig, outDir, name);
    close(fig);
end
