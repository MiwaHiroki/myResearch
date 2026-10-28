% compareHistToTracking.m
% issue #30 の評価スクリプト。写真ごとに1回のクリックからヒストグラムで N 本の溝を選ぶ
% 本実装（grooveHist_Ncycle.m の cycleResult_origD_hist<N>_<日付>.mat）を、N 本を
% trackGroove で別々に追跡した正解データ（grooveTrack_Ncycle.m の
% cycleResult_origD_track<N>_<日付>.mat）と比べる。1本目は #25 の1周分
% （experiments/1014/cycleResult_origD_track_1014.mat）とも比べる。
% 評価の項目・しきい値は docs/issues/30-multi-groove/criteria.md（ID は同じ）。
%
% - 比べ方は docs/rules/evaluation.md に従う（RMSE[px]・相関係数、写真×溝ごと・溝（周）ごと・
%   全体）。本実装（帯の点を補間）と正解（追跡）はどちらも仕組みの上で欠損しないので、
%   補わずにそのまま使う（NaN があれば数えて報告する）。前処理はどちらも写真ごと・溝ごとの
%   9次デトレンド（plan.md Q2 の (a)）なので、そのまま比べる。
% - 判定の表の「区分」：前提（満たさなければ評価の保留）、計画（計画の試行と同じ値になるかの
%   確認）、品質（手法として十分かの基準）、整合（保存と再現）、参考（判定に使わない）。
% - ginput は使わない。図・表は results/<OUT_DATE>/ に evalMulti_ で始まる名前で書く。
%   experiments/ には何も書かない。
% - experiments/ の SHA-256、変えてはいけないファイルの git diff、runAllTests、checkcode は
%   このスクリプトの外で確かめる（criteria.md の E7・T）。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       重ね描きの図で reconstructImage を使う）。src/ はプロジェクトのパスにある前提。
% 2026/10/27作成（評価担当、issue #30）

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ（実行する人が書き換える場所）
GT_DATE   = "MMDD";   % 正解データ experiments/<GT_DATE>/cycleResult_origD_track<N>_<GT_DATE>.mat
GT_FILE   = "";       % 正解データのファイル名。空なら上の既定の名前（RECLICK_IMAGES で作り直した "_2" 付きを使うときに書く）
HIST_DATE = "MMDD";   % 本実装 experiments/<HIST_DATE>/cycleResult_origD_hist<N>_<HIST_DATE>.mat
HIST_FILE = "";       % 本実装のファイル名。空なら上の既定の名前
OUT_DATE  = "MMDD";   % 図・表の出力先 results/<OUT_DATE>/
REF_PATH  = fullfile(rootFolder, "experiments", "1014", "cycleResult_origD_track_1014.mat");  % #25 の1周分（P3・E7d）
SAVE_FIGURES = true;  % 重ね描き・差・スペクトログラムの図を保存する

NUM_GROOVES  = 5;     % 評価に使う溝の本数（issue #30 の決定）
NUM_SEGMENTS = 10;    % 写真1枚あたりのセグメント数
METHODS = ["centroid","localMax"];

% しきい値（criteria.md の表と同じ値。変えるときは criteria.md の承認を取り直す）
TH.EXACT         = 1e-9;   % 一致・整合とみなす誤差
TH.P2_DEV        = 13;     % 正解の経路（1本目の多項式で補正）の、中央値からのずれの最大 [px]（溝の間隔の約半分）
TH.P2_GAP_MIN    = 13;     % 隣どうしの始点（y0）の差の最小 [px]（grooveTrack_Ncycle.m の MIN_SEED_GAP）
TH.P2_GAP_RATIO  = 1.5;    % 隣どうしの始点の差 ÷ その写真の差の中央値 の最大（溝を飛ばしていない）
TH.E2_PLAN_RMSE  = 0.02;   % 計画の試行で完全には一致しなかった1本（重心法・写真8・5本目）の RMSE [px]
TH.E2_PLAN_CORR  = 0.995;  % 同、相関係数
TH.E2_RMSE       = 0.15;   % 写真×溝ごとの RMSE [px]（品質）
TH.E2_CORR       = 0.80;   % 写真×溝ごとの相関係数（品質）
TH.E3_MISSING    = 20;     % 写真×溝ごとの、帯の中に点が無かった列の数（品質）
TH.E3_MAX_GAP    = 40;     % 最も長い連続欠損 [px]（品質）
TH.E3_LOST       = 20;     % 正解で採れて本実装で採れなかった列の数（品質）
TH.E4_PLAN_RMSE  = 0.004;  % 重心法の5周分の y_comb の RMSE [px]（計画）
TH.E4_PLAN_CORR  = 0.9999; % 同、相関係数（計画）
TH.E4_CORR       = 0.90;   % 5周分・周ごとの相関係数（品質）
TH.E4_RMSE       = 0.15;   % 5周分・周ごとの RMSE [px]（品質）
EXPECTED_FS      = 41729;  % 1周分の列の数 32099 と 78rpm から決まる標本化周波数 [Hz]

% 計画の試行の値（plan.md 付録 A.5・A.10）。「計画」の区分の確認に使う
PLAN.SEEDS_Y = [259.4 232.4 205.4 178.9 152.4
                288.4 262.4 235.9 210.4 183.9
                242.3 216.3 189.8 164.3 137.8
                241.6 214.6 187.6 160.6 133.6
                338.3 310.3 283.3 255.8 227.8
                266.0 240.0 214.5 189.0 162.5
                241.8 214.8 187.8 161.3 133.8
                248.5 220.0 192.5 164.5 136.0];
PLAN.CENTERS.centroid = [ 0.5 -27.5 -53.5 -80.5 -107.5
                         -0.5 -26.5 -52.5 -78.5 -104.5
                          0.5 -26.5 -52.5 -78.5 -104.5
                          0.5 -27.5 -54.5 -80.5 -108.5
                          0.5 -27.5 -55.5 -82.5 -110.5
                         -0.5 -26.5 -51.5 -77.5 -103.5
                          0.5 -27.5 -53.5 -80.5 -108.5
                         -0.5 -28.5 -56.5 -83.5 -112.5];
PLAN.CENTERS.localMax = PLAN.CENTERS.centroid;
PLAN.CENTERS.localMax([3 7], 1) = -0.5;
PLAN.MISSING.centroid = [0 0 0 4 0; 7 0 3 10 7; 6 6 2 2 0; 0 0 1 0 0
                         0 0 3 3 16; 4 0 0 1 0; 0 2 0 3 0; 0 2 0 0 0];
PLAN.MISSING.localMax = PLAN.MISSING.centroid;
PLAN.INEXACT.centroid = false(8, 5);  % 正解の作り方と完全には一致しない (i,j)
PLAN.INEXACT.centroid(8, 5) = true;   % x=2314 の1列だけ、帯が追跡では採らない点を採る
PLAN.INEXACT.localMax = false(8, 5);

%% 読み込み
if any([GT_DATE HIST_DATE OUT_DATE] == "MMDD")
    error("compareHistToTracking:dateNotSet", ...
        "GT_DATE・HIST_DATE・OUT_DATE を実行日（MMDD）にしてください。");
end
if GT_FILE == ""
    GT_FILE = "cycleResult_origD_track" + NUM_GROOVES + "_" + GT_DATE + ".mat";
end
if HIST_FILE == ""
    HIST_FILE = "cycleResult_origD_hist" + NUM_GROOVES + "_" + HIST_DATE + ".mat";
end
gtPath   = fullfile(experimentDir(rootFolder, GT_DATE, Create=false), GT_FILE);
histPath = fullfile(experimentDir(rootFolder, HIST_DATE, Create=false), HIST_FILE);

gt  = loadCycleResult(gtPath);
hs  = loadCycleResult(histPath);
ref = loadCycleResult(REF_PATH);
outDir = mkdirFromDate(rootFolder, OUT_DATE);

for src = ["正解", "本実装"]
    if src == "正解", R = gt; p = gtPath; else, R = hs; p = histPath; end
    fprintf("%-4s: %s\n      commit %s、gitDirty %d、保存 %s、スクリプト %s\n", src, p, ...
        R.meta.gitCommit, R.meta.gitDirty, string(R.meta.savedAt), R.meta.scriptName);
end
fprintf("#25  : %s\n", REF_PATH);

% 比べるのに要るフィールドが無ければ、ここで止める（criteria.md の E6a・E6e の不合格にあたる）
needTop = ["p1","p2","method","seeds","tracking","multiGroove"];
missingG = needTop(~isfield(gt.grooveSelection, needTop));
missingH = needTop(~isfield(hs.grooveSelection, needTop));
if ~isempty(missingG) || ~isempty(missingH)
    error("compareHistToTracking:missingFields", ...
        "grooveSelection にフィールドがありません（正解：%s、本実装：%s）。plan.md 4.4 の保存形式と違います。", ...
        strjoin(missingG, ", "), strjoin(missingH, ", "));
end
gsG = gt.grooveSelection;  mgG = gsG.multiGroove;
gsH = hs.grooveSelection;  mgH = gsH.multiGroove;
trkG = gsG.tracking;       trkH = gsH.tracking;
numImages = gt.conditions.numImages;
N = NUM_GROOVES;
if mgG.numGrooves ~= N || mgH.numGrooves ~= N
    error("compareHistToTracking:numGrooves", ...
        "溝の本数が NUM_GROOVES(%d) と違います（正解 %d、本実装 %d）。", N, mgG.numGrooves, mgH.numGrooves);
end

% 写真ごとの xQuery と、セグメントごとの列の数（保存した点群から作り直す）
xq = cell(numImages, 1);
counts = cell(numImages, 1);
for i = 1:numImages
    ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
    [~, xq{i}, counts{i}] = mergeSegmentPoints(hs.centroid.pts(ks), QueryStep=trkH.queryStep);
end

rows = cell(0, 6);   % 判定の表 {ID, 区分, 指標, しきい値, 実測値, 合格}
allFinite = @(c) all(cellfun(@(v) all(isfinite(v)), c(:)));

%% P：前提（正解データと、本実装のデータの作り方の確認）
fprintf("\n=== P：前提 ===\n");
okDirty = ~gt.meta.gitDirty && ~hs.meta.gitDirty;
rows(end+1,:) = {"P1", "前提", "正解・本実装とも作業ツリーがきれいな状態で作った（meta.gitDirty）", ...
    "どちらも false（commit は評価レポートで確かめる）", ...
    sprintf("正解 %d（%s）、本実装 %d（%s）", gt.meta.gitDirty, gt.meta.gitCommit, ...
    hs.meta.gitDirty, hs.meta.gitCommit), okDirty};

% P2：正解の経路の飛び移り（正解自身の1本目の多項式で補正した経路の、中央値からのずれ）と始点の間隔
devMax = zeros(numImages, N, 2);
for iM = 1:2
    m = METHODS(iM);
    yAbsG = mgG.(fieldFor(m, "yAbs"));
    foundG = mgG.(fieldFor(m, "found"));
    for i = 1:numImages
        [p, S, mu] = polyfit(xq{i}, yAbsG{i,1}, mgG.polyDegree);
        base = polyval(p, xq{i}, S, mu);
        for j = 1:N
            yc = yAbsG{i,j} - base;
            devMax(i,j,iM) = max(abs(yc - median(yc(foundG{i,j}))));
        end
    end
end
y0Gap = -diff(mgG.y0Cnt, 1, 2);
gapRatio = y0Gap ./ median(y0Gap, 2);
isSorted = all(diff(mgG.seedsY, 1, 2) < 0, "all");
[worstDev, iw] = max(devMax(:));
[wi, wj, wm] = ind2sub(size(devMax), iw);
rows(end+1,:) = {"P2a", "前提", "正解の経路（1本目の多項式で補正）の、中央値からのずれの最大 [px]", ...
    "< " + TH.P2_DEV + "（飛び移りなし。図 grooveTrackN_img*.png はユーザーが確かめる）", ...
    sprintf("%.2f（写真%d・%d本目・%s）", worstDev, wi, wj, METHODS(wm)), worstDev < TH.P2_DEV};
okGap = all(y0Gap >= TH.P2_GAP_MIN, "all") && all(gapRatio <= TH.P2_GAP_RATIO, "all") && isSorted;
rows(end+1,:) = {"P2b", "前提", "正解の隣どうしの始点 y0 の差（重心法）、seedsY が外側から並ぶ", ...
    ">= " + TH.P2_GAP_MIN + " px、差の中央値の " + TH.P2_GAP_RATIO + " 倍以下、降順", ...
    sprintf("%.1f〜%.1f px、比 %.2f〜%.2f、降順 %d", min(y0Gap(:)), max(y0Gap(:)), ...
    min(gapRatio(:)), max(gapRatio(:)), isSorted), okGap};

% P3：正解の1本目が #25（1014）と同じ溝・同じ結果
okRef = true;
for m = METHODS
    okRef = okRef && isequal(gt.(m).ycoords(:,1), ref.(m).ycoords) && ...
        isequal(trkG.(fieldFor(m, "yAbs")), ref.grooveSelection.tracking.(fieldFor(m, "yAbs")));
end
rows(end+1,:) = {"P3", "前提", "正解の1周目（ycoords(:,1)・tracking.yAbs）が 1014 と同じ（両手法）", ...
    "isequal", string(okRef), okRef};

% P4：本実装が正解の1本目のクリックを再現した
okSeeds = isequal(size(gsH.seeds), [numImages 2]) && ...
    isequal(gsH.seeds(:,2), gsG.seeds(:,2)) && all(gsH.seeds(:,1) == cellfun(@(v) v(1), xq));
rows(end+1,:) = {"P4", "前提", "本実装の seeds が [1列目, 正解の1本目のクリックのy]", ...
    "一致", string(okSeeds), okSeeds};

% P5：正解が、計画の試行の始点（seedsY）から追跡したものと同じ経路か。違う (i,j) は
% 「計画」の区分の確認から除き、「品質」の基準だけで判定する（criteria.md）
planApplies = false(numImages, N, 2);
for iM = 1:2
    m = METHODS(iM);
    yAbsG = mgG.(fieldFor(m, "yAbs"));
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        pks = mergeSegmentPoints(gt.(m).pts(ks), QueryStep=trkG.queryStep);
        for j = 1:N
            pts = trackGroove(pks, [xq{i}(1), PLAN.SEEDS_Y(i,j)], xq{i}, ...
                Tolerance=trkG.tolerance, FitLength=trkG.fitLength, SnapRadius=trkG.snapRadius, ...
                InitLength=trkG.initLength, MaxGapLength=trkG.maxGapLength);
            planApplies(i,j,iM) = isequal(pts(:,2), yAbsG{i,j});
        end
    end
end
[ni, nj, nk] = ind2sub(size(planApplies), find(~planApplies));
notApplied = compose("写真%d・%d本目・%s", ni, nj, METHODS(nk)');
rows(end+1,:) = {"P5", "参考", "正解が計画の試行の始点（seedsY）からの追跡と同じ経路の (i,j)", ...
    "違う (i,j) は「計画」の確認から除く", ...
    sprintf("%d/%d %s", nnz(planApplies), numel(planApplies), strjoin(notApplied, "、")), true};

%% E1〜E3：写真×溝ごとの比較
fprintf("\n=== E1〜E3：写真×溝ごと ===\n");
G = struct();   % 写真×溝×手法 の値（numImages x N x 2）
names = ["centerHist","centerGT","dCenter","halfSpacing","rmse","corr","corrNeighbor", ...
    "missHist","missGT","lost","extra","maxGapPx","numDup"];
for nm = names
    G.(nm) = NaN(numImages, N, 2);
end
shapeH = cell(numImages, N, 2);
shapeG = cell(numImages, N, 2);
numNaN = 0;
for iM = 1:2
    m = METHODS(iM);
    yAbsG = mgG.(fieldFor(m, "yAbs"));
    foundG = mgG.(fieldFor(m, "found"));
    foundH = mgH.(fieldFor(m, "found"));
    trendH = mgH.(fieldFor(m, "trend"));
    centersH = mgH.(fieldFor(m, "centers"));
    numDupH = mgH.(fieldFor(m, "numDup"));
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        tr = trendH{i};
        base = polyval(tr.p, xq{i}, tr.S, tr.mu);
        for j = 1:N
            shapeH{i,j,iM} = vertcat(hs.(m).ycoords{ks, j});
            shapeG{i,j,iM} = vertcat(gt.(m).ycoords{ks, j});
            yc = yAbsG{i,j} - base;
            G.centerGT(i,j,iM) = median(yc(foundG{i,j}));
            G.centerHist(i,j,iM) = centersH(i,j);
            G.missHist(i,j,iM) = nnz(~foundH{i,j});
            G.missGT(i,j,iM) = nnz(~foundG{i,j});
            G.lost(i,j,iM) = nnz(foundG{i,j} & ~foundH{i,j});
            G.extra(i,j,iM) = nnz(~foundG{i,j} & foundH{i,j});
            G.maxGapPx(i,j,iM) = longestRun(~foundH{i,j}) * trkH.queryStep;
            G.numDup(i,j,iM) = numDupH(i,j);
        end
        spacing = -diff(G.centerGT(i,:,iM));
        G.halfSpacing(i,:,iM) = min(spacing) / 2;
        for j = 1:N
            a = shapeH{i,j,iM}; b = shapeG{i,j,iM};
            numNaN = numNaN + nnz(isnan(a)) + nnz(isnan(b));
            [G.rmse(i,j,iM), G.corr(i,j,iM)] = rmseCorr(a, b);
            nb = [];
            for jj = [j-1, j+1]
                if jj >= 1 && jj <= N
                    [~, c] = rmseCorr(a, shapeG{i,jj,iM});
                    nb(end+1) = c; %#ok<SAGROW>
                end
            end
            G.corrNeighbor(i,j,iM) = max(nb);
        end
    end
end
G.dCenter = G.centerHist - G.centerGT;
fprintf("NaN の数（本実装・正解の ycoords）：%d\n", numNaN);
inner = repmat([false true(1, N-1)], numImages, 1);   % 2本目以降

for iM = 1:2
    m = METHODS(iM);
    % E1：同じ溝を選べているか
    okC = max(abs(mgH.(fieldFor(m, "centers")) - PLAN.CENTERS.(m)), [], "all") <= TH.EXACT;
    rows(end+1,:) = {"E1a", "計画", m + "：山の中心 centers（8x5）が計画の試行（plan.md A.5）と同じ", ...
        "一致", string(okC), okC}; %#ok<SAGROW>
    margin = G.halfSpacing(:,:,iM) - abs(G.dCenter(:,:,iM));
    [mn, k] = min(margin(:)); [wi, wj] = ind2sub([numImages N], k);
    rows(end+1,:) = {"E1b", "品質", m + "：|山の中心 − 正解の中心| < その写真の溝の間隔の最小の半分", ...
        "すべての (i,j)", sprintf("|差|の最大 %.3f px、余裕の最小 %.2f px（写真%d・%d本目）", ...
        max(abs(G.dCenter(:,:,iM)), [], "all"), mn, wi, wj), mn > 0}; %#ok<SAGROW>
    dOwn = G.corr(:,:,iM) - G.corrNeighbor(:,:,iM);
    [mn, k] = min(dOwn(:)); [wi, wj] = ind2sub([numImages N], k);
    rows(end+1,:) = {"E1c", "品質", m + "：正解の同じ溝との相関 > 隣の溝（j±1）との相関", ...
        "すべての (i,j)", sprintf("差の最小 %.3f（写真%d・%d本目）、隣との相関の最大 %.3f", ...
        mn, wi, wj, max(G.corrNeighbor(:,:,iM), [], "all")), mn > 0}; %#ok<SAGROW>

    % E2：形状の一致（2本目以降）
    applies = planApplies(:,:,iM) & inner;
    isExact = G.rmse(:,:,iM) <= TH.EXACT;
    expectExact = applies & ~PLAN.INEXACT.(m);
    okExact = all(isExact(expectExact));
    rows(end+1,:) = {"E2a", "計画", m + "：2本目以降で正解と完全に一致する (i,j)（RMSE <= 1e-9）", ...
        sprintf("計画の試行で一致した %d 本がすべて一致", nnz(expectExact)), ...
        sprintf("%d/%d（一致しない：%s）", nnz(isExact & expectExact), nnz(expectExact), ...
        listIJ(expectExact & ~isExact)), okExact}; %#ok<SAGROW>
    inexact = applies & PLAN.INEXACT.(m);
    if any(inexact(:))
        r = G.rmse(:,:,iM); c = G.corr(:,:,iM);
        ok = all(r(inexact) <= TH.E2_PLAN_RMSE) && all(c(inexact) >= TH.E2_PLAN_CORR);
        rows(end+1,:) = {"E2b", "計画", m + "：計画の試行でも完全には一致しなかった " + listIJ(inexact), ...
            "RMSE <= " + TH.E2_PLAN_RMSE + "、相関 >= " + TH.E2_PLAN_CORR, ...
            sprintf("RMSE %s、相関 %s", mat2str(r(inexact)', 4), mat2str(c(inexact)', 4)), ok}; %#ok<SAGROW>
    end
    r = G.rmse(:,:,iM); c = G.corr(:,:,iM);
    [mx, k] = max(r(inner)); idx = find(inner); [wi, wj] = ind2sub([numImages N], idx(k));
    rows(end+1,:) = {"E2c", "品質", m + "：2本目以降の写真×溝ごとの RMSE の最大 [px]", ...
        "<= " + TH.E2_RMSE, sprintf("%.4f（写真%d・%d本目）", mx, wi, wj), mx <= TH.E2_RMSE}; %#ok<SAGROW>
    [mn, k] = min(c(inner)); [wi, wj] = ind2sub([numImages N], idx(k));
    rows(end+1,:) = {"E2d", "品質", m + "：2本目以降の写真×溝ごとの相関係数の最小", ...
        ">= " + TH.E2_CORR, sprintf("%.4f（写真%d・%d本目）", mn, wi, wj), mn >= TH.E2_CORR}; %#ok<SAGROW>

    % E3：欠損
    miss = G.missHist(:,:,iM);
    okMiss = isequal(miss, PLAN.MISSING.(m));
    rows(end+1,:) = {"E3a", "計画", m + "：帯の中に点が無かった列の数（補間の前、8x5）が計画の試行と同じ", ...
        "一致（plan.md A.5 の表、1本目は #25 の [0 7 6 0 0 4 0 0]）", ...
        sprintf("一致 %d（違う：%s）", okMiss, listIJ(miss ~= PLAN.MISSING.(m))), okMiss}; %#ok<SAGROW>
    lost = G.lost(:,:,iM); extra = G.extra(:,:,iM);
    expExtra = double(PLAN.INEXACT.(m));
    ok = all(lost(planApplies(:,:,iM)) == 0) && all(extra(planApplies(:,:,iM)) == expExtra(planApplies(:,:,iM)));
    rows(end+1,:) = {"E3b", "計画", m + "：正解で採れて本実装で採れなかった列／その逆", ...
        "0 列／計画の試行と同じ（重心法の写真8・5本目だけ1列）", ...
        sprintf("合計 %d 列／合計 %d 列（%s）", sum(lost(:)), sum(extra(:)), listIJ(extra > 0)), ok}; %#ok<SAGROW>
    [mx, k] = max(miss(:)); [wi, wj] = ind2sub([numImages N], k);
    rows(end+1,:) = {"E3c", "品質", m + "：写真×溝ごとの、帯の中に点が無かった列の数の最大", ...
        "<= " + TH.E3_MISSING, sprintf("%d（写真%d・%d本目）", mx, wi, wj), mx <= TH.E3_MISSING}; %#ok<SAGROW>
    gap = G.maxGapPx(:,:,iM);
    [mx, k] = max(gap(:)); [wi, wj] = ind2sub([numImages N], k);
    rows(end+1,:) = {"E3d", "品質", m + "：最も長い連続欠損 [px]", ...
        "<= " + TH.E3_MAX_GAP, sprintf("%g（写真%d・%d本目）", mx, wi, wj), mx <= TH.E3_MAX_GAP}; %#ok<SAGROW>
    [mx, k] = max(lost(:)); [wi, wj] = ind2sub([numImages N], k);
    rows(end+1,:) = {"E3e", "品質", m + "：正解で採れて本実装で採れなかった列の数の最大", ...
        "<= " + TH.E3_LOST, sprintf("%d（写真%d・%d本目）", mx, wi, wj), mx <= TH.E3_LOST}; %#ok<SAGROW>
end

grooveTable = table();
for iM = 1:2
    [ii, jj] = ndgrid(1:numImages, 1:N);
    t = table(repmat(METHODS(iM), numImages*N, 1), ii(:), jj(:), ...
        'VariableNames', ["method","photo","groove"]);
    for nm = names
        v = G.(nm)(:,:,iM);
        t.(nm) = v(:);
    end
    v = planApplies(:,:,iM);
    t.planApplies = v(:);
    grooveTable = [grooveTable; t]; %#ok<AGROW>
end
fprintf("写真×溝ごと（dCenter=山の中心−正解の中心[px]、rmse[px]、miss=帯の中に点が無かった列、" + ...
    "lost=正解で採れて本実装で採れなかった列）\n");
disp(grooveTable(:, ["method","photo","groove","centerHist","dCenter","halfSpacing", ...
    "rmse","corr","corrNeighbor","missHist","lost","extra","maxGapPx","numDup"]));

%% E4：最終出力（N周分の y_comb、周ごと）
fprintf("\n=== E4：N周分の y_comb ===\n");
cycleTable = table();
for iM = 1:2
    m = METHODS(iM);
    a = hs.(m).y_comb; b = gt.(m).y_comb;
    [rAll, cAll] = rmseCorr(a, b);
    rC = zeros(N,1); cC = zeros(N,1);
    for j = 1:N
        [rC(j), cC(j)] = rmseCorr(vertcat(hs.(m).ycoords{:,j}), vertcat(gt.(m).ycoords{:,j}));
    end
    cycleTable = [cycleTable; table(repmat(m, N+1, 1), ["cycle " + (1:N)'; "all"], ...
        [rC; rAll], [cC; cAll], 'VariableNames', ["method","cycle","rmse","corr"])]; %#ok<AGROW>
    if all(planApplies(:,:,iM), "all")
        if m == "localMax"
            ok = rAll <= TH.EXACT;
            thr = "一致（RMSE <= 1e-9）";
        else
            ok = rAll <= TH.E4_PLAN_RMSE && cAll >= TH.E4_PLAN_CORR;
            thr = "RMSE <= " + TH.E4_PLAN_RMSE + "、相関 >= " + TH.E4_PLAN_CORR;
        end
        rows(end+1,:) = {"E4a", "計画", m + "：5周分の y_comb（全体）", thr, ...
            sprintf("RMSE %.4g、相関 %.6f", rAll, cAll), ok}; %#ok<SAGROW>
    end
    rows(end+1,:) = {"E4b", "品質", m + "：相関係数（全体と周ごとの最小）", ">= " + TH.E4_CORR, ...
        sprintf("全体 %.4f、周ごと %s", cAll, mat2str(cC', 4)), min([cAll; cC]) >= TH.E4_CORR}; %#ok<SAGROW>
    rows(end+1,:) = {"E4c", "品質", m + "：RMSE [px]（全体と周ごとの最大）", "<= " + TH.E4_RMSE, ...
        sprintf("全体 %.4f、周ごと %s", rAll, mat2str(rC', 4)), max([rAll; rC]) <= TH.E4_RMSE}; %#ok<SAGROW>
end
disp(cycleTable);

%% E5：1本目の一致
fprintf("\n=== E5：1本目 ===\n");
ok = true;
for m = METHODS
    ok = ok && isequal(hs.(m).ycoords(:,1), gt.(m).ycoords(:,1)) && ...
        isequal(trkH.(fieldFor(m, "yAbs")), trkG.(fieldFor(m, "yAbs"))) && ...
        isequal(trkH.(fieldFor(m, "found")), trkG.(fieldFor(m, "found")));
end
rows(end+1,:) = {"E5", "整合", "本実装の1周目（ycoords(:,1)・tracking.yAbs/found）が正解の1周目と同じ（両手法）", ...
    "isequal", string(ok), ok};

%% E6：保存と再現
fprintf("\n=== E6：保存と再現 ===\n");
numSegTotal = numImages * NUM_SEGMENTS;
colCounts = cellfun(@numel, hs.centroid.ycoords(:,1));
fsExpected = round(sum(colCounts) / (60 / hs.conditions.rpm));
needTrk = ["tolerance","fitLength","snapRadius","initLength","maxGapLength", ...
    "minFitPoints","queryStep","polyDegree","detrendScope","ampDivisor", ...
    "yAbsCnt","yAbsMax","foundCnt","foundMax"];

% 本実装の形式
needH = ["numGrooves","binWidth","thHistRatio","bandTol","polyDegree","detrendScope","ampDivisor", ...
    "centersCnt","centersMax","yAbsCnt","yAbsMax","foundCnt","foundMax","numDupCnt","numDupMax", ...
    "trendCnt","trendMax"];
okFmt = all(isfield(gsH, ["p1","p2","method","seeds","tracking","multiGroove"])) && ...
    all(isfield(trkH, needTrk)) && all(isfield(mgH, needH)) && gsH.method == "histogram" && ...
    isequal(size(gsH.p1), [numSegTotal 2]) && isequal(size(gsH.p2), [numSegTotal 2]);
if okFmt
    okFmt = mgH.binWidth == 1 && mgH.thHistRatio == 0.3 && mgH.bandTol == 3 && ...
        mgH.polyDegree == 9 && mgH.detrendScope == "photo" && mgH.ampDivisor == 1.5 && ...
        isequal(size(mgH.centersCnt), [numImages N]) && isequal(size(mgH.centersMax), [numImages N]) && ...
        isequal(size(mgH.numDupCnt), [numImages N]) && isequal(size(mgH.numDupMax), [numImages N]) && ...
        isequal(size(mgH.trendCnt), [numImages 1]) && isequal(size(mgH.trendMax), [numImages 1]) && ...
        all(cellfun(@(t) all(isfield(t, ["p","S","mu","degree"])), [mgH.trendCnt; mgH.trendMax]));
    for m = METHODS
        yA = mgH.(fieldFor(m, "yAbs")); fd = mgH.(fieldFor(m, "found"));
        okFmt = okFmt && isequal(size(yA), [numImages N]) && isequal(size(fd), [numImages N]) && ...
            all(cellfun(@islogical, fd(:))) && allFinite(yA) && ...
            isequal(size(hs.(m).ycoords), [numSegTotal N]) && isequal(size(hs.(m).xcoords), [numSegTotal N]) && ...
            numel(hs.(m).pts) == numSegTotal;
        for i = 1:numImages
            okFmt = okFmt && all(cellfun(@numel, yA(i,:)) == numel(xq{i}));
        end
    end
    c = hs.conditions;
    okFmt = okFmt && c.binWidth == mgH.binWidth && c.tol == mgH.bandTol && isnan(c.thHist) && ...
        isnan(c.hPrl) && c.polyDegree == mgH.polyDegree && c.upsampling.kind == "origD";
end
rows(end+1,:) = {"E6a", "整合", "本実装の grooveSelection・multiGroove・ycoords の形と値（plan.md 4.4）", ...
    "表のとおり", string(okFmt), okFmt};

% 本実装・正解の y_comb・audio・fs
for src = ["本実装", "正解"]
    if src == "本実装", R = hs; ampDiv = mgH.ampDivisor; else, R = gt; ampDiv = mgG.ampDivisor; end
    for m = METHODS
        yc = R.(m).y_comb;
        combErr = max(abs(yc - vertcat(R.(m).ycoords{:})));
        ampErr = max(abs(R.(m).audio.signal - (yc - mean(yc)) / ampDiv));
        fs = R.(m).audio.fs;
        ok = combErr <= TH.EXACT && ampErr <= TH.EXACT && fs == EXPECTED_FS && fs == fsExpected;
        id = "E6b"; if src == "正解", id = "E6f"; end
        rows(end+1,:) = {id, "整合", src + "・" + m + "：y_comb = vertcat(ycoords{:})、audio = (y_comb−mean)/ampDivisor、fs", ...
            "<= 1e-9、fs = " + EXPECTED_FS, sprintf("連結 %.1e、振幅 %.1e、fs %d", combErr, ampErr, fs), ok}; %#ok<SAGROW>
    end
end

% ycoords = 溝ごとに detrendTrackedShape(デトレンド前のy) を分けたもの（本実装・正解）
for src = ["本実装", "正解"]
    if src == "本実装", R = hs; mg = mgH; trk = trkH; else, R = gt; mg = mgG; trk = trkG; end
    err = 0;
    for m = METHODS
        yA = mg.(fieldFor(m, "yAbs"));
        err = max(err, max(abs(vertcat(yA{:,1}) - vertcat(trk.(fieldFor(m, "yAbs")){:}))));
        for i = 1:numImages
            ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
            for j = 1:N
                d = detrendTrackedShape([xq{i}, yA{i,j}], PolyDegree=mg.polyDegree);
                err = max(err, max(abs(d(:,2) - vertcat(R.(m).ycoords{ks, j}))));
                if ~isequal(cellfun(@numel, R.(m).ycoords(ks, j)), counts{i})
                    err = Inf;
                end
            end
        end
    end
    id = "E6c"; if src == "正解", id = "E6g"; end
    rows(end+1,:) = {id, "整合", src + "：ycoords = detrendTrackedShape(multiGroove.yAbs) を counts で分けたもの、yAbs(:,1) = tracking.yAbs", ...
        "<= 1e-9", sprintf("%.1e", err), err <= TH.EXACT}; %#ok<SAGROW>
end

% 本実装：保存した pts・seeds・パラメータだけで extractMultiGroove を実行し直す
errY = 0; errF = 0; errC = 0; errD = 0;
for m = METHODS
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        pks = mergeSegmentPoints(hs.(m).pts(ks), QueryStep=trkH.queryStep);
        [~, info] = extractMultiGroove(pks, gsH.seeds(i,:), xq{i}, N, ...
            TrackTolerance=trkH.tolerance, FitLength=trkH.fitLength, SnapRadius=trkH.snapRadius, ...
            InitLength=trkH.initLength, MaxGapLength=trkH.maxGapLength, PolyDegree=mgH.polyDegree, ...
            BinWidth=mgH.binWidth, MinPeakRatio=mgH.thHistRatio, BandTolerance=mgH.bandTol);
        yA = mgH.(fieldFor(m, "yAbs")); fd = mgH.(fieldFor(m, "found"));
        errY = max(errY, max(abs(info.yAbs - [yA{i,:}]), [], "all"));
        errF = errF + nnz(info.found ~= [fd{i,:}]);
        errC = max(errC, max(abs(info.centers' - mgH.(fieldFor(m, "centers"))(i,:))));
        errD = errD + nnz(info.numDuplicateCols ~= mgH.(fieldFor(m, "numDup"))(i,:));
    end
end
ok = errY <= TH.EXACT && errF == 0 && errC <= TH.EXACT && errD == 0;
rows(end+1,:) = {"E6d", "整合", "本実装：保存した pts・seeds・multiGroove のパラメータで extractMultiGroove を再実行", ...
    "y・centers <= 1e-9、found・numDup の不一致 0", ...
    sprintf("y %.1e、found %d、centers %.1e、numDup %d", errY, errF, errC, errD), ok};

% 正解の形式
needG = ["numGrooves","seedsY","y0Cnt","y0Max","minSeedGap","polyDegree","detrendScope", ...
    "ampDivisor","yAbsCnt","yAbsMax","foundCnt","foundMax"];
okFmt = all(isfield(gsG, ["p1","p2","method","seeds","tracking","multiGroove"])) && ...
    all(isfield(trkG, needTrk)) && all(isfield(mgG, needG)) && gsG.method == "tracking";
if okFmt
    okFmt = isequal(size(mgG.seedsY), [numImages N]) && isequal(size(mgG.y0Cnt), [numImages N]) && ...
        isequal(size(mgG.y0Max), [numImages N]) && isSorted && ...
        isequal(gsG.seeds, [cellfun(@(v) v(1), xq), mgG.seedsY(:,1)]) && ...
        isequal(trackingSeeds(gsG, NUM_SEGMENTS), gsG.seeds) && ...
        mgG.polyDegree == 9 && mgG.detrendScope == "photo" && mgG.ampDivisor == 1.5 && ...
        isequal(size(gsG.p1), [numSegTotal 2]);
    for m = METHODS
        okFmt = okFmt && isequal(size(mgG.(fieldFor(m, "yAbs"))), [numImages N]) && ...
            isequal(size(gt.(m).ycoords), [numSegTotal N]) && allFinite(mgG.(fieldFor(m, "yAbs")));
    end
end
rows(end+1,:) = {"E6e", "整合", "正解の grooveSelection・multiGroove の形（seedsY は外側から、seeds = [1, seedsY(:,1)]）", ...
    "表のとおり", string(okFmt), okFmt};

% 正解：保存した seedsY から trackGroove を実行し直す
errY = 0; errF = 0; errY0 = 0;
for iM = 1:2
    m = METHODS(iM);
    yA = mgG.(fieldFor(m, "yAbs")); fd = mgG.(fieldFor(m, "found")); y0 = mgG.(fieldFor(m, "y0"));
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        pks = mergeSegmentPoints(gt.(m).pts(ks), QueryStep=trkG.queryStep);
        for j = 1:N
            [pts, f, info] = trackGroove(pks, [xq{i}(1), mgG.seedsY(i,j)], xq{i}, ...
                Tolerance=trkG.tolerance, FitLength=trkG.fitLength, SnapRadius=trkG.snapRadius, ...
                InitLength=trkG.initLength, MaxGapLength=trkG.maxGapLength);
            errY = max(errY, max(abs(pts(:,2) - yA{i,j})));
            errF = errF + nnz(f ~= fd{i,j});
            errY0 = max(errY0, abs(info.y0 - y0(i,j)));
        end
    end
end
ok = errY <= TH.EXACT && errF == 0 && errY0 <= TH.EXACT;
rows(end+1,:) = {"E6h", "整合", "正解：保存した seedsY から trackGroove を再実行（yAbs・found・y0）", ...
    "<= 1e-9、不一致 0", sprintf("y %.1e、found %d、y0 %.1e", errY, errF, errY0), ok};

%% E7d：detrendTrackedShape の変更で、#25 の結果が変わらない
err = 0;
trkR = ref.grooveSelection.tracking;
for m = METHODS
    yA = trkR.(fieldFor(m, "yAbs"));
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        d = detrendTrackedShape([xq{i}, yA{i}], PolyDegree=trkR.polyDegree);
        if ~isequal(d(:,2), vertcat(ref.(m).ycoords{ks}))
            err = err + 1;
        end
    end
end
rows(end+1,:) = {"E7d", "整合", "1014 の tracking.yAbs に今の detrendTrackedShape をかけると 1014 の ycoords と同じ", ...
    "isequal（16枚）", sprintf("違う写真 %d", err), err == 0};

%% 参考（判定に使わない）
fprintf("\n=== 参考 ===\n");
spacingCnt = -diff(G.centerGT(:,:,1), 1, 2);
disp(table((1:numImages)', spacingCnt, 'VariableNames', ["photo","spacingPx"]));
fprintf("両手法の centers の差（重心法 − 局所的最大値法）：\n"); disp(mgH.centersCnt - mgH.centersMax);
for src = ["本実装", "正解"]
    if src == "本実装", R = hs; else, R = gt; end
    fprintf("%s：|振幅|>1 のサンプル 重心法 %d、局所的最大値法 %d（最大 %.3f / %.3f）\n", src, ...
        nnz(abs(R.centroid.audio.signal) > 1), nnz(abs(R.localMax.audio.signal) > 1), ...
        max(abs(R.centroid.audio.signal)), max(abs(R.localMax.audio.signal)));
end
fprintf("同じ列に2点以上あった列（本実装）：重心法 %d、局所的最大値法 %d\n", ...
    sum(mgH.numDupCnt(:)), sum(mgH.numDupMax(:)));
[rCM, cCM] = deal(zeros(numImages, N));
for i = 1:numImages
    for j = 1:N
        [rCM(i,j), cCM(i,j)] = rmseCorr(shapeG{i,j,1}, shapeG{i,j,2});
    end
end
fprintf("正解の重心法と局所的最大値法の差（写真×溝ごと）：RMSE %.3f〜%.3f px、相関 %.3f〜%.3f\n", ...
    min(rCM(:)), max(rCM(:)), min(cCM(:)), max(cCM(:)));

%% 判定の表
resultTable = cell2table(rows, 'VariableNames', ["ID","区分","指標","しきい値","実測値","合格"]);
fprintf("\n=== 判定（数値の項目） ===\n");
disp(resultTable);
isJudged = resultTable.("区分") ~= "参考";
fprintf("前提 %d/%d、計画 %d/%d、品質 %d/%d、整合 %d/%d を満たす\n", ...
    countPass(resultTable, "前提"), countKind(resultTable, "前提"), ...
    countPass(resultTable, "計画"), countKind(resultTable, "計画"), ...
    countPass(resultTable, "品質"), countKind(resultTable, "品質"), ...
    countPass(resultTable, "整合"), countKind(resultTable, "整合"));
fprintf("（数値の項目 %d/%d）\n", nnz(resultTable.("合格") & isJudged), nnz(isJudged));
writetable(resultTable, fullfile(outDir, "evalMulti_summary.csv"), "Encoding", "UTF-8");
writetable(grooveTable, fullfile(outDir, "evalMulti_grooves.csv"));
writetable(cycleTable, fullfile(outDir, "evalMulti_cycles.csv"));

%% 図（ユーザーが判断する項目 U1・U3 の補助）
if SAVE_FIGURES
    colors = lines(N);
    % 本実装（細い実線）と正解（太い半透明の線）の経路を、撮影画像に重ねる（重心法）。
    % 写真を横に4つに分けて並べる。本実装の帯に点が無かった列は×
    for i = 1:numImages
        imgs = reconstructImage(hs.conditions, i);
        photo = [imgs.img];
        yA = mgH.yAbsCnt(i,:); yG = mgG.yAbsCnt(i,:); fd = mgH.foundCnt(i,:);
        nCols = numel(xq{i});
        edgesX = round(linspace(0, nCols, 5));
        fig = figure('Visible', 'off', 'Position', [0 0 1800 1200]);
        tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
        for q = 1:4
            ax = nexttile(tl);
            cols = edgesX(q)+1:edgesX(q+1);
            yLo = max(1, floor(min([yA{N}(cols); yG{N}(cols)])) - 15);
            yHi = min(size(photo,1), ceil(max([yA{1}(cols); yG{1}(cols)])) + 15);
            imagesc(ax, xq{i}(cols), yLo:yHi, photo(yLo:yHi, cols)); colormap(ax, gray); hold(ax, "on");
            for j = 1:N
                plot(ax, xq{i}(cols), yG{j}(cols), '-', 'Color', [colors(j,:) 0.35], 'LineWidth', 3);
                plot(ax, xq{i}(cols), yA{j}(cols), '-', 'Color', colors(j,:), 'LineWidth', 0.6);
                miss = cols(~fd{j}(cols));
                plot(ax, xq{i}(miss), yA{j}(miss), 'x', 'Color', 'b', 'MarkerSize', 4);
            end
            if q == 1
                plot(ax, gsH.seeds(i,1), gsH.seeds(i,2), 'y^', 'MarkerFaceColor', 'y', 'MarkerSize', 6);
            end
            ax.YDir = "reverse";
            title(ax, sprintf("photo %d (%d/4): hist = thin line, tracking (GT) = thick line, centroid", i, q), ...
                'Interpreter', 'none', 'FontSize', 9);
        end
        exportgraphics(fig, fullfile(outDir, sprintf("evalMulti_overlay_img%d.png", i)), 'Resolution', 150);
        close(fig);
    end

    % 写真×溝ごとの差（本実装 − 正解、デトレンド後）
    for iM = 1:2
        m = METHODS(iM);
        fig = figure('Visible', 'off', 'Position', [0 0 1800 1600]);
        tl = tiledlayout(fig, numImages, N, 'TileSpacing', 'tight', 'Padding', 'compact');
        for i = 1:numImages
            for j = 1:N
                ax = nexttile(tl);
                plot(ax, xq{i}, shapeH{i,j,iM} - shapeG{i,j,iM});
                ylim(ax, [-0.5 0.5]); xlim(ax, [xq{i}(1) xq{i}(end)]);
                title(ax, sprintf("photo %d, groove %d: RMSE %.3f", i, j, G.rmse(i,j,iM)), ...
                    'Interpreter', 'none', 'FontSize', 7);
                ax.FontSize = 6;
            end
        end
        title(tl, "hist - tracking (GT), " + m + " [px]", 'Interpreter', 'none');
        exportgraphics(fig, fullfile(outDir, "evalMulti_diff_" + m + ".png"), 'Resolution', 150);
        close(fig);
    end

    % スペクトログラム（本実装・正解 × 重心法・局所的最大値法、N周分）
    fig = figure('Visible', 'off', 'Position', [0 0 1600 1000]);
    tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
    for m = METHODS
        for src = ["hist", "tracking (GT)"]
            if src == "hist", R = hs; else, R = gt; end
            nexttile(tl);
            R.(m).audio.plotSpectrogram(1024);
            title(src + " / " + m, 'Interpreter', 'none');
        end
    end
    exportgraphics(fig, fullfile(outDir, "evalMulti_stft.png"), 'Resolution', 150);
    close(fig);
end
fprintf("\n図・表の出力先：%s\n", outDir);


%% ローカル関数
function name = fieldFor(method, base)
% multiGroove・tracking のフィールド名（例："yAbs" → "yAbsCnt" / "yAbsMax"）
    if method == "centroid"
        name = base + "Cnt";
    else
        name = base + "Max";
    end
end

function [r, c] = rmseCorr(a, b)
% RMSE[px] と Pearson の相関係数（全列が対象）
    r = sqrt(mean((a - b).^2));
    if isequal(a, b)
        c = 1;
    else
        cc = corrcoef(a, b);
        c = cc(1,2);
    end
end

function n = longestRun(tf)
    runs = diff([0; tf(:); 0]);
    lens = find(runs == -1) - find(runs == 1);
    if isempty(lens), n = 0; else, n = max(lens); end
end

function s = listIJ(mask)
% 論理行列の true の位置を「写真i・j本目」の文字列にする（無ければ "なし"）
    [i, j] = find(mask);
    if isempty(i)
        s = "なし";
    else
        s = strjoin(compose("写真%d・%d本目", i, j), "、");
    end
end

function n = countKind(t, kind)
    n = nnz(t.("区分") == kind);
end

function n = countPass(t, kind)
    n = nnz(t.("区分") == kind & t.("合格"));
end
