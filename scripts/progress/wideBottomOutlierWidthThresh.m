% wideBottomOutlierWidthThresh.m
% 進捗報告用。issue #35 の素材 M6・M8・M9。
% 溝底区間の幅の上限を 8（直す前）と 4（直した後）にして、保存したクリック位置から溝の選択をやり直し、
% 直す前と後に選んだ溝底点を写真に重ねた切り出しの図と、音声の波形の図を作って、
% results/figures/progress/grooveBottomDetection/ に保存する。作るのは、評価スクリプト
% scripts/evaluation/grooveBottomDetection/compareWidthThresh.m が 2026-11-18 に results/grooveBottomDetection/2026-1118_evaluation/ に出した
% ユーザー確認用の図のうち、次の5枚と同じ名前・同じ中身の図である。
%   M6：1014、写真8、715-716 ms の切り出しと、714-717 ms の波形（外れ値が消えた所）
%   M8：1104 の本実装、4本目・写真5、2718-2719 ms の切り出しと、2717-2720 ms の波形
%       （溝底の線そのものの下がりが残る所）
%   M9：1014、写真8、671-672 ms の切り出し（外れ値でない幅の広い点が、補間に置き換わった所）
% 評価の図との違いは、点と文字の大きさと、凡例の位置だけである（ユーザーの決定、2026-11-23）。切り出しの
% 図の点は、すべての種類を同じ大きさ（MARKER_SIZE）にし、文字は MATLAB の既定（目盛り 9 pt、軸ラベルと
% タイトル 9.9 pt、凡例 8.1 pt）にした。凡例は、描画領域の右上（LEGEND_LOCATION）に置いた。
% 評価スクリプトはこれらの値を関数の中に書いていて、temp/ のコピーの冒頭を変えるだけでは作れないので、
% 要るローカル関数（溝底点の検出、溝の選択のやり直し、列ごとの表、切り出す範囲の決め方、図）を、
% このスクリプトの末尾に写した。評価スクリプトは変えていない。
% 手順
%   1. 写真を reconstructImage で読み直し、幅の上限 8 と 4 で、溝底点（重心法）と点ごとの溝底区間の幅を
%      求める。幅の上限 8 の点が、保存した溝底点（pts）と一致することを確かめる（評価の R1）。
%   2. 保存したクリック位置とパラメータで、データを作ったスクリプトと同じ溝の選択をやり直し、写真ごとの
%      9次のデトレンドと振幅を作る。幅の上限 8 の結果が、保存したデトレンド前の y・点を採れた列
%      （h1104 はヒストグラムの山の中心も）と振幅に一致することを確かめる（評価の R3・R4）。
%   3. 外れ値・|振幅| の数と、切り出す区間の |振幅| の最大が、評価の結果と合うことを確かめる。
%   4. 評価スクリプトと同じ決め方で、切り出す範囲と波形の時間を決め、図を作る。
% 局所的なずれ：選んだ点のデトレンド前の y から、前後10列（合わせて21列）で点を採れた列の y の
% 中央値を引いた値。外れ値は、その絶対値が DEV_TH を超える点（docs/issues/closed/35-wide-bottom-outliers/
% criteria.md と同じ定義）。
% experiments/ は読むだけで、何も保存しない。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること）。
% 2026/11/23作成
% 2026/11/23 ユーザーの決定で、凡例の位置を "best" から右上（"northeast"）にそろえた。OVERWRITE=true で
%            5枚を作り直した
% 2026/11/26 ユーザーの決定（docs/rules/figures.md の「線と点」「軸の範囲」「凡例」）で、波形の図の、y が変わった
%            列の丸を塗りつぶし、写真の境目を細い実線（LINE_WIDTH_AUX）にし、振幅の軸を 0 を中心に上下対称に
%            した（AMP_LIM_STEP）。OVERWRITE=true で波形の2枚（M6・M8）だけを作り直した（MAKE_FIGS.crop=false）
% 2026/11/26 ユーザーの決定（docs/rules/figures.md の「線と点」の線の太さの既定値）で、波形の直す前の線を
%            1.2 pt から 1 pt に、切り出しの直した後の経路を 0.8 pt から 1 pt（LINE_WIDTH_PATH）にした。
%            OVERWRITE=true で5枚（M6・M8 の切り出しと波形、M9 の切り出し）を作り直した

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ（評価スクリプトと同じ値）
DATA_KEYS  = ["t1014", "h1104"];
DATA_DATES = ["2026-1014", "2026-1104"];
DATA_MMDD = extractAfter(DATA_DATES, "-");   % 図の名前とタイトルに書くデータの日付（MMDD。docs/rules/figures.md）
DATA_FILES = ["cycleResult_origD_track_2026-1014.mat", "cycleResult_origD_hist5_2026-1104.mat"];
DATA_KIND  = ["track", "hist"];  % 溝の選び方（図の名前の語にもなる）
UPSAMPLING = "origD";   % 高解像度化（自動追跡は origD だけ）
BOUND = "inclBound";    % 溝底の判定。2つのデータは ad46b44 以降のコードで作った
METHOD = "centroid";    % 溝底の抽出法（この素材は重心法だけ）

W_BEFORE = 8;           % 直す前の溝底区間の幅の上限 [px]
W_AFTER = 4;            % 直した後の値
WIDE_MIN = W_AFTER + 1; % 幅がこれ以上の選んだ点を「幅の広い点」とする [px]
DEV_WINDOW = 21;        % 局所的なずれの移動中央値の窓 [列]
DEV_TH = 1;             % 外れ値とする局所的なずれの絶対値 [px]（これを超えたら外れ値）
AMP_TH = [0.8 1];       % 数える |振幅| のしきい値
RUN_JOIN_GAP = 2;       % 幅の広い点が続く区間で、つなぐすき間の列の数
EXACT = 1e-9;           % 一致とみなす誤差
NUM_SEGMENTS = 10;      % 写真1枚あたりの区間の数

% 作る図：データ data の groove 本目・写真 photo で、列 x を含む「幅の広い点が続く区間」の切り出しと、
% その区間が外れ値を含むか LONG_RUN 列以上続くときは、波形
TARGETS = struct("data", {"t1014", "h1104", "t1014"}, "groove", {1, 4, 1}, "photo", {8, 5, 8}, ...
    "x", {1862, 1141, 33});
% 評価と同じ図の名前（作った図の名前が、この中にあることを確かめる）
EXPECTED_NAMES = ["grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_715-716ms", ...
    "waveform_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_714-717ms", ...
    "grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2718-2719ms", ...
    "waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2717-2720ms", ...
    "grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_671-672ms"];

% 評価の結果（直す前・直した後）。eval-report-1.md 2.3 の P1〜P3 と、
% results/grooveBottomDetection/2026-1118_evaluation/evalWidthThresh_wideRuns.csv の maxAbsAmpBefore・maxAbsAmpAfter
EXPECT.outliers = struct("t1014", [1 0], "h1104", [26 0]);
EXPECT.amp08    = struct("t1014", [2 1], "h1104", [56 9]);
EXPECT.amp1     = struct("t1014", [1 0], "h1104", [32 0]);
EXPECT_RUN_AMP  = [1.0349 0.4316; 1.2284 0.7770; 0.0801 0.2846];  % TARGETS の順。区間の |振幅| の最大
EXPECT_TOL = 5e-4;      % EXPECT_RUN_AMP と比べるときの誤差

% 図（評価スクリプトと同じ値）
X_MARGIN = 30;          % 切り出しの、区間の両端から外への幅 [px]
Y_HALF = 14;            % 切り出しの、溝の y を中心にした高さの半分 [px]（隣の溝の手前まで）
MERGE_GAP = 30;         % これより近い区間は1枚の切り出しにまとめる [列]
LONG_RUN = 11;          % 波形を作る区間の長さ [列]（外れ値を含まなくても、これ以上続けば作る）
WAVE_MARGIN_MS = 1;     % 波形の、区間の両端から外への時間 [ms]
% 評価の図から変えた値（ユーザーの決定、2026-11-23）
MARKER_SIZE = 18;       % 切り出しの図の点の大きさ（すべての種類。評価の図は、すべての溝底点だけ 9）
FONT_SIZE = 9;          % 目盛りの文字 [pt]。軸ラベル・タイトルはその 1.1 倍、凡例は 0.9 倍（MATLAB の既定）
LEGEND_LOCATION = "northeast"; % 凡例の位置（描画領域の右上。評価の図は "best"）
% 評価の図から変えた値（ユーザーの決定、2026-11-26。docs/rules/figures.md の「線と点」「軸の範囲」）
LINE_WIDTH_BEFORE = 1;  % 波形の、直す前の線の太さ [pt]（データの線の既定値。評価の図は 1.2 pt）
LINE_WIDTH_AFTER = 1;   % 波形の、直した後の線の太さ [pt]（データの線の既定値。評価の図と同じ）
LINE_WIDTH_PATH = 1;    % 切り出しの、直した後の経路の太さ [pt]（データの線の既定値。評価の図は 0.8 pt）
LINE_WIDTH_AUX = 0.5;    % 波形の、写真の境目の線の太さ [pt]（補助の線。データの線より細い実線。評価の図は 1 pt の点線）
WAVE_MARKER_SIZE = 4;    % 波形の、y が変わった列の丸の大きさ（plot の MarkerSize。塗りつぶす。評価の図は白抜き）
AMP_LIM_STEP = 0.1;      % 振幅の軸は ±(区間の |振幅| の最大をこの刻みで切り上げた値。1 より小さければ 1)。
                         % 評価の図は自動の範囲で、0 を中心にしていなかった
MAKE_FIGS = struct("crop", true, "wave", true); % 作る図（crop は切り出し、wave は波形）。片方だけ作り直すときに使う
STYLE = struct("figSizeCrop", [16 13], "figSizeWave", [16 8], "markerSize", MARKER_SIZE, ...
    "fontSize", FONT_SIZE, "legendLocation", LEGEND_LOCATION, ...
    "lineWidthBefore", LINE_WIDTH_BEFORE, "lineWidthAfter", LINE_WIDTH_AFTER, "lineWidthAux", LINE_WIDTH_AUX, ...
    "lineWidthPath", LINE_WIDTH_PATH, ...
    "waveMarkerSize", WAVE_MARKER_SIZE, "ampLimStep", AMP_LIM_STEP, ...
    "colorAll", "cyan", "colorBefore", "yellow", "colorAfter", "magenta", ...
    "colorWaveBefore", [0.85 0.33 0.10], "colorWaveAfter", [0 0.45 0.74]);
OVERWRITE = false;      % 同じ名前の図を上書きするか（作り直すときだけ true にする）

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD", "original", "inclBound", "inclusive bounds", "centroid", "centroid", ...
    "track", "tracking", "hist", "histogram", ...
    "before", "width threshold " + W_BEFORE + " px", "after", "width threshold " + W_AFTER + " px");

THEME = "grooveBottomDetection";
saveDir = figureDir(rootFolder, "progress", THEME);

%% 読み込み
if METHOD ~= "centroid"   % 溝底点の検出（detectPhoto）は重心法だけを求める
    error("wideBottomOutlierWidthThresh:method", "このスクリプトは重心法だけを扱います。");
end
R = struct();
for d = 1:numel(DATA_KEYS)
    path = fullfile(experimentDir(rootFolder, DATA_DATES(d), Create=false), DATA_FILES(d));
    R.(DATA_KEYS(d)) = loadCycleResult(path);
    meta = R.(DATA_KEYS(d)).meta;
    fprintf("%s：%s\n       commit %s、gitDirty %d、スクリプト %s\n", DATA_KEYS(d), path, ...
        meta.gitCommit, meta.gitDirty, meta.scriptName);
end

% 2つのデータは、同じ写真・同じ検出のパラメータで作ったことを確かめる（写真は1度だけ読む）
cond = R.h1104.conditions;
for d = 1:numel(DATA_KEYS)
    c = R.(DATA_KEYS(d)).conditions;
    if c.dThresh ~= cond.dThresh || c.lMask ~= cond.lMask || c.wTh ~= W_BEFORE || ...
            ~isequal(c.filenames, cond.filenames) || c.numImages ~= cond.numImages || ...
            c.numSegments ~= NUM_SEGMENTS || c.upsampling.kind ~= UPSAMPLING
        error("wideBottomOutlierWidthThresh:conditionsMismatch", ...
            "データの検出の条件（dThresh・lMask・wTh・写真・区間の数・高解像度化）が同じではありません。");
    end
end
numImages = cond.numImages;
queryStep = R.h1104.grooveSelection.tracking.queryStep;
fs = R.h1104.(METHOD).audio.fs;
if R.t1014.(METHOD).audio.fs ~= fs
    error("wideBottomOutlierWidthThresh:fsMismatch", "2つのデータでサンプリング周波数が違います。");
end

%% 1. 溝底点の検出（幅の上限 8 と 4）
DET = struct("before", {cell(numImages,1)}, "after", {cell(numImages,1)});
photos = cell(numImages,1);   % 写真1枚分の画素値（図に使う）
for i = 1:numImages
    imgs = reconstructImage(cond, i);
    photos{i} = [imgs.img];
    DET.before{i} = detectPhoto(imgs, cond.dThresh, W_BEFORE, queryStep);
    DET.after{i} = detectPhoto(imgs, cond.dThresh, W_AFTER, queryStep);
end

% 幅の上限 8 の点が、保存した溝底点と一致するか（評価の R1）
errR1 = 0;
for d = 1:numel(DATA_KEYS)
    for i = 1:numImages
        ks = (i-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
        saved = mergeSegmentPoints(R.(DATA_KEYS(d)).(METHOD).pts(ks), QueryStep=queryStep);
        errR1 = max(errR1, pointsError(saved, DET.before{i}.pks));
    end
end
fprintf("\nR1：幅の上限 %d で求め直した溝底点と、保存した溝底点の差の最大 %.1e\n", W_BEFORE, errR1);
if errR1 > EXACT
    error("wideBottomOutlierWidthThresh:pointsMismatch", "求め直した溝底点が、保存した溝底点と違います。");
end

%% 2. 溝の選択とデトレンド（直す前と後）
SEL = struct();   % SEL.(データ).(before/after)：選択の結果
T = struct();     % T.(データ).(before/after)：列ごとの表（再生順）
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    trk = R.(key).grooveSelection.tracking;
    for p = ["before", "after"]
        sel = selectGrooves(R.(key), DATA_KIND(d), DET.(p), NUM_SEGMENTS);
        shapes = cell(size(sel.yAbs));
        for k = 1:numel(sel.yAbs)
            [i, ~] = ind2sub(size(sel.yAbs), k);
            dt = detrendTrackedShape([DET.(p){i}.xQuery, sel.yAbs{k}], PolyDegree=trk.polyDegree);
            shapes{k} = dt(:,2);
        end
        yc = vertcat(shapes{:});   % 再生順（1本目の写真1〜8、2本目の写真1〜8、…）
        amp = (yc - mean(yc)) / trk.ampDivisor;
        SEL.(key).(p) = sel;
        T.(key).(p) = columnTable(sel, DET.(p), shapes, amp, fs, DEV_WINDOW);
        fprintf("%s・%s：溝の選択の警告 %d 件\n", key, p, numel(sel.warnings));
        if ~isempty(sel.warnings)
            fprintf("    %s\n", sel.warnings);
        end
    end
end

% 直す前が、保存した結果を再現するか（評価の R3・R4）
errY = 0; errF = 0; errC = 0; errA = 0;
sfx = suffixOf(METHOD);
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    gs = R.(key).grooveSelection;
    if isfield(gs, "multiGroove")
        yS = gs.multiGroove.("yAbs" + sfx); fS = gs.multiGroove.("found" + sfx);
    else
        yS = gs.tracking.("yAbs" + sfx); fS = gs.tracking.("found" + sfx);
    end
    sel = SEL.(key).before;
    for k = 1:numel(yS)
        errY = max(errY, max(abs(sel.yAbs{k} - yS{k})));
        errF = errF + nnz(sel.found{k} ~= fS{k});
    end
    if DATA_KIND(d) == "hist"
        errC = max(errC, max(abs(sel.centers - gs.multiGroove.("centers" + sfx)), [], "all"));
    end
    errA = max(errA, max(abs(T.(key).before.amp - R.(key).(METHOD).audio.signal)));
end
fprintf("R3：直す前の溝の選択と保存した結果の差 y %.1e、found の不一致 %d、山の中心 %.1e\n", errY, errF, errC);
fprintf("R4：直す前の振幅と、保存した音声の差の最大 %.1e\n", errA);
if errY > EXACT || errF ~= 0 || errC > EXACT || errA > EXACT
    error("wideBottomOutlierWidthThresh:selectionMismatch", "直す前の溝の選択か振幅が、保存した結果と違います。");
end

%% 3. 評価の結果と合うか
for d = 1:numel(DATA_KEYS)
    key = DATA_KEYS(d);
    B = T.(key).before;
    A = T.(key).after;
    got.outliers = [nnz(abs(B.dev) > DEV_TH), nnz(abs(A.dev) > DEV_TH)];
    got.amp08 = [nnz(abs(B.amp) > AMP_TH(1)), nnz(abs(A.amp) > AMP_TH(1))];
    got.amp1 = [nnz(abs(B.amp) > AMP_TH(2)), nnz(abs(A.amp) > AMP_TH(2))];
    fprintf("%s：外れ値 %d → %d、|振幅| > %g が %d → %d、|振幅| > %g が %d → %d\n", key, ...
        got.outliers, AMP_TH(1), got.amp08, AMP_TH(2), got.amp1);
    for f = ["outliers", "amp08", "amp1"]
        if ~isequal(got.(f), EXPECT.(f).(key))
            error("wideBottomOutlierWidthThresh:countMismatch", "%s の %s が、評価の結果と違います。", key, f);
        end
    end
end

%% 4. 図
vsName = "wTh" + W_BEFORE + "VsWTh" + W_AFTER;
vsTitle = LABEL.before + " vs " + LABEL.after;
for iTarget = 1:numel(TARGETS)
    tg = TARGETS(iTarget);
    d = find(DATA_KEYS == tg.data);
    key = DATA_KEYS(d);
    B = T.(key).before;
    A = T.(key).after;
    i = tg.photo; j = tg.groove;
    nG = size(SEL.(key).before.yAbs, 2);
    if nG > 1
        cycName = "_" + nG + "cyc"; cycTitle = ", " + nG + " cycles";
        partName = "_img" + i + "_groove" + j; partTitle = "photo " + i + ", groove " + j;
    else
        cycName = ""; cycTitle = "";
        partName = "_img" + i; partTitle = "photo " + i;
    end
    condName = UPSAMPLING + "_" + BOUND + "_" + METHOD + "_" + DATA_KIND(d) + cycName + "_" + DATA_MMDD(d);
    condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(BOUND) + ", " + LABEL.(METHOD) + ", " + ...
        LABEL.(DATA_KIND(d)) + cycTitle + ", data " + DATA_MMDD(d);

    % 切り出す場所：直す前の幅の広い点が続く区間（評価スクリプトと同じ決め方）
    k = find(B.groove == j & B.photo == i);
    runs = wideRuns(B, A, k, WIDE_MIN, DEV_TH, RUN_JOIN_GAP);
    r = find(runs.xStart <= tg.x & runs.xEnd >= tg.x, 1);
    if isempty(r)
        error("wideBottomOutlierWidthThresh:noRun", "%s・%d本目・写真%d の x=%d に、幅の広い点が続く区間がありません。", ...
            key, j, i, tg.x);
    end
    fprintf("\n%s・%d本目・写真%d：区間 x=%d〜%d（%d列、幅の広い点 %d、外れ値 %d）、|振幅| の最大 %.4f → %.4f\n", ...
        key, j, i, runs.xStart(r), runs.xEnd(r), runs.numCols(r), runs.numWide(r), runs.numOutliers(r), ...
        runs.maxAbsAmpBefore(r), runs.maxAbsAmpAfter(r));
    if any(abs([runs.maxAbsAmpBefore(r), runs.maxAbsAmpAfter(r)] - EXPECT_RUN_AMP(iTarget,:)) > EXPECT_TOL)
        error("wideBottomOutlierWidthThresh:runAmpMismatch", "区間の |振幅| の最大が、評価の結果と違います。");
    end
    crops = mergeCrops(runs, MERGE_GAP);
    c = crops(find(crops.xStart <= tg.x & crops.xEnd >= tg.x, 1), :);

    xQ = B.x(k);
    xr = max(1, c.xStart - X_MARGIN) : min(numel(xQ), c.xEnd + X_MARGIN);
    yMid = round(median(B.y(k(xr))));
    yr = max(1, yMid - Y_HALF) : min(size(photos{i},1), yMid + Y_HALF);
    msRange = [floor(c.tStartMs), max(ceil(c.tEndMs), floor(c.tStartMs) + 1)];
    selB = [B.x(k(B.found(k))), B.y(k(B.found(k)))];
    selA = [A.x(k(A.found(k))), A.y(k(A.found(k)))];
    % タイトルは図の幅に収まらないので3行に分ける（書く情報と順は、名前と同じ。評価の図と同じ分け方）
    if MAKE_FIGS.crop
        fig = plotCrop(photos{i}, xr, yr, DET.before{i}.pks, selB, selA, [A.x(k), A.y(k)], ...
            STYLE, LABEL, ["Groove on image: " + vsTitle, "(" + condTitle + ",", ...
            partTitle + sprintf(", %d-%d ms)", msRange)]);
        saveAndClose(fig, saveDir, "grooveOnImage_" + vsName + "_" + condName + partName + ...
            sprintf("_%d-%dms", msRange), EXPECTED_NAMES, OVERWRITE);
    end

    % 外れ値を含む区間と、LONG_RUN 列以上続く区間の波形
    if MAKE_FIGS.wave && (c.numOutliers > 0 || c.numCols >= LONG_RUN)
        tr = [floor(c.tStartMs - WAVE_MARGIN_MS), ceil(c.tEndMs + WAVE_MARGIN_MS)];
        fig = plotWave(B, A, tr, EXACT, STYLE, LABEL, ["Waveform: " + vsTitle, ...
            "(" + condTitle + ", " + partTitle + sprintf(", %d-%d ms)", tr)]);
        saveAndClose(fig, saveDir, "waveform_" + vsName + "_" + condName + partName + ...
            sprintf("_%d-%dms", tr), EXPECTED_NAMES, OVERWRITE);
    end
end
fprintf("\n図の出力先：%s\n", saveDir);


%% ローカル関数（scripts/evaluation/grooveBottomDetection/compareWidthThresh.m から写した。
%% 重心法だけにし、点と文字の大きさを STYLE で決めるようにした所と、wideRuns・saveAndClose が違う）
function det = detectPhoto(imgs, dThresh, widthThresh, queryStep)
% 写真1枚分（区間の ImageData の配列 imgs）の溝底点（重心法）を、自動追跡の3つのスクリプトの検出の
% ループと同じ処理で求め、mergeSegmentPoints で写真1枚分の [x y] にする。点ごとの溝底区間の幅
% （最後の行 − 最初の行 [px]。origD なので行の数のまま）も、同じ並びで返す。
% 出力 det のフィールド：pks、width、xQuery
    numSeg = numel(imgs);
    allPts(numSeg,1) = GroovePointCloud();
    widthCells = cell(numSeg,1);
    for jSegment = 1:numSeg
        origImg = imgs(jSegment);
        origD = DarknessMap(origImg);
        origD = origD.setDiffTF(dThresh);
        pts = GroovePointCloud(origD);
        colWidths = cell(origImg.width,1);
        extractor = GrooveExtractor(origD);
        for x = 1:origImg.width
            [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
            [extractor, btmFirstIdx, btmLastIdx, numPeaks] = ...
                extractor.findGrooveBottomIntervals(origD, x, firstIdx, lastIdx, widthThresh);
            pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(origD, x)];
            colWidths{x} = reshape(btmLastIdx - btmFirstIdx, [], 1);
        end
        allPts(jSegment) = pts;
        widthCells{jSegment} = vertcat(zeros(0,1), colWidths{:});
    end
    [pks, xQuery] = mergeSegmentPoints(allPts, QueryStep=queryStep);
    det = struct("pks", pks, "width", vertcat(widthCells{:}), "xQuery", xQuery);
    if numel(det.width) ~= size(pks,1)
        error("wideBottomOutlierWidthThresh:widthCount", "幅の数（%d）が点の数（%d）と違います。", ...
            numel(det.width), size(pks,1));
    end
end

function sel = selectGrooves(result, kind, det, numSegments)
% 保存したクリック位置とパラメータで、データを作ったスクリプトと同じ溝の選択をやり直す。
%   kind "hist"：extractMultiGroove（grooveHist_Ncycle.m）。始点は trackingSeeds の y
%   kind "track"：trackGroove。1周分は trackingSeeds の y で（grooveTrack_1cycle.m）
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
    sel.warnings = strings(0,1);
    for i = 1:numImages
        pks = det{i}.pks;
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

function T = columnTable(sel, det, shapes, amp, fs, devWindow)
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
            [tf, loc] = ismember([xQ(f) y(f)], det{i}.pks, "rows");
            if ~all(tf)
                error("wideBottomOutlierWidthThresh:pointNotDetected", ...
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

function runs = wideRuns(B, A, k, wideMin, devTh, joinGap)
% 列ごとの表 B（直す前）・A（直した後）の行 k（1本の溝・1枚の写真）で、直す前の幅の広い点が続く区間を
% 求める（joinGap 列以下のすき間はつなぐ）。評価スクリプトの runList と同じ列を持つ表を返す
    seg = runsOf(B.found(k) & B.width(k) >= wideMin, joinGap);
    runs = table();
    for r = 1:size(seg,1)
        kk = k(seg(r,1):seg(r,2));
        runs = [runs; table(B.groove(kk(1)), B.photo(kk(1)), B.x(kk(1)), B.x(kk(end)), numel(kk), ...
            nnz(B.found(kk) & B.width(kk) >= wideMin), nnz(abs(B.dev(kk)) > devTh), ...
            max(abs(B.amp(kk))), max(abs(A.amp(kk))), B.timeMs(kk(1)), B.timeMs(kk(end)), ...
            'VariableNames', ["groove","photo","xStart","xEnd","numCols","numWide","numOutliers", ...
            "maxAbsAmpBefore","maxAbsAmpAfter","tStartMs","tEndMs"])]; %#ok<AGROW>
    end
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
% 直す前の色が見える点は、直したことで除いた点である。点はすべて同じ大きさにする
    fig = createFigure([0 0 style.figSizeCrop]);
    fig.Visible = "off";
    tl = tiledlayout(fig, 2, 1, Padding="compact", TileSpacing="compact");
    for t = 1:2
        ax = nexttile(tl);
        imagesc(ax, photo(yr, xr), XData=xr([1 end]), YData=yr([1 end]));
        colormap(ax, gray); clim(ax, [0 255]);   % 撮影画像の表示範囲は [0 255] に固定する
        axis(ax, "image");
        ax.FontSize = style.fontSize;            % tiledlayout が小さくしないように、目盛りの大きさを決める
        ylabel(ax, "$y$ [px]");
        ax.Toolbar.Visible = "off";
    end
    title(tl, titleLines, Interpreter="latex", FontSize=style.fontSize*1.1);
    inView = @(p) p(p(:,1) >= xr(1) & p(:,1) <= xr(end) & p(:,2) >= yr(1) & p(:,2) <= yr(end), :);
    pksAll = inView(pksAll);
    selB = inView(selB);
    selA = inView(selA);
    inX = pathA(:,1) >= xr(1) & pathA(:,1) <= xr(end);
    hold(ax, "on");
    h = gobjects(4,1);
    h(1) = scatter(ax, pksAll(:,1), pksAll(:,2), style.markerSize, style.colorAll, "filled");
    h(2) = scatter(ax, selB(:,1), selB(:,2), style.markerSize, style.colorBefore, "filled");
    h(3) = scatter(ax, selA(:,1), selA(:,2), style.markerSize, style.colorAfter, "filled");
    h(4) = plot(ax, pathA(inX,1), pathA(inX,2), "-", Color=style.colorAfter, LineWidth=style.lineWidthPath);
    hold(ax, "off");
    xlabel(ax, "$x$ [px]");
    lgd = legend(ax, h, ["all groove-bottom points", label.before, label.after, ...
        label.after + " (interpolated)"], Location=style.legendLocation, NumColumns=2, FontSize=style.fontSize*0.9);
    lgd.ItemHitFcn = @togglevisibility;
end

function fig = plotWave(B, A, tr, exact, style, label, titleLines)
% 時間 tr [ms] の範囲の、直す前と後の振幅を重ねる。y が変わった列を塗りつぶした丸で示し、写真の境目に
% 縦の細い実線を引く（補助の線はデータの線より細くする。docs/rules/figures.md「線と点」）。振幅の軸は 0 を中心に
% 上下対称にする（同「軸の範囲」）
    k = find(B.timeMs >= tr(1) & B.timeMs <= tr(2));
    fig = createFigure([0 0 style.figSizeWave]);
    fig.Visible = "off";
    tl = tiledlayout(fig, 1, 1, Padding="compact");
    ax = nexttile(tl);
    ax.FontSize = style.fontSize;
    hold(ax, "on");
    h = gobjects(0,1);
    names = strings(0,1);
    h(end+1) = plot(ax, B.timeMs(k), B.amp(k), "-", Color=style.colorWaveBefore, LineWidth=style.lineWidthBefore);
    names(end+1) = label.before;
    h(end+1) = plot(ax, A.timeMs(k), A.amp(k), "-", Color=style.colorWaveAfter, LineWidth=style.lineWidthAfter);
    names(end+1) = label.after;
    ch = k(abs(A.y(k) - B.y(k)) > exact);
    if ~isempty(ch)
        h(end+1) = plot(ax, A.timeMs(ch), A.amp(ch), "o", Color=style.colorWaveAfter, MarkerSize=style.waveMarkerSize, ...
            MarkerFaceColor=style.colorWaveAfter);
        names(end+1) = "changed columns";
    end
    edges = k(diff([B.photo(k); NaN]) ~= 0 | diff([B.groove(k); NaN]) ~= 0);
    edges = edges(edges < k(end));
    hb = gobjects(0,1);
    for e = edges'
        hb(end+1) = xline(ax, (B.timeMs(e) + B.timeMs(e+1))/2, "k-", LineWidth=style.lineWidthAux); %#ok<AGROW>
    end
    if ~isempty(hb)
        h(end+1) = hb(1);
        names(end+1) = "photo boundary";
    end
    hold(ax, "off");
    grid(ax, "on");
    xlim(ax, tr);
    ampLim = max(1, ceil(max(abs([B.amp(k); A.amp(k)])) / style.ampLimStep) * style.ampLimStep);
    ylim(ax, [-ampLim ampLim]);
    xlabel(ax, "Time [ms]");
    ylabel(ax, "Amplitude");
    title(ax, titleLines);
    legend(ax, h, names, Location=style.legendLocation, FontSize=style.fontSize*0.9);
    ax.Toolbar.Visible = "off";
end

function saveAndClose(fig, saveDir, name, expectedNames, overwrite)
% 名前が評価の図と同じ（expectedNames の中にある）ことを確かめてから、saveFigure で png と fig を
% 保存して閉じる。見えない図のまま fig を保存すると、開いたときにも見えないので、開いたときに
% 見えるようにしておく
    if ~ismember(name, expectedNames)
        close(fig);
        error("wideBottomOutlierWidthThresh:unexpectedName", "評価の図に無い名前です：%s", name);
    end
    fig.CreateFcn = "set(gcbo,'Visible','on')";
    saveFigure(fig, saveDir, name, Overwrite=overwrite);
    close(fig);
    fprintf("保存：%s\n", name);
end
