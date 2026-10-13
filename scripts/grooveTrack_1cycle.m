% grooveTrack_1cycle.m
% 高解像度化していない画像で、写真1枚につき1回のクリックから溝1本を自動追跡し
% （trackGroove）、重心法と局所的最大値法で1周分の音声を作って cycleResult に保存する。
% pkCentroid_1cycle.m の fitGroove＋extractGrooveWaveform（1周80回のginput）を、
% 写真ごとの追跡＋写真ごとの多項式デトレンド（1周8回のginput）に置き換えたもの（issue #25）。
% PREV_RESULT_PATH に以前の結果.matを指定すると、保存したクリック位置（新しい形式の
% grooveSelection.seeds、または手動選択の p1）を使い、ginput なしで再現する。
% 2026/10/13作成

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

% trackGroove のパラメータ。長さはすべて元の画像のpx（高解像度化しても値を変えなくてよい）
TRACK_TOL = 2;          % 予測位置から採る点までの最大距離（y方向）[px]
FIT_LENGTH = 60;        % 予測の直線あてはめに使う範囲（最後に採った点から）[px]
SNAP_RADIUS = 10;       % 始点の初期化でクリック位置から探す範囲（y方向）[px]
INIT_LENGTH = 20;       % 始点の初期化に使う範囲（始点の列から右へ）[px]
MAX_GAP_LENGTH = 40;    % これより長く欠損が続いたら警告する[px]
MIN_FIT_POINTS = 5;     % trackGroove の中の定数（直線あてはめに必要な点の数）。記録用
POLY_DEGREE = 9;        % detrendTrackedShape の次数（写真ごと。issue #25 Q2。評価の結果で見直すことがある）
AMP_DIV = 1.5;          % 振幅の正規化 [px]（既存の tol/2 = 3/2 と同じ。音量を比べられるように）

% 保存用（実行する人が書き換える場所）
date = "MMDD";          % 実行日。図・wavは results/<日付>/、結果.matは experiments/<日付>/
% 以前保存したクリック位置で溝を自動選択する場合は、その結果.matのパスを指定する
% （空文字なら写真ごとに ginput でクリックする。手動選択の結果.matの p1 も使える）
PREV_RESULT_PATH = "";
SAVE_TRACK_FIG = true;  % 写真ごとに追跡結果を画像に重ねた図を results/<日付>/ に保存する

if date == "MMDD"
    error("grooveTrack_1cycle:dateNotSet", ...
        "date を実行日（MMDD）にしてください。既存の results/<日付>/ を上書きしないよう、実行前に確かめてください。");
end
outDir = mkdirFromDate(proj.RootFolder,date);       % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先

isReplay = PREV_RESULT_PATH ~= "";
if isReplay
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    if ~isfield(prevResult,"grooveSelection")
        error("grooveTrack_1cycle:noSelection", ...
            "%s には grooveSelection がありません。", PREV_RESULT_PATH);
    end
    prevSeeds = trackingSeeds(prevResult.grooveSelection, NUM_SEGMENTS);
    if size(prevSeeds,1) ~= NUM_IMAGES
        error("grooveTrack_1cycle:seedCount", ...
            "始点の数(%d)が写真の枚数(%d)と一致しません。", size(prevSeeds,1), NUM_IMAGES);
    end
end

%%
allImg(TOTAL_SEGMENTS,1) = ImageData();
allPts_cnt(TOTAL_SEGMENTS,1) = GroovePointCloud();
allPts_max(TOTAL_SEGMENTS,1) = GroovePointCloud();

% 1周分のデータのx,y座標（保存形式は pkCentroid_1cycle.m と同じセグメントごとのcell）
xcoords = cell(TOTAL_SEGMENTS,1); % xcoordsは共通（セグメントの中のローカルなx）
ycoords_cnt = cell(TOTAL_SEGMENTS,1); % centroid method
ycoords_max = cell(TOTAL_SEGMENTS,1); % local maximum method
allP1 = zeros(TOTAL_SEGMENTS,2); % 追跡した経路のセグメントの両端（古い再現スクリプト用）
allP2 = zeros(TOTAL_SEGMENTS,2);

seeds = zeros(NUM_IMAGES,2);          % 写真ごとのクリック位置（写真1枚分を連結した座標）
yAbsCnt = cell(NUM_IMAGES,1);         % 写真ごとの補間済み・デトレンド前のy座標
yAbsMax = cell(NUM_IMAGES,1);
foundCnt = cell(NUM_IMAGES,1);        % 写真ごとの、点を採れた列
foundMax = cell(NUM_IMAGES,1);
numMissing = zeros(NUM_IMAGES,2);     % [重心法, 局所的最大値法]
maxGapLength = zeros(NUM_IMAGES,2);   % [px]

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

    % 写真1枚分の点群をつなぎ、1回のクリックから溝1本を追跡する
    ks = (iImg-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
    [pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
    pksMax = mergeSegmentPoints(allPts_max(ks), QueryStep=QUERY_STEP);
    if sum(counts) ~= numel(xQuery)
        error("grooveTrack_1cycle:countMismatch", ...
            "写真%d：セグメントの列の数の合計(%d)が xQuery の長さ(%d)と一致しません。", ...
            iImg, sum(counts), numel(xQuery));
    end
    photoImg = ImageData([allImg(ks).img], [iImg;0]); % 高さは同じなので横に連結できる

    if isReplay
        seed = prevSeeds(iImg,:);
    else
        fig = figure;
        photoImg.showImage("fit");
        hold on;
        scatter(pksCnt(:,1), pksCnt(:,2), 2, "cyan", "filled");
        title("写真" + iImg + "：左端付近で追跡する溝をクリック", "Interpreter", "none");
        seed = ginput(1);
        close(fig);
    end

    [ptsCnt, fCnt, infoCnt] = trackGroove(pksCnt, seed, xQuery, Tolerance=TRACK_TOL, ...
        FitLength=FIT_LENGTH, SnapRadius=SNAP_RADIUS, InitLength=INIT_LENGTH, ...
        MaxGapLength=MAX_GAP_LENGTH);
    [ptsMax, fMax, infoMax] = trackGroove(pksMax, seed, xQuery, Tolerance=TRACK_TOL, ...
        FitLength=FIT_LENGTH, SnapRadius=SNAP_RADIUS, InitLength=INIT_LENGTH, ...
        MaxGapLength=MAX_GAP_LENGTH);

    % 写真ごとにデトレンドし（平均0）、保存形式を既存と同じにするためセグメントごとに分け直す
    detCnt = detrendTrackedShape(ptsCnt, PolyDegree=POLY_DEGREE);
    detMax = detrendTrackedShape(ptsMax, PolyDegree=POLY_DEGREE);
    ycoords_cnt(ks) = mat2cell(detCnt(:,2), counts);
    ycoords_max(ks) = mat2cell(detMax(:,2), counts);

    widths = [allPts_cnt(ks).width]';
    for jSegment=1:NUM_SEGMENTS
        xcoords{ks(jSegment)} = (1:QUERY_STEP:widths(jSegment))';
    end

    % p1/p2：追跡した重心法のy座標（補間済み、デトレンド前）の、各セグメントの左端・右端
    lastIdx = cumsum(counts);
    firstIdx = lastIdx - counts + 1;
    allP1(ks,:) = [ones(NUM_SEGMENTS,1), ptsCnt(firstIdx,2)];
    allP2(ks,:) = [widths, ptsCnt(lastIdx,2)];

    seeds(iImg,:) = seed;
    yAbsCnt{iImg} = ptsCnt(:,2);
    yAbsMax{iImg} = ptsMax(:,2);
    foundCnt{iImg} = fCnt;
    foundMax{iImg} = fMax;
    numMissing(iImg,:) = [infoCnt.numMissing, infoMax.numMissing];
    maxGapLength(iImg,:) = [infoCnt.maxGapLength, infoMax.maxGapLength];

    if SAVE_TRACK_FIG
        if isReplay
            fig = figure('Visible','off', 'Position', [50 50 1600 300]);
        else
            fig = figure('Position', [50 50 1600 300]);
        end
        photoImg.showImage("fit");
        hold on;
        plot(ptsCnt(:,1), ptsCnt(:,2), "r-", "LineWidth", 0.5);
        plot(seed(1), seed(2), "y^", "MarkerFaceColor", "y", "MarkerSize", 6);
        title("写真" + iImg + "：追跡した溝（赤、重心法）とクリック位置（黄）", "Interpreter", "none");
        exportgraphics(fig, outDir + "grooveTrack_img" + iImg + ".png", "Resolution", 250);
        close(fig);
    end
end % for iImg = 1:NUM_IMAGES


%%
y_comb_cnt = vertcat(ycoords_cnt{:}); % 写真ごとに平均0にしたy座標を連結したもの（保存用）
y_comb_max = vertcat(ycoords_max{:});

num_samples = length(y_comb_cnt);
fs = round(num_samples / (60/RPM));

amp_cnt = (y_comb_cnt - mean(y_comb_cnt)) / AMP_DIV;
amp_max = (y_comb_max - mean(y_comb_max)) / AMP_DIV;

% 同じ日に pkCentroid_1cycle.m（手動選択）を実行しても wav・図の名前が重ならないよう、
% 名前に (tracking) を付ける
trackCntAudio = AudioData("audio (centroid method)(original)(tracking)", amp_cnt, fs);
trackMaxAudio = AudioData("audio (local maximum method)(original)(tracking)", amp_max, fs);

for audio = [trackMaxAudio, trackCntAudio]
    fig = figure;audio.plotWaveform();
    saveas(fig,outDir+audio.filename+"_amp","fig");saveas(fig,outDir+audio.filename+"_amp","png");close(fig);

    fig = figure;audio.plotFFT();
    saveas(fig,outDir+audio.filename+"_fft","fig");saveas(fig,outDir+audio.filename+"_fft","png");close(fig);

    fig = figure;audio.plotSpectrogram(1024);
    saveas(fig,outDir+audio.filename+"_stft","fig");saveas(fig,outDir+audio.filename+"_stft","png");close(fig);

    audio.saveAudio(outDir);
end


%%
% 追跡で使わない必須の引数（ThHist・BinWidth・HPrl・Tol）には NaN を渡す。
% 追跡のパラメータは grooveSelection.tracking に入れる
cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=outDir,ExperimentDir=expDir,...
    LMask=L_MASK,ThHist=NaN,DThresh=D_THRESH,WTh=WIDTH_THRESH,...
    Tol=NaN,BinWidth=NaN,HPrl=NaN,PolyDegree=POLY_DEGREE,Rpm=RPM,...
    NumImages=NUM_IMAGES,NumSegments=NUM_SEGMENTS,Filenames=filenames_new,...
    ScriptName="grooveTrack_1cycle",Note="自動追跡（パラメータは grooveSelection.tracking）");

res_cnt = cycleMethodResult("centroid", allPts_cnt, xcoords, ycoords_cnt, y_comb_cnt, trackCntAudio);
res_max = cycleMethodResult("localMax", allPts_max, xcoords, ycoords_max, y_comb_max, trackMaxAudio);

% cell を struct() に直接渡すと struct 配列になるので、dot記法で組み立てる
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
trk.yAbsCnt = yAbsCnt;
trk.yAbsMax = yAbsMax;
trk.foundCnt = foundCnt;
trk.foundMax = foundMax;

grooveSelection = struct();
grooveSelection.p1 = allP1;
grooveSelection.p2 = allP2;
grooveSelection.method = "tracking";
grooveSelection.seeds = seeds;
grooveSelection.tracking = trk;

matPath = saveCycleResult(cond, allImg, [res_cnt res_max], ...
    GrooveSelection=grooveSelection, FileName="cycleResult_origD_track_"+date, Overwrite=false);

fprintf("\n写真ごとの追跡の欠損（列の数 / 最も長い連続欠損[px]）\n");
for iImg=1:NUM_IMAGES
    fprintf("  写真%d：重心法 %d / %g、局所的最大値法 %d / %g\n", iImg, ...
        numMissing(iImg,1), maxGapLength(iImg,1), numMissing(iImg,2), maxGapLength(iImg,2));
end
