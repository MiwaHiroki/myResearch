% grooveHist_Ncycle.m
% 高解像度化していない画像で、写真1枚につき1回のクリックから NUM_GROOVES 本の溝を取り出し、
% 重心法と局所的最大値法で N周分の音声を作って cycleResult に保存する（issue #30）。
% 1本目は grooveTrack_1cycle.m と同じく trackGroove で追跡して写真ごとに9次でデトレンドし、
% 2本目以降は、1本目の多項式で写真全体の点の傾きを補正した y のヒストグラムの山から、
% y座標が小さい側（レコードの内側）へ順に選ぶ（extractMultiGroove。旧
% scripts/archive/Ncycle_omitMask.m のヒストグラムによる溝の選択と同じ考え方）。
% shapes{i,j}（i枚目の写真のj本目の溝）を列の順に連結した vertcat(shapes{:}) が再生順になる
% （j本目の写真8の次に、j+1本目の写真1が続くため）。
% PREV_RESULT_PATH に以前の結果.matを指定すると、保存したクリック位置（grooveSelection.seeds、
% または手動選択の p1）を使い、ginput なしで再現する。
% 2026/10/28作成

setDefaultIntrpr();
proj = currentProject();

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_IMAGES * NUM_SEGMENTS; % 全部で80枚の画像

filenames_new = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end

L_MASK = 20;        % Maskを取るためのluminanceのthreshold, 0付近に設定する（pkCentroid_1cycle.m と同じ）
D_THRESH = 0.6;     % 暗さのしきい値（pkCentroid_1cycle.m と同じ）
WIDTH_THRESH = 8;   % 溝底区間の幅のしきい値[px]（pkCentroid_1cycle.m と同じ）
QUERY_STEP = 1;     % 列の間隔[px]。今回は高解像度化なし（origD）なので1
RPM = 78;           % 回転数[rpm]。1周分のサンプル数から標本化周波数を決める

% 1本目の trackGroove のパラメータ（grooveTrack_1cycle.m と同じ）。長さはすべて元の画像のpx
TRACK_TOL = 2;          % 予測位置から採る点までの最大距離（y方向）[px]
FIT_LENGTH = 60;        % 予測の直線あてはめに使う範囲（最後に採った点から）[px]
SNAP_RADIUS = 10;       % 始点の初期化でクリック位置から探す範囲（y方向）[px]
INIT_LENGTH = 20;       % 始点の初期化に使う範囲（始点の列から右へ）[px]
MAX_GAP_LENGTH = 40;    % これより長く欠損が続いたら警告する[px]
MIN_FIT_POINTS = 5;     % trackGroove の中の定数（直線あてはめに必要な点の数）。記録用
POLY_DEGREE = 9;        % detrendTrackedShape の次数（写真ごと。すべての溝で同じ。issue #30 Q2）
AMP_DIV = 1.5;          % 振幅の正規化 [px]（grooveTrack_1cycle.m と同じ。issue #30 Q3）

% 複数本の溝
NUM_GROOVES = 5;          % 抽出する溝の本数（=周の数）。1本目はクリックした溝、2本目以降はy座標が小さい側（内側）
CLICK_VIEW_WIDTH = 300;   % クリックの図に表示する、写真の左端からの幅[px]（溝の間が画面で広く見えるように）
BIN_WIDTH = 1;            % ヒストグラムのビンの幅[px]（ビンの中心と溝の中心のずれを0.5px以下にする。issue #30 Q1）
TH_HIST_RATIO = 0.3;      % 山とみなす高さ（写真の列の数に対する割合。実データで0.20〜0.45なら同じ山を選ぶ）
BAND_TOL = 3;             % 帯の半分の幅[px]（実データで帯から落ちる点・同じ列の2点が0）

% 保存用（実行する人が書き換える場所）
date = "MMDD";          % 実行日。図・wavは results/<日付>/、結果.matは experiments/<日付>/
% 以前保存したクリック位置で1本目を選ぶ場合は、その結果.matのパスを指定する
% （空文字なら写真ごとに ginput でクリックする。grooveTrack_1cycle.m・grooveTrack_Ncycle.m の
% 結果、手動選択の結果.matの p1 も使える）
PREV_RESULT_PATH = "";
SAVE_FIG = true;        % 写真ごとに、N本の経路の図とヒストグラムの図を results/<日付>/ に保存する

if date == "MMDD"
    error("grooveHist_Ncycle:dateNotSet", ...
        "date を実行日（MMDD）にしてください。既存の results/<日付>/ を上書きしないよう、実行前に確かめてください。");
end
outDir = mkdirFromDate(proj.RootFolder,date);       % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先

isReplay = PREV_RESULT_PATH ~= "";
if isReplay
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    if ~isfield(prevResult,"grooveSelection")
        error("grooveHist_Ncycle:noSelection", ...
            "%s には grooveSelection がありません。", PREV_RESULT_PATH);
    end
    prevSeeds = trackingSeeds(prevResult.grooveSelection, NUM_SEGMENTS);
    if size(prevSeeds,1) ~= NUM_IMAGES
        error("grooveHist_Ncycle:seedCount", ...
            "始点の数(%d)が写真の枚数(%d)と一致しません。", size(prevSeeds,1), NUM_IMAGES);
    end
end

% extractMultiGroove に渡す引数（重心法・局所的最大値法で同じ）
mgArgs = {"TrackTolerance",TRACK_TOL, "FitLength",FIT_LENGTH, "SnapRadius",SNAP_RADIUS, ...
    "InitLength",INIT_LENGTH, "MaxGapLength",MAX_GAP_LENGTH, "PolyDegree",POLY_DEGREE, ...
    "BinWidth",BIN_WIDTH, "MinPeakRatio",TH_HIST_RATIO, "BandTolerance",BAND_TOL};

%%
allImg(TOTAL_SEGMENTS,1) = ImageData();
allPts_cnt(TOTAL_SEGMENTS,1) = GroovePointCloud();
allPts_max(TOTAL_SEGMENTS,1) = GroovePointCloud();

% N周分のデータのx,y座標（セグメントごとのcell。j列目が j周目＝j本目の溝）
xcoords = cell(TOTAL_SEGMENTS,NUM_GROOVES); % xcoordsは共通（セグメントの中のローカルなx）
ycoords_cnt = cell(TOTAL_SEGMENTS,NUM_GROOVES); % centroid method
ycoords_max = cell(TOTAL_SEGMENTS,NUM_GROOVES); % local maximum method
shapesCnt = cell(NUM_IMAGES,NUM_GROOVES);       % i枚目の写真のj本目の溝 [xQuery, y]（デトレンド後）
shapesMax = cell(NUM_IMAGES,NUM_GROOVES);
allP1 = zeros(TOTAL_SEGMENTS,2); % 1本目の経路のセグメントの両端（古い再現スクリプト用）
allP2 = zeros(TOTAL_SEGMENTS,2);

seeds = zeros(NUM_IMAGES,2);                    % 写真ごとの1本目の始点 [x y]（xは1列目に固定）
yAbsCnt = cell(NUM_IMAGES,NUM_GROOVES);         % 補間済み・デトレンド前のy座標（元の画像のpx）
yAbsMax = cell(NUM_IMAGES,NUM_GROOVES);
foundCnt = cell(NUM_IMAGES,NUM_GROOVES);        % 点を採れた列（1本目は追跡、2本目以降は帯）
foundMax = cell(NUM_IMAGES,NUM_GROOVES);
centersCnt = zeros(NUM_IMAGES,NUM_GROOVES);     % 補正後の山の中心[px]
centersMax = zeros(NUM_IMAGES,NUM_GROOVES);
numDupCnt = zeros(NUM_IMAGES,NUM_GROOVES);      % 帯の中に2点以上あった列の数
numDupMax = zeros(NUM_IMAGES,NUM_GROOVES);
trendCnt = cell(NUM_IMAGES,1);                  % 1本目の多項式（detrendTrackedShape の2つ目の出力）
trendMax = cell(NUM_IMAGES,1);

for iImg=1:NUM_IMAGES
    img_new = imread(filenames_new(9-iImg) + ".png");
    img_gray = rgb2gray(img_new);
    [~,width] = size(img_gray);

    divWidth = round(width / NUM_SEGMENTS);
    xarray = [1:divWidth:width width+1]';

    % マスク（omitMask で落とす低輝度の列）は写真の両端にしか無いので、将来は
    % 写真1枚単位で omitMask〜GrooveExtractor を行う形に変える可能性がある。
    % 今回は既存の保存形式（pts が 80x1）を保つため、セグメントごとに行う。
    for jSegment=1:NUM_SEGMENTS
        kImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % 何番目のimgSmallか。kImgSmall = 1 ~ TOTAL_SEGMENTS

        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);
        img_omitMask = omitMask(img_small, L_MASK);
        origImg = ImageData(img_omitMask, [iImg;jSegment]);

        origD = DarknessMap(origImg);
        origD = origD.setDiffTF(D_THRESH);

        pts_cnt = GroovePointCloud(origD);
        pts_max = GroovePointCloud(origD);

        extractor = GrooveExtractor(origD);
        for x=1:origImg.width
            [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
            [extractor,~,~,numPeaks] = ...
                extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,WIDTH_THRESH);

            centroidY = extractor.extractByCentroid(origD,x);
            maxY = extractor.extractByLocalMax(origD,x);

            pts_cnt.peakCells{x} = [x*ones(numPeaks,1), centroidY];
            pts_max.peakCells{x} = [x*ones(numPeaks,1), maxY];
        end

        allImg(kImgSmall) = origImg;
        allPts_cnt(kImgSmall) = pts_cnt;
        allPts_max(kImgSmall) = pts_max;
    end % for jSegment=1:NUM_SEGMENTS

    % 写真1枚分の点群をつなぎ、1回のクリックから NUM_GROOVES 本の溝を取り出す
    ks = (iImg-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
    [pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
    pksMax = mergeSegmentPoints(allPts_max(ks), QueryStep=QUERY_STEP);
    if sum(counts) ~= numel(xQuery)
        error("grooveHist_Ncycle:countMismatch", ...
            "写真%d：セグメントの列の数の合計(%d)が xQuery の長さ(%d)と一致しません。", ...
            iImg, sum(counts), numel(xQuery));
    end
    photoImg = ImageData([allImg(ks).img], [iImg;0]); % 高さは同じなので横に連結できる

    if isReplay
        seed = prevSeeds(iImg,:);
    else
        % trackGroove の始点の初期化は1列目から INIT_LENGTH の範囲だけを見るので、左端を拡大する
        fig = figure;
        photoImg.showImage("fit");
        hold on;
        inView = pksCnt(:,1) <= CLICK_VIEW_WIDTH;
        scatter(pksCnt(inView,1), pksCnt(inView,2), 4, "cyan", "filled");
        xlim([0.5, CLICK_VIEW_WIDTH+0.5]);
        title("写真" + iImg + "：左端の近くで、1本目（最も外側＝下）の溝を1回クリック（yだけを使う）", ...
            "Interpreter", "none");
        seed = ginput(1);
        close(fig);
    end
    % 始点のxは、クリックした位置によらず写真の1列目に固定し、yだけを使う
    % （grooveTrack_1cycle.m と同じ規則。以前の結果から再現するときも同じ）
    seed = [xQuery(1), seed(2)];

    [shapesCnt(iImg,:), infoCnt] = runMultiGroove(pksCnt, seed, xQuery, NUM_GROOVES, mgArgs, iImg, "重心法");
    [shapesMax(iImg,:), infoMax] = runMultiGroove(pksMax, seed, xQuery, NUM_GROOVES, mgArgs, iImg, "局所的最大値法");

    % 保存形式に合わせ、j本目の溝をセグメントごとに分け直す（80 x N）
    widths = [allPts_cnt(ks).width]';
    for jGroove=1:NUM_GROOVES
        ycoords_cnt(ks,jGroove) = mat2cell(shapesCnt{iImg,jGroove}(:,2), counts);
        ycoords_max(ks,jGroove) = mat2cell(shapesMax{iImg,jGroove}(:,2), counts);
        for jSegment=1:NUM_SEGMENTS
            xcoords{ks(jSegment),jGroove} = (1:QUERY_STEP:widths(jSegment))';
        end
        yAbsCnt{iImg,jGroove} = infoCnt.yAbs(:,jGroove);
        yAbsMax{iImg,jGroove} = infoMax.yAbs(:,jGroove);
        foundCnt{iImg,jGroove} = infoCnt.found(:,jGroove);
        foundMax{iImg,jGroove} = infoMax.found(:,jGroove);
    end

    % p1/p2：1本目（重心法）のy座標（補間済み、デトレンド前）の、各セグメントの左端・右端
    lastIdx = cumsum(counts);
    firstIdx = lastIdx - counts + 1;
    allP1(ks,:) = [ones(NUM_SEGMENTS,1), infoCnt.yAbs(firstIdx,1)];
    allP2(ks,:) = [widths, infoCnt.yAbs(lastIdx,1)];

    seeds(iImg,:) = seed;
    centersCnt(iImg,:) = infoCnt.centers';
    centersMax(iImg,:) = infoMax.centers';
    numDupCnt(iImg,:) = infoCnt.numDuplicateCols;
    numDupMax(iImg,:) = infoMax.numDuplicateCols;
    trendCnt{iImg} = infoCnt.trend;
    trendMax{iImg} = infoMax.trend;

    fprintf("写真%d\n", iImg);
    fprintf("  山の中心[px]       重心法 %s、局所的最大値法 %s\n", ...
        mat2str(centersCnt(iImg,:), 4), mat2str(centersMax(iImg,:), 4));
    fprintf("  点が無かった列     重心法 %s、局所的最大値法 %s\n", ...
        mat2str(sum(~infoCnt.found,1)), mat2str(sum(~infoMax.found,1)));
    fprintf("  同じ列に2点以上    重心法 %s、局所的最大値法 %s\n", ...
        mat2str(numDupCnt(iImg,:)), mat2str(numDupMax(iImg,:)));

    if SAVE_FIG
        savePathFigure(photoImg, infoCnt.yAbs, seed, isReplay, ...
            "写真" + iImg + "：取り出した " + NUM_GROOVES + " 本の溝（重心法）と1本目の始点（黄）", ...
            outDir + "grooveHist_img" + iImg + ".png");
        saveHistogramFigure(infoCnt, NUM_GROOVES, isReplay, ...
            "写真" + iImg + "：補正後の y のヒストグラム（重心法）", ...
            outDir + "grooveHist_histogram_img" + iImg + ".png");
    end
end % for iImg = 1:NUM_IMAGES


%%
y_comb_cnt = vertcat(ycoords_cnt{:}); % 列の順（1本目の80セグメント → 2本目 …）がそのまま再生順
y_comb_max = vertcat(ycoords_max{:});
allShapesCnt = vertcat(shapesCnt{:});
allShapesMax = vertcat(shapesMax{:});
if ~isequal(allShapesCnt(:,2), y_comb_cnt) || ~isequal(allShapesMax(:,2), y_comb_max)
    error("grooveHist_Ncycle:orderMismatch", ...
        "vertcat(shapes{:}) と vertcat(ycoords{:}) が一致しません（並べ方の誤り）。");
end

num_samples = sum(cellfun(@numel, ycoords_cnt(:,1))); % 1周分のサンプル数
fs = round(num_samples / (60/RPM));

amp_cnt = (y_comb_cnt - mean(y_comb_cnt)) / AMP_DIV;
amp_max = (y_comb_max - mean(y_comb_max)) / AMP_DIV;
fprintf("\nfs = %d Hz、±1 を超えたサンプル：重心法 %d、局所的最大値法 %d（全 %d サンプル）\n", ...
    fs, nnz(abs(amp_cnt) > 1), nnz(abs(amp_max) > 1), numel(amp_cnt));

% 同じ日に grooveTrack_1cycle.m・grooveTrack_Ncycle.m を実行しても wav・図の名前が重ならないよう、
% 名前に (hist N cycles) を付ける
histCntAudio = AudioData("audio (centroid method)(original)(hist " + NUM_GROOVES + " cycles)", amp_cnt, fs);
histMaxAudio = AudioData("audio (local maximum method)(original)(hist " + NUM_GROOVES + " cycles)", amp_max, fs);

for audio = [histMaxAudio, histCntAudio]
    fig = figure;audio.plotWaveform();
    saveas(fig,outDir+audio.filename+"_amp","fig");saveas(fig,outDir+audio.filename+"_amp","png");close(fig);

    fig = figure;audio.plotFFT();
    saveas(fig,outDir+audio.filename+"_fft","fig");saveas(fig,outDir+audio.filename+"_fft","png");close(fig);

    fig = figure;audio.plotSpectrogram(1024);
    saveas(fig,outDir+audio.filename+"_stft","fig");saveas(fig,outDir+audio.filename+"_stft","png");close(fig);

    audio.saveAudio(outDir);
end


%%
% しきい値は列の数に対する割合になり旧 ThHist と意味が変わるので ThHist に NaN を渡し、
% grooveSelection.multiGroove.thHistRatio に入れる。HPrl（平行四辺形の高さ）も使わない
cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=outDir,ExperimentDir=expDir,...
    LMask=L_MASK,ThHist=NaN,DThresh=D_THRESH,WTh=WIDTH_THRESH,...
    Tol=BAND_TOL,BinWidth=BIN_WIDTH,HPrl=NaN,PolyDegree=POLY_DEGREE,Rpm=RPM,...
    NumImages=NUM_IMAGES,NumSegments=NUM_SEGMENTS,Filenames=filenames_new,...
    ScriptName="grooveHist_Ncycle",...
    Note="N周分（NUM_GROOVES=" + NUM_GROOVES + "、ヒストグラムで2本目以降を選択。パラメータは grooveSelection.multiGroove）");

res_cnt = cycleMethodResult("centroid", allPts_cnt, xcoords, ycoords_cnt, y_comb_cnt, histCntAudio);
res_max = cycleMethodResult("localMax", allPts_max, xcoords, ycoords_max, y_comb_max, histMaxAudio);

% cell を struct() に直接渡すと struct 配列になるので、dot記法で組み立てる
% 1本目の追跡（grooveTrack_1cycle.m と同じフィールド）
trk = struct();
trk.tolerance = TRACK_TOL;
trk.fitLength = FIT_LENGTH;
trk.snapRadius = SNAP_RADIUS;
trk.initLength = INIT_LENGTH;
trk.maxGapLength = MAX_GAP_LENGTH;
trk.minFitPoints = MIN_FIT_POINTS;
trk.queryStep = QUERY_STEP;
trk.polyDegree = POLY_DEGREE;
trk.detrendScope = "photo";
trk.ampDivisor = AMP_DIV;
trk.yAbsCnt = yAbsCnt(:,1);
trk.yAbsMax = yAbsMax(:,1);
trk.foundCnt = foundCnt(:,1);
trk.foundMax = foundMax(:,1);

% 複数本の溝
mg = struct();
mg.numGrooves = NUM_GROOVES;
mg.binWidth = BIN_WIDTH;
mg.thHistRatio = TH_HIST_RATIO;
mg.bandTol = BAND_TOL;
mg.polyDegree = POLY_DEGREE;
mg.detrendScope = "photo";
mg.ampDivisor = AMP_DIV;
mg.centersCnt = centersCnt;
mg.centersMax = centersMax;
mg.yAbsCnt = yAbsCnt;
mg.yAbsMax = yAbsMax;
mg.foundCnt = foundCnt;
mg.foundMax = foundMax;
mg.numDupCnt = numDupCnt;
mg.numDupMax = numDupMax;
mg.trendCnt = trendCnt;
mg.trendMax = trendMax;

grooveSelection = struct();
grooveSelection.p1 = allP1;
grooveSelection.p2 = allP2;
grooveSelection.method = "histogram";
grooveSelection.seeds = seeds;
grooveSelection.tracking = trk;
grooveSelection.multiGroove = mg;

matPath = saveCycleResult(cond, allImg, [res_cnt res_max], GrooveSelection=grooveSelection, ...
    FileName="cycleResult_origD_hist" + NUM_GROOVES + "_" + date, Overwrite=false);


%%
function [shapes, info] = runMultiGroove(pks, seed, xQuery, numGrooves, mgArgs, iImg, methodName)
% extractMultiGroove を呼び、エラーなら写真の番号と手法を書いて出し直す
% （どの写真で止まったかを分かるようにするため）
    try
        [shapes, info] = extractMultiGroove(pks, seed, xQuery, numGrooves, mgArgs{:});
    catch cause
        err = MException("grooveHist_Ncycle:grooveSelectionFailed", ...
            "写真%d（%s）で %d 本の溝を取り出せませんでした：%s", ...
            iImg, methodName, numGrooves, cause.message);
        err = addCause(err, cause);
        throw(err);
    end
end

function savePathFigure(photoImg, yAbs, seed, isReplay, titleText, filePath)
% 写真に N 本の経路を色を変えて重ね、1本目の始点を黄色の三角で示した図を保存する
    if isReplay
        fig = figure('Visible','off', 'Position', [50 50 1600 300]);
    else
        fig = figure('Position', [50 50 1600 300]);
    end
    photoImg.showImage("fit");
    hold on;
    numGrooves = size(yAbs,2);
    colors = lines(numGrooves);
    x = (1:size(yAbs,1))';
    for j = 1:numGrooves
        plot(x, yAbs(:,j), "-", "Color", colors(j,:), "LineWidth", 0.5);
    end
    plot(seed(1), seed(2), "y^", "MarkerFaceColor", "y", "MarkerSize", 6);
    title(titleText, "Interpreter", "none");
    exportgraphics(fig, filePath, "Resolution", 250);
    close(fig);
end

function saveHistogramFigure(info, numGrooves, isReplay, titleText, filePath)
% 補正後の y のヒストグラム（横軸に点の数、縦軸に y。画像と同じく y の小さい側を上）に、
% しきい値の線と選んだ山の印を描いて保存する
    if isReplay
        fig = figure('Visible','off');
    else
        fig = figure;
    end
    h = info.hist;
    barh(h.binCenters, h.counts, 1, "FaceColor", [0.6 0.6 0.6], "EdgeColor", "none");
    hold on;
    xline(info.minPeakHeight, "r--", "しきい値", "Interpreter", "none");
    selIdx = h.firstIdx:-1:h.firstIdx-numGrooves+1;
    plot(h.peakHeights(selIdx), h.peakCenters(selIdx), "ro", "MarkerSize", 6);
    set(gca, "YDir", "reverse");
    ylim([info.centers(end) - 20, info.centers(1) + 20]);
    xlabel("点の数", "Interpreter", "none");
    ylabel("補正後の y [px]", "Interpreter", "none");
    title(titleText, "Interpreter", "none");
    exportgraphics(fig, filePath, "Resolution", 200);
    close(fig);
end
