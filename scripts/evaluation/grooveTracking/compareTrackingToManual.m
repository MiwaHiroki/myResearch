% compareTrackingToManual.m
% issue #25 の評価スクリプト。溝の自動追跡（grooveTrack_1cycle.m）の結果と、
% 今のコードで手動選択を再現した結果（pkCentroid_1cycle.m を intpD_0731 の
% grooveSelection で再実行したもの）、正解（origD_0731）を溝形状で比べる。
% 評価の項目・しきい値は docs/issues/25-groove-tracking/criteria.md（ID は同じ）。
%
% - 3つのファイルは同じ loadCycleResult で読み、同じフィールド（ycoords・y_comb・audio）
%   を比べる（要求「同じ比較スクリプトで読み込んで比べられる」の確認を兼ねる）。
% - 比べ方は docs/rules/evaluation.md に従う（RMSE[px]・相関係数、欠損は
%   fillmissing(...,"linear") で補ってから全列で計算、写真ごとと全体）。
% - 前処理（デトレンド）の違いによる差と、手法（追跡か手動か）の違いによる差を分ける。
%   手法の差（E1）は、追跡のデトレンド前のy座標にセグメントごとの3次デトレンドを
%   かけ直して比べる。最終出力の差（E4）は、写真ごとのデトレンドのまま比べる。
% - デトレンドの次数を変えた比較（POLY_DEGREES）も出す（plan.md 8章 Q2 の見直し用）。
%   保存済みのデトレンド前のy座標にかけ直すので、追跡の再実行は要らない。
% - ginput は使わない。図・wav は results/<OUT_DATE>/ に evalTrack_ で始まる名前で書く。
%   experiments/ には何も書かない。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       重ね描きの図で reconstructImage を使う）。
% 2026/10/13作成（評価担当、issue #25）

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
TRACK_DATE  = "MMDD";   % 追跡の結果 experiments/<日付>/cycleResult_origD_track_<日付>.mat
MANUAL_DATE = "MMDD";   % 手動選択の再現 experiments/<日付>/cycleResult_origD_<日付>.mat
GT_DATE     = "0731";   % 正解 cycleResult_origD_<GT_DATE>.mat、始点の入手元 cycleResult_intpD_<GT_DATE>.mat
OUT_DATE    = "MMDD";   % 図・wavの出力先 results/<OUT_DATE>/

POLY_DEGREES = [3 5 9 15];   % 写真ごとのデトレンドの次数を変えた比較（Q2の判断材料）
SAVE_FIGURES = true;         % 重ね描き・溝形状・スペクトログラムの図を保存する
SAVE_DEGREE_AUDIO = true;    % 次数ごとの wav を保存する（試聴用）
NUM_SEGMENTS = 10;           % 写真1枚あたりのセグメント数

% しきい値（criteria.md の表と同じ値。変えるときは criteria.md の承認を取り直す）
TH.P2_TOL         = 0.005;   % 手動の再現と正解の差が、計画段階の試行値からずれてよい幅
TH.E1_RMSE_MED    = 0.02;    % セグメントごとのRMSEの中央値 [px]
TH.E1_RMSE_MAX    = struct('centroid', 0.162, 'localMax', 0.30);   % 最大 [px]（未決事項 Q-a）
TH.E1_CORR_MIN    = 0.70;    % セグメントごとの相関係数の最小
TH.E1_NEAR_EXACT  = 70;      % RMSE<=0.01px のセグメントの数（80中）
TH.E1_GT_RMSE_DIFF = 0.01;   % 正解とのRMSEの中央値の、手動の再現との差 [px]
TH.E1_GT_CORR_DIFF = 0.02;   % 正解との相関の中央値の、手動の再現との差
TH.E2_MISSING     = 20;      % 写真ごとの欠損列の数
TH.E2_MAX_GAP     = 40;      % 最も長い連続欠損 [px]
TH.E3_STEP_RATIO  = 2;       % 境目の段差の中央値 / 隣どうしの列の差の中央値
TH.E4_CORR_PHOTO  = 0.80;    % 写真ごとの相関係数の最小
TH.E4_CORR_ALL    = 0.90;    % 全体の相関係数
TH.E4_RMSE_ALL    = 0.15;    % 全体のRMSE [px]
TH.E5_P_DIFF      = 4;       % p1/p2 のyの、手動の再現との差 [px]（h_prl/2）
TH.E5_EXACT_TOL   = 1e-9;    % 再現・整合の許容誤差

% 計画段階の試行（plan.md 付録A.4、評価担当の再試行で確認）での、手動の再現と正解の差
% [RMSE中央値, RMSE最大, 相関中央値, 相関最小]
EXPECTED_MANUAL_VS_GT = struct( ...
    'centroid', [0.1111 0.1616 0.8538 0.7036], ...
    'localMax', [0.0814 0.1466 0.9632 0.8898]);

METHODS = ["centroid","localMax"];

%% 読み込み
if any([TRACK_DATE MANUAL_DATE OUT_DATE] == "MMDD")
    error("compareTrackingToManual:dateNotSet", ...
        "TRACK_DATE・MANUAL_DATE・OUT_DATE を実行日（MMDD）にしてください。");
end
trackPath  = fullfile(experimentDir(rootFolder, TRACK_DATE, Create=false), ...
    "cycleResult_origD_track_" + TRACK_DATE + ".mat");
manualPath = cycleResultPath(rootFolder, "origD", MANUAL_DATE);
gtPath     = cycleResultPath(rootFolder, "origD", GT_DATE);
intpPath   = cycleResultPath(rootFolder, "intpD", GT_DATE);

track  = loadCycleResult(trackPath);
manual = loadCycleResult(manualPath);
gt     = loadCycleResult(gtPath);
intp   = loadCycleResult(intpPath);
outDir = mkdirFromDate(rootFolder, OUT_DATE);

fprintf("追跡      : %s（commit %s）\n", trackPath, track.meta.gitCommit);
fprintf("手動の再現: %s（commit %s）\n", manualPath, manual.meta.gitCommit);
fprintf("正解      : %s\n", gtPath);
fprintf("始点の入手元: %s\n", intpPath);

numSegTotal = numel(manual.centroid.ycoords);
numImages = numSegTotal / NUM_SEGMENTS;
gs  = track.grooveSelection;
trk = gs.tracking;
rows = cell(0,5);   % 判定の表 {ID, 指標, しきい値, 実測値, 判定}

%% P：基準データ（手動の再現）の確認
fprintf("\n=== P：基準データの確認 ===\n");
isSameSelection = isequal(manual.grooveSelection.p1, intp.grooveSelection.p1) && ...
    isequal(manual.grooveSelection.p2, intp.grooveSelection.p2);
rows(end+1,:) = {"P1", "手動の再現の p1/p2 が intpD_" + GT_DATE + " と同じ", "一致", ...
    string(isSameSelection), isSameSelection};

for m = METHODS
    [r, c] = segmentMetrics(fillCells(manual.(m).ycoords), fillCells(gt.(m).ycoords));
    measured = [median(r) max(r) median(c) min(c)];
    ok = all(abs(measured - EXPECTED_MANUAL_VS_GT.(m)) <= TH.P2_TOL);
    rows(end+1,:) = {"P2", m + "：手動の再現と正解（RMSE中央値/最大、相関中央値/最小）", ...
        "試行値 " + mat2str(EXPECTED_MANUAL_VS_GT.(m),4) + " ±" + TH.P2_TOL, ...
        mat2str(measured,4), ok}; %#ok<SAGROW>
end
fprintf("NaN の数（補間の前）：手動の再現 %d、正解 %d、追跡 %d\n", ...
    countNaN(manual), countNaN(gt), countNaN(track));

%% E5：保存形式と再現性
fprintf("\n=== E5：保存形式と再現性 ===\n");
needFields = ["p1","p2","method","seeds","tracking"];
needTrk = ["tolerance","fitLength","snapRadius","initLength","maxGapLength", ...
    "minFitPoints","queryStep","polyDegree","detrendScope","ampDivisor", ...
    "yAbsCnt","yAbsMax","foundCnt","foundMax"];
hasFields = all(isfield(gs, needFields)) && all(isfield(trk, needTrk));
seedsExpected = trackingSeeds(intp.grooveSelection, NUM_SEGMENTS);
formatOk = hasFields && gs.method == "tracking" && isequal(size(gs.seeds), [numImages 2]) && ...
    isequal(size(gs.p1), [numSegTotal 2]) && isequal(size(gs.p2), [numSegTotal 2]);
rows(end+1,:) = {"E5a", "grooveSelection のフィールド・形（method/seeds/tracking/p1/p2）", ...
    "plan.md 4.4 のとおり", string(formatOk), formatOk};
seedsOk = isequal(trackingSeeds(gs, NUM_SEGMENTS), gs.seeds) && isequal(gs.seeds, seedsExpected);
rows(end+1,:) = {"E5a", "seeds = intpD_" + GT_DATE + " の p1(1:10:end,:)（trackingSeeds でも同じ）", ...
    "一致", string(seedsOk), seedsOk};

dp1 = abs(gs.p1(:,2) - manual.grooveSelection.p1(:,2));
dp2 = abs(gs.p2(:,2) - manual.grooveSelection.p2(:,2));
dpMax = max([dp1; dp2]);
rows(end+1,:) = {"E5b", "p1/p2 のy と手動の再現のクリックの差の最大 [px]", ...
    "<= " + TH.E5_P_DIFF, sprintf("%.2f", dpMax), dpMax <= TH.E5_P_DIFF};

counts = cellfun(@numel, track.centroid.ycoords);
for m = METHODS
    lenOk = isequal(counts, cellfun(@numel, manual.(m).ycoords)) && ...
        isequal(cellfun(@numel, track.(m).ycoords), counts);
    yComb = track.(m).y_comb;
    combErr = max(abs(yComb - vertcat(track.(m).ycoords{:})));
    ampErr = max(abs(track.(m).audio.signal - (yComb - mean(yComb)) / trk.ampDivisor));
    fsOk = track.(m).audio.fs == manual.(m).audio.fs;
    ok = lenOk && combErr <= TH.E5_EXACT_TOL && ampErr <= TH.E5_EXACT_TOL && fsOk;
    rows(end+1,:) = {"E5c", m + "：ycoords の長さ・y_comb・audio（振幅÷ampDivisor、fs）", ...
        "手動の再現と同じ形", sprintf("長さ%d 連結誤差%.1e 振幅誤差%.1e fs%d", ...
        lenOk, combErr, ampErr, fsOk), ok}; %#ok<SAGROW>
end

% 保存した点群・始点・パラメータだけで、ginput なしで追跡を再現する
replay = struct();
for m = METHODS
    [yAbsSaved, foundSaved] = trackingFields(trk, m);
    errAbs = 0; errFound = 0; errDet = 0;
    replay.(m) = cell(numImages,1);
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        [pks, xq, cnt] = mergeSegmentPoints(track.(m).pts(ks), QueryStep=trk.queryStep);
        [pts, found] = trackGroove(pks, gs.seeds(i,:), xq, Tolerance=trk.tolerance, ...
            FitLength=trk.fitLength, SnapRadius=trk.snapRadius, ...
            InitLength=trk.initLength, MaxGapLength=trk.maxGapLength);
        errAbs = max(errAbs, max(abs(pts(:,2) - yAbsSaved{i})));
        errFound = errFound + nnz(found ~= foundSaved{i});
        det = detrendTrackedShape([xq, yAbsSaved{i}], PolyDegree=trk.polyDegree);
        errDet = max(errDet, max(abs(det(:,2) - vertcat(track.(m).ycoords{ks}))));
        if ~isequal(cnt, counts(ks))
            errDet = Inf;
        end
        replay.(m){i} = xq;
    end
    rows(end+1,:) = {"E5d", m + "：ycoords = detrendTrackedShape(デトレンド前のy) を分けたもの", ...
        "<= " + TH.E5_EXACT_TOL, sprintf("%.1e", errDet), errDet <= TH.E5_EXACT_TOL}; %#ok<SAGROW>
    ok = errAbs <= TH.E5_EXACT_TOL && errFound == 0;
    rows(end+1,:) = {"E5e", m + "：保存した pts・seeds・tracking で再現（y の差、found の不一致）", ...
        "<= " + TH.E5_EXACT_TOL + "、0列", sprintf("%.1e、%d列", errAbs, errFound), ok}; %#ok<SAGROW>
end

%% E2：欠損
fprintf("\n=== E2：欠損（写真ごと） ===\n");
missTable = table((1:numImages)', 'VariableNames', "photo");
for m = METHODS
    [~, foundSaved] = trackingFields(trk, m);
    numMiss = cellfun(@(f) nnz(~f), foundSaved);
    maxGap = cellfun(@(f) longestRun(~f), foundSaved) * trk.queryStep;
    missTable.(m + "_missing") = numMiss;
    missTable.(m + "_maxGapPx") = maxGap;
    rows(end+1,:) = {"E2a", m + "：写真ごとの欠損列の数の最大", "<= " + TH.E2_MISSING, ...
        mat2str(numMiss'), max(numMiss) <= TH.E2_MISSING}; %#ok<SAGROW>
    rows(end+1,:) = {"E2b", m + "：最も長い連続欠損 [px]", "<= " + TH.E2_MAX_GAP, ...
        sprintf("%g", max(maxGap)), max(maxGap) <= TH.E2_MAX_GAP}; %#ok<SAGROW>
end
disp(missTable);

%% E1：同じ溝を追えているか（同じ前処理＝セグメントごとの3次デトレンドで比べる）
fprintf("\n=== E1：手法の差（セグメントごと%d次デトレンドで比べる） ===\n", manual.conditions.polyDegree);
segTable = table((1:numSegTotal)', ceil((1:numSegTotal)'/NUM_SEGMENTS), ...
    mod((0:numSegTotal-1)', NUM_SEGMENTS) + 1, 'VariableNames', ["k","photo","segment"]);
trackSeg3 = struct();
for m = METHODS
    [yAbsSaved, ~] = trackingFields(trk, m);
    yAbsSegs = mat2cell(vertcat(yAbsSaved{:}), counts);
    segs = cell(numSegTotal,1);
    for k = 1:numSegTotal
        t = detrendGrooveShape([track.(m).xcoords{k}, yAbsSegs{k}], ...
            PolyDegree=manual.conditions.polyDegree);
        segs{k} = t(:,2);
    end
    trackSeg3.(m) = segs;
    [rM, cM] = segmentMetrics(segs, fillCells(manual.(m).ycoords));
    [rG, cG] = segmentMetrics(segs, fillCells(gt.(m).ycoords));
    [rMG, cMG] = segmentMetrics(fillCells(manual.(m).ycoords), fillCells(gt.(m).ycoords));
    segTable.(m + "_rmseVsManual") = rM;
    segTable.(m + "_corrVsManual") = cM;
    segTable.(m + "_rmseVsGT") = rG;
    segTable.(m + "_corrVsGT") = cG;

    rows(end+1,:) = {"E1a", m + "：RMSE の中央値 [px]", "<= " + TH.E1_RMSE_MED, ...
        sprintf("%.4f", median(rM)), median(rM) <= TH.E1_RMSE_MED}; %#ok<SAGROW>
    rows(end+1,:) = {"E1b", m + "：RMSE の最大 [px]", "<= " + TH.E1_RMSE_MAX.(m), ...
        sprintf("%.4f（k=%d）", max(rM), find(rM == max(rM), 1)), max(rM) <= TH.E1_RMSE_MAX.(m)}; %#ok<SAGROW>
    rows(end+1,:) = {"E1c", m + "：相関係数の最小", ">= " + TH.E1_CORR_MIN, ...
        sprintf("%.4f（k=%d）", min(cM), find(cM == min(cM), 1)), min(cM) >= TH.E1_CORR_MIN}; %#ok<SAGROW>
    nNear = nnz(rM <= 0.01);
    rows(end+1,:) = {"E1d", m + "：RMSE<=0.01px のセグメントの数", ">= " + TH.E1_NEAR_EXACT, ...
        sprintf("%d/%d", nNear, numSegTotal), nNear >= TH.E1_NEAR_EXACT}; %#ok<SAGROW>
    dR = median(rG) - median(rMG); dC = median(cG) - median(cMG);
    rows(end+1,:) = {"E1e", m + "：正解との差の中央値（追跡 − 手動の再現）RMSE / 相関", ...
        "RMSE <= +" + TH.E1_GT_RMSE_DIFF + "、相関 >= −" + TH.E1_GT_CORR_DIFF, ...
        sprintf("%+.4f / %+.4f（追跡 %.4f/%.4f、手動 %.4f/%.4f）", dR, dC, ...
        median(rG), median(cG), median(rMG), median(cMG)), ...
        dR <= TH.E1_GT_RMSE_DIFF && dC >= -TH.E1_GT_CORR_DIFF}; %#ok<SAGROW>

    diffK = find(rM > 1e-9)';
    fprintf("%s：手動の再現と完全には一致しないセグメント k = %s\n", m, mat2str(diffK));
    for k = diffK
        fprintf("   k=%2d（写真%d・セグメント%d）RMSE %.4f 相関 %.4f\n", ...
            k, segTable.photo(k), segTable.segment(k), rM(k), cM(k));
    end
end

%% E4：最終出力（写真ごとのデトレンド）と、次数を変えた比較
fprintf("\n=== E4：最終出力（写真ごと%d次）と次数を変えた比較 ===\n", trk.polyDegree);
degTable = table();
photoTable = table((1:numImages)', 'VariableNames', "photo");
for m = METHODS
    [yAbsSaved, ~] = trackingFields(trk, m);
    manualPhotos = photoCells(fillCells(manual.(m).ycoords), NUM_SEGMENTS);
    gtPhotos     = photoCells(fillCells(gt.(m).ycoords), NUM_SEGMENTS);
    seg3Photos   = photoCells(trackSeg3.(m), NUM_SEGMENTS);
    finalPhotos  = photoCells(track.(m).ycoords, NUM_SEGMENTS);

    [rP, cP, rAll, cAll] = photoMetrics(finalPhotos, manualPhotos);
    [rPg, cPg, rAllG, cAllG] = photoMetrics(finalPhotos, gtPhotos);
    [rPd, cPd, rAllD, cAllD] = photoMetrics(finalPhotos, seg3Photos);
    photoTable.(m + "_rmseVsManual") = rP;  photoTable.(m + "_corrVsManual") = cP;
    photoTable.(m + "_rmseVsGT") = rPg;     photoTable.(m + "_corrVsGT") = cPg;
    photoTable.(m + "_rmseDetrendOnly") = rPd; photoTable.(m + "_corrDetrendOnly") = cPd;

    rows(end+1,:) = {"E4a", m + "：写真ごとの相関係数の最小（対 手動の再現）", ">= " + TH.E4_CORR_PHOTO, ...
        sprintf("%.3f（写真%d）", min(cP), find(cP == min(cP), 1)), min(cP) >= TH.E4_CORR_PHOTO}; %#ok<SAGROW>
    rows(end+1,:) = {"E4b", m + "：全体の相関係数（対 手動の再現）", ">= " + TH.E4_CORR_ALL, ...
        sprintf("%.3f", cAll), cAll >= TH.E4_CORR_ALL}; %#ok<SAGROW>
    rows(end+1,:) = {"E4c", m + "：全体のRMSE [px]（対 手動の再現）", "<= " + TH.E4_RMSE_ALL, ...
        sprintf("%.3f", rAll), rAll <= TH.E4_RMSE_ALL}; %#ok<SAGROW>
    fprintf("%s：対 正解 全体 RMSE %.3f 相関 %.3f ／ デトレンドだけの差（同じ追跡に2通りのデトレンド）RMSE %.3f 相関 %.3f\n", ...
        m, rAllG, cAllG, rAllD, cAllD);

    for d = POLY_DEGREES
        detPhotos = cell(numImages,1);
        for i = 1:numImages
            t = detrendTrackedShape([replay.(m){i}, yAbsSaved{i}], PolyDegree=d);
            detPhotos{i} = t(:,2);
        end
        [rM, cM, rMa, cMa] = photoMetrics(detPhotos, manualPhotos);
        [rG, cG, rGa, cGa] = photoMetrics(detPhotos, gtPhotos);
        [stepMed, diffMed] = boundarySteps(detPhotos, counts, NUM_SEGMENTS);
        degTable = [degTable; table(m, d, ...
            min(rM), max(rM), rMa, min(cM), max(cM), cMa, ...
            min(rG), max(rG), rGa, min(cG), max(cG), cGa, stepMed, diffMed, ...
            'VariableNames', ["method","degree", ...
            "rmseManMin","rmseManMax","rmseManAll","corrManMin","corrManMax","corrManAll", ...
            "rmseGTMin","rmseGTMax","rmseGTAll","corrGTMin","corrGTMax","corrGTAll", ...
            "stepMedian","neighborDiffMedian"])]; %#ok<AGROW>
    end
end
disp(photoTable);
fprintf("次数を変えた比較（写真ごとのデトレンド。Man=手動の再現、GT=正解。参考、判定には使わない）\n");
disp(degTable);

%% E3：セグメントの境目の段差（写真の中）
fprintf("\n=== E3：セグメントの境目の段差 ===\n");
for m = METHODS
    [stepMed, diffMed] = boundarySteps(photoCells(track.(m).ycoords, NUM_SEGMENTS), counts, NUM_SEGMENTS);
    [stepMan, diffMan] = boundarySteps(photoCells(fillCells(manual.(m).ycoords), NUM_SEGMENTS), counts, NUM_SEGMENTS);
    ratio = stepMed / diffMed;
    rows(end+1,:) = {"E3", m + "：境目の段差の中央値 ÷ 隣どうしの列の差の中央値", ...
        "<= " + TH.E3_STEP_RATIO, sprintf("%.2f（%.4f/%.4f px。手動の再現は %.2f）", ...
        ratio, stepMed, diffMed, stepMan/diffMan), ratio <= TH.E3_STEP_RATIO}; %#ok<SAGROW>
end

%% 参考：セグメントの周期（約104Hz）の高調波の目立ち具合（ユーザーが判断する項目 U2 の補助）
fprintf("\n=== 参考：セグメント周期の高調波の目立ち具合 [dB]（1〜5次。周囲のビンの中央値との比） ===\n");
for m = METHODS
    fprintf("%-9s 手動の再現 %s ／ 追跡 %s\n", m, ...
        mat2str(segmentRateProminence(manual.(m).y_comb, numSegTotal), 3), ...
        mat2str(segmentRateProminence(track.(m).y_comb, numSegTotal), 3));
end

%% 判定の表
resultTable = cell2table(rows, 'VariableNames', ["ID","指標","しきい値","実測値","合格"]);
fprintf("\n=== 判定（数値の項目） ===\n");
disp(resultTable);
fprintf("数値の項目：%d/%d 合格\n", nnz([rows{:,5}]), size(rows,1));
writetable(resultTable, fullfile(outDir, "evalTrack_summary.csv"), "Encoding", "UTF-8");
writetable(segTable, fullfile(outDir, "evalTrack_segments.csv"));
writetable(photoTable, fullfile(outDir, "evalTrack_photos.csv"));
writetable(degTable, fullfile(outDir, "evalTrack_degrees.csv"));

%% 図と wav（ユーザーが判断する項目 U1〜U4）
if SAVE_FIGURES
    % U1：追跡の経路を撮影画像に重ねる（セグメントごとに溝の周りを切り出す）
    for i = 1:numImages
        imgs = reconstructImage(track.conditions, i);
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        yPhoto = trk.yAbsCnt{i};
        fPhoto = trk.foundCnt{i};
        yManSegs = photoSegments(manual.grooveSelection, ks);
        offs = [0; cumsum(counts(ks(1:end-1)))];
        fig = figure('Visible', 'off', 'Position', [0 0 1600 1200]);
        tl = tiledlayout(fig, NUM_SEGMENTS, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
        for j = 1:NUM_SEGMENTS
            nexttile(tl);
            idx = offs(j) + (1:counts(ks(j)))';
            y = yPhoto(idx); x = (1:numel(idx))';
            rowRange = max(1, floor(min(y)) - 30) : min(imgs(j).height, ceil(max(y)) + 30);
            imagesc(imgs(j).img(rowRange, :)); colormap(gca, gray); axis off; hold on;
            plot(x, y - rowRange(1) + 1, 'r-', 'LineWidth', 0.8);
            miss = ~fPhoto(idx);
            plot(x(miss), y(miss) - rowRange(1) + 1, 'bx', 'MarkerSize', 4);
            plot([1 counts(ks(j))], yManSegs(j,:) - rowRange(1) + 1, 'y^', ...
                'MarkerFaceColor', 'y', 'MarkerSize', 4);
            title(sprintf("photo %d, segment %d", i, j), 'Interpreter', 'none', 'FontSize', 8);
        end
        exportgraphics(fig, fullfile(outDir, sprintf("evalTrack_overlay_img%d.png", i)), 'Resolution', 150);
        close(fig);
    end

    % 溝形状（写真ごと）：手動の再現と追跡の最終出力を重ねる
    for m = METHODS
        manualPhotos = photoCells(fillCells(manual.(m).ycoords), NUM_SEGMENTS);
        finalPhotos  = photoCells(track.(m).ycoords, NUM_SEGMENTS);
        fig = figure('Visible', 'off', 'Position', [0 0 1600 1600]);
        tl = tiledlayout(fig, numImages, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
        for i = 1:numImages
            nexttile(tl);
            plot(manualPhotos{i} - mean(manualPhotos{i})); hold on;
            plot(finalPhotos{i} - mean(finalPhotos{i}));
            xline(cumsum(counts((i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS-1))), ':');
            axis tight; ylabel(sprintf("photo %d", i), 'Interpreter', 'none');
        end
        legend(["manual (segment-wise)", "tracking (photo-wise)"], 'Interpreter', 'none');
        exportgraphics(fig, fullfile(outDir, "evalTrack_shape_" + m + ".png"), 'Resolution', 150);
        close(fig);
    end

    % U2：スペクトログラム（全帯域は窓1024点、0〜500Hzは周波数の分解能を上げて窓4096点）
    for yMax = [5000 500]
        if yMax > 500, winSize = 1024; else, winSize = 4096; end
        fig = figure('Visible', 'off', 'Position', [0 0 1600 1000]);
        tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
        for m = METHODS
            for src = ["manual","track"]
                if src == "manual", res = manual; else, res = track; end
                nexttile(tl);
                res.(m).audio.plotSpectrogram(winSize);
                ylim([0 yMax]);
                title(src + " / " + m, 'Interpreter', 'none');
            end
        end
        exportgraphics(fig, fullfile(outDir, sprintf("evalTrack_stft_0to%dHz.png", yMax)), 'Resolution', 150);
        close(fig);
    end
end

if SAVE_DEGREE_AUDIO
    % U3・U4：次数ごとの wav（振幅は追跡のスクリプトと同じ ampDivisor で割る）
    for m = METHODS
        [yAbsSaved, ~] = trackingFields(trk, m);
        for d = POLY_DEGREES
            parts = cell(numImages,1);
            for i = 1:numImages
                t = detrendTrackedShape([replay.(m){i}, yAbsSaved{i}], PolyDegree=d);
                parts{i} = t(:,2);
            end
            y = vertcat(parts{:});
            amp = (y - mean(y)) / trk.ampDivisor;
            peak = max(abs(amp));
            if peak > 1
                % 低い次数では残ったうねりで±1を超え、wavで切り捨てられるので、最大値で割る
                amp = amp / peak;
                fprintf("%s %d次：振幅の最大が %.2f のため、最大値で正規化して保存した（音量は他と比べられない）\n", ...
                    m, d, peak);
            end
            AudioData(sprintf("evalTrack deg%d %s", d, m), amp, track.(m).audio.fs).saveAudio(outDir);
        end
    end
end
fprintf("\n図・wav・表の出力先：%s\n", outDir);


%% ローカル関数
function cells = fillCells(cells)
% 区間検出に基づく手法の欠損（NaN）を、既存の _1cycle スクリプトと同じく線形補間する
    cells = cellfun(@(v) fillmissing(v, "linear"), cells, 'UniformOutput', false);
end

function n = countNaN(result)
    n = 0;
    for m = ["centroid","localMax"]
        n = n + sum(cellfun(@(v) nnz(isnan(v)), result.(m).ycoords));
    end
end

function [r, c] = segmentMetrics(a, b)
% セグメントごとの RMSE[px] と相関係数（全列が対象）
    n = numel(a);
    r = zeros(n,1); c = zeros(n,1);
    for k = 1:n
        [r(k), c(k)] = rmseCorr(a{k}, b{k});
    end
end

function [rP, cP, rAll, cAll] = photoMetrics(a, b)
% 写真ごとと全体の RMSE・相関係数。比べる前にどちらも写真ごとに平均0にする
    n = numel(a);
    rP = zeros(n,1); cP = zeros(n,1);
    a = cellfun(@(v) v - mean(v), a, 'UniformOutput', false);
    b = cellfun(@(v) v - mean(v), b, 'UniformOutput', false);
    for i = 1:n
        [rP(i), cP(i)] = rmseCorr(a{i}, b{i});
    end
    [rAll, cAll] = rmseCorr(vertcat(a{:}), vertcat(b{:}));
end

function [r, c] = rmseCorr(a, b)
    r = sqrt(mean((a - b).^2));
    if isequal(a, b)
        c = 1;
    else
        cc = corrcoef(a, b);
        c = cc(1,2);
    end
end

function photos = photoCells(segCells, numSegments)
% セグメントごとの cell（N x 1）を写真ごとに縦につないだ cell（N/numSegments x 1）にする
    numImages = numel(segCells) / numSegments;
    photos = cell(numImages,1);
    for i = 1:numImages
        photos{i} = vertcat(segCells{(i-1)*numSegments + (1:numSegments)});
    end
end

function [yAbs, found] = trackingFields(trk, method)
% grooveSelection.tracking から、手法ごとのデトレンド前のy座標と found を取り出す
    if method == "centroid"
        yAbs = trk.yAbsCnt; found = trk.foundCnt;
    else
        yAbs = trk.yAbsMax; found = trk.foundMax;
    end
end

function [stepMed, diffMed] = boundarySteps(photos, counts, numSegments)
% 写真の中のセグメントの境目の段差（右端と次の左端の差の絶対値）の中央値と、
% 境目以外の隣どうしの列の差の絶対値の中央値
    steps = []; diffs = [];
    for i = 1:numel(photos)
        cnt = counts((i-1)*numSegments + (1:numSegments));
        last = cumsum(cnt);
        y = photos{i};
        d = abs(diff(y));
        isBoundary = false(size(d));
        isBoundary(last(1:end-1)) = true;
        steps = [steps; d(isBoundary)]; %#ok<AGROW>
        diffs = [diffs; d(~isBoundary)]; %#ok<AGROW>
    end
    stepMed = median(steps);
    diffMed = median(diffs);
end

function n = longestRun(tf)
    runs = diff([0; tf(:); 0]);
    lens = find(runs == -1) - find(runs == 1);
    if isempty(lens), n = 0; else, n = max(lens); end
end

function yEnds = photoSegments(selection, ks)
% 手動の再現のクリック（p1/p2）のyを、セグメントごとに [左端 右端] で返す
    yEnds = [selection.p1(ks,2), selection.p2(ks,2)];
end

function prom = segmentRateProminence(y, numSegTotal)
% 1周の波形のFFTで、セグメントの周期（1周にnumSegTotal回）の1〜5次の高調波が、
% 周りのビン（±2〜10ビン）の中央値より何dB大きいか。1周分なので、ビン m*numSegTotal+1 が
% m次の高調波にあたる
    A = abs(fft(y - mean(y)));
    prom = zeros(1,5);
    for h = 1:5
        b = h*numSegTotal + 1;
        nb = [b-10:b-2, b+2:b+10];
        prom(h) = 20*log10(max(A(b-1:b+1)) / median(A(nb)));
    end
end
