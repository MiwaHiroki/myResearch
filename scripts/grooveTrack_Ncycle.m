% grooveTrack_Ncycle.m
% grooveHist_Ncycle.m（ヒストグラムで2本目以降を選ぶ本実装）を評価するための正解データを作る。
% 写真ごとに NUM_GROOVES 本の溝の左端付近をクリックし（8 x N 回の ginput）、それぞれを
% trackGroove → detrendTrackedShape（grooveTrack_1cycle.m と同じ処理）で別々に追跡して、
% 重心法と局所的最大値法で N周分の音声を作り、cycleResult に保存する（issue #30）。
% クリックは y の大きい順（外側から）に並べ替えて1本目〜N本目にする（クリックの順によらない）。
% shapes{i,j} を列の順に連結した vertcat(shapes{:}) が再生順になる（grooveHist_Ncycle.m と同じ）。
% PREV_RESULT_PATH に以前の正解データを指定すると、保存した multiGroove.seedsY で ginput なしに
% 再現する。RECLICK_IMAGES に書いた写真だけ、もう一度クリックする（飛び移りがあった写真だけ直すため）。
% GUIDE_RESULT_PATH に以前の結果（例：1014 の追跡）を指定すると、その1本目の始点の y を
% クリックの図に黄色の三角で示す（1本目を #25 と同じ溝にするため）。
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

% trackGroove のパラメータ（grooveTrack_1cycle.m と同じ）。長さはすべて元の画像のpx
TRACK_TOL = 2;          % 予測位置から採る点までの最大距離（y方向）[px]
FIT_LENGTH = 60;        % 予測の直線あてはめに使う範囲（最後に採った点から）[px]
SNAP_RADIUS = 10;       % 始点の初期化でクリック位置から探す範囲（y方向）[px]
INIT_LENGTH = 20;       % 始点の初期化に使う範囲（始点の列から右へ）[px]
MAX_GAP_LENGTH = 40;    % これより長く欠損が続いたら警告する[px]
MIN_FIT_POINTS = 5;     % trackGroove の中の定数（直線あてはめに必要な点の数）。記録用
POLY_DEGREE = 9;        % detrendTrackedShape の次数（写真ごと。すべての溝で同じ）
AMP_DIV = 1.5;          % 振幅の正規化 [px]（grooveHist_Ncycle.m と同じ）

% 複数本の溝
NUM_GROOVES = 5;          % 追跡する溝の本数（=周の数）。1本目は最も外側（yが大きい側）の溝
CLICK_VIEW_WIDTH = 300;   % クリックの図に表示する、写真の左端からの幅[px]（溝の間が画面で広く見えるように）
MIN_SEED_GAP = 13;        % 隣どうしの始点がこれより近ければ警告[px]（溝の間隔 25.5〜28.4px の約半分）
RECLICK_IMAGES = [];      % PREV_RESULT_PATH から再現するとき、もう一度クリックする写真の番号（例：[3 7]）
GUIDE_RESULT_PATH = "";   % 1本目の目安（以前の結果.matの始点）を図に示す。空文字なら示さない

% 保存用（実行する人が書き換える場所）
date = "MMDD";          % 実行日。図・wavは results/<日付>/、結果.matは experiments/<日付>/
% 以前保存した正解データのクリック位置で再現する場合は、その結果.matのパスを指定する
% （空文字なら写真ごとに ginput でクリックする）
PREV_RESULT_PATH = "";
SAVE_FIG = true;        % 写真ごとに、N本の経路の図を results/<日付>/ に保存する

if date == "MMDD"
    error("grooveTrack_Ncycle:dateNotSet", ...
        "date を実行日（MMDD）にしてください。既存の results/<日付>/ を上書きしないよう、実行前に確かめてください。");
end
outDir = mkdirFromDate(proj.RootFolder,date);       % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先

isReplay = PREV_RESULT_PATH ~= "";
if isReplay
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    if ~isfield(prevResult,"grooveSelection") || ~isfield(prevResult.grooveSelection,"multiGroove") ...
            || ~isfield(prevResult.grooveSelection.multiGroove,"seedsY") ...
            || size(prevResult.grooveSelection.multiGroove.seedsY,2) ~= NUM_GROOVES ...
            || size(prevResult.grooveSelection.multiGroove.seedsY,1) ~= NUM_IMAGES
        error("grooveTrack_Ncycle:noSeeds", ...
            "%s に、%d x %d の grooveSelection.multiGroove.seedsY がありません。", ...
            PREV_RESULT_PATH, NUM_IMAGES, NUM_GROOVES);
    end
    prevSeedsY = prevResult.grooveSelection.multiGroove.seedsY;
end
isGuide = GUIDE_RESULT_PATH ~= "";
if isGuide
    guideResult = loadCycleResult(GUIDE_RESULT_PATH);
    guideSeeds = trackingSeeds(guideResult.grooveSelection, NUM_SEGMENTS);
end

% trackGroove に渡す引数（すべての溝・両手法で同じ）
trackArgs = {"Tolerance",TRACK_TOL, "FitLength",FIT_LENGTH, "SnapRadius",SNAP_RADIUS, ...
    "InitLength",INIT_LENGTH, "MaxGapLength",MAX_GAP_LENGTH};

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

seedsY = zeros(NUM_IMAGES,NUM_GROOVES);         % クリックのy（行ごとに大きい順＝外側から）
yAbsCnt = cell(NUM_IMAGES,NUM_GROOVES);         % 補間済み・デトレンド前のy座標（元の画像のpx）
yAbsMax = cell(NUM_IMAGES,NUM_GROOVES);
foundCnt = cell(NUM_IMAGES,NUM_GROOVES);        % 点を採れた列
foundMax = cell(NUM_IMAGES,NUM_GROOVES);
y0Cnt = zeros(NUM_IMAGES,NUM_GROOVES);          % trackGroove が初期化で決めた始点のy
y0Max = zeros(NUM_IMAGES,NUM_GROOVES);

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

    % 写真1枚分の点群をつなぎ、N回のクリックから N本の溝を別々に追跡する
    ks = (iImg-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
    [pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
    pksMax = mergeSegmentPoints(allPts_max(ks), QueryStep=QUERY_STEP);
    if sum(counts) ~= numel(xQuery)
        error("grooveTrack_Ncycle:countMismatch", ...
            "写真%d：セグメントの列の数の合計(%d)が xQuery の長さ(%d)と一致しません。", ...
            iImg, sum(counts), numel(xQuery));
    end
    photoImg = ImageData([allImg(ks).img], [iImg;0]); % 高さは同じなので横に連結できる

    needClick = ~isReplay || ismember(iImg, RECLICK_IMAGES);
    if needClick
        % trackGroove の始点の初期化は1列目から INIT_LENGTH の範囲だけを見るので、左端を拡大する
        fig = figure;
        photoImg.showImage("fit");
        hold on;
        inView = pksCnt(:,1) <= CLICK_VIEW_WIDTH;
        scatter(pksCnt(inView,1), pksCnt(inView,2), 4, "cyan", "filled");
        if isGuide
            plot(xQuery(1), guideSeeds(iImg,2), "y^", "MarkerFaceColor", "y", "MarkerSize", 8);
        end
        xlim([0.5, CLICK_VIEW_WIDTH+0.5]);
        title("写真" + iImg + "：左端の近くで、外側（下）の溝から " + NUM_GROOVES + ...
            " 本をクリック（順不同、yだけを使う。黄色の三角は1本目の目安）", "Interpreter", "none");
        clicks = ginput(NUM_GROOVES);
        close(fig);
        if size(clicks,1) ~= NUM_GROOVES
            error("grooveTrack_Ncycle:clickCount", ...
                "写真%d：クリックの数(%d)が NUM_GROOVES(%d)と違います。", ...
                iImg, size(clicks,1), NUM_GROOVES);
        end
        seedsY(iImg,:) = sort(clicks(:,2), "descend")';
    else
        seedsY(iImg,:) = prevSeedsY(iImg,:);
    end

    widths = [allPts_cnt(ks).width]';
    for jGroove=1:NUM_GROOVES
        % 始点のxは、クリックした位置によらず写真の1列目に固定し、yだけを使う
        % （grooveTrack_1cycle.m と同じ規則）
        seed = [xQuery(1), seedsY(iImg,jGroove)];
        [ptsCnt, fCnt, infoCnt] = trackGroove(pksCnt, seed, xQuery, trackArgs{:});
        [ptsMax, fMax, infoMax] = trackGroove(pksMax, seed, xQuery, trackArgs{:});

        shapesCnt{iImg,jGroove} = detrendTrackedShape(ptsCnt, PolyDegree=POLY_DEGREE);
        shapesMax{iImg,jGroove} = detrendTrackedShape(ptsMax, PolyDegree=POLY_DEGREE);

        % 保存形式に合わせ、j本目の溝をセグメントごとに分け直す（80 x N）
        ycoords_cnt(ks,jGroove) = mat2cell(shapesCnt{iImg,jGroove}(:,2), counts);
        ycoords_max(ks,jGroove) = mat2cell(shapesMax{iImg,jGroove}(:,2), counts);
        for jSegment=1:NUM_SEGMENTS
            xcoords{ks(jSegment),jGroove} = (1:QUERY_STEP:widths(jSegment))';
        end

        yAbsCnt{iImg,jGroove} = ptsCnt(:,2);
        yAbsMax{iImg,jGroove} = ptsMax(:,2);
        foundCnt{iImg,jGroove} = fCnt;
        foundMax{iImg,jGroove} = fMax;
        y0Cnt(iImg,jGroove) = infoCnt.y0;
        y0Max(iImg,jGroove) = infoMax.y0;
    end

    % 同じ溝を2回・溝を飛ばしたクリックに気づくため、隣どうしの始点（重心法）の差を確かめる
    gaps = -diff(y0Cnt(iImg,:));
    if any(gaps < MIN_SEED_GAP)
        warning("grooveTrack_Ncycle:sameGroove", ...
            "写真%d：隣どうしの始点の差が MIN_SEED_GAP(%g px)より小さい所があります" + ...
            "（同じ溝を2回選んだ可能性）。始点の y = %s", ...
            iImg, MIN_SEED_GAP, mat2str(y0Cnt(iImg,:), 5));
    end
    if NUM_GROOVES >= 3 && any(gaps > 1.5*median(gaps))
        warning("grooveTrack_Ncycle:grooveSkipped", ...
            "写真%d：隣どうしの始点の差が、その中央値の1.5倍を超える所があります" + ...
            "（溝を1本飛ばした可能性）。始点の y = %s", ...
            iImg, mat2str(y0Cnt(iImg,:), 5));
    end

    % p1/p2：1本目（重心法）のy座標（補間済み、デトレンド前）の、各セグメントの左端・右端
    lastIdx = cumsum(counts);
    firstIdx = lastIdx - counts + 1;
    allP1(ks,:) = [ones(NUM_SEGMENTS,1), yAbsCnt{iImg,1}(firstIdx)];
    allP2(ks,:) = [widths, yAbsCnt{iImg,1}(lastIdx)];

    fprintf("写真%d\n", iImg);
    fprintf("  始点の y            重心法 %s、局所的最大値法 %s\n", ...
        mat2str(y0Cnt(iImg,:), 5), mat2str(y0Max(iImg,:), 5));
    fprintf("  点を採れなかった列  重心法 %s、局所的最大値法 %s\n", ...
        mat2str(cellfun(@(f) nnz(~f), foundCnt(iImg,:))), mat2str(cellfun(@(f) nnz(~f), foundMax(iImg,:))));

    if SAVE_FIG
        if needClick
            fig = figure('Position', [50 50 1600 300]);
        else
            fig = figure('Visible','off', 'Position', [50 50 1600 300]);
        end
        photoImg.showImage("fit");
        hold on;
        colors = lines(NUM_GROOVES);
        for jGroove=1:NUM_GROOVES
            plot(xQuery, yAbsCnt{iImg,jGroove}, "-", "Color", colors(jGroove,:), "LineWidth", 0.5);
        end
        plot(xQuery(1)*ones(1,NUM_GROOVES), seedsY(iImg,:), "y^", "MarkerFaceColor", "y", "MarkerSize", 6);
        title("写真" + iImg + "：追跡した " + NUM_GROOVES + " 本の溝（重心法）とクリック位置（黄）", ...
            "Interpreter", "none");
        exportgraphics(fig, outDir + "grooveTrackN_img" + iImg + ".png", "Resolution", 250);
        close(fig);
    end
end % for iImg = 1:NUM_IMAGES


%%
y_comb_cnt = vertcat(ycoords_cnt{:}); % 列の順（1本目の80セグメント → 2本目 …）がそのまま再生順
y_comb_max = vertcat(ycoords_max{:});
allShapesCnt = vertcat(shapesCnt{:});
allShapesMax = vertcat(shapesMax{:});
if ~isequal(allShapesCnt(:,2), y_comb_cnt) || ~isequal(allShapesMax(:,2), y_comb_max)
    error("grooveTrack_Ncycle:orderMismatch", ...
        "vertcat(shapes{:}) と vertcat(ycoords{:}) が一致しません（並べ方の誤り）。");
end

num_samples = sum(cellfun(@numel, ycoords_cnt(:,1))); % 1周分のサンプル数
fs = round(num_samples / (60/RPM));

amp_cnt = (y_comb_cnt - mean(y_comb_cnt)) / AMP_DIV;
amp_max = (y_comb_max - mean(y_comb_max)) / AMP_DIV;
fprintf("\nfs = %d Hz、±1 を超えたサンプル：重心法 %d、局所的最大値法 %d（全 %d サンプル）\n", ...
    fs, nnz(abs(amp_cnt) > 1), nnz(abs(amp_max) > 1), numel(amp_cnt));

% 同じ日に grooveTrack_1cycle.m・grooveHist_Ncycle.m を実行しても wav・図の名前が重ならないよう、
% 名前に (tracking N cycles) を付ける
trackCntAudio = AudioData("audio (centroid method)(original)(tracking " + NUM_GROOVES + " cycles)", amp_cnt, fs);
trackMaxAudio = AudioData("audio (local maximum method)(original)(tracking " + NUM_GROOVES + " cycles)", amp_max, fs);

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
% 追跡で使わない必須の引数（ThHist・BinWidth・HPrl・Tol）には NaN を渡す（grooveTrack_1cycle.m と同じ）。
% 追跡のパラメータは grooveSelection.tracking・multiGroove に入れる
cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=outDir,ExperimentDir=expDir,...
    LMask=L_MASK,ThHist=NaN,DThresh=D_THRESH,WTh=WIDTH_THRESH,...
    Tol=NaN,BinWidth=NaN,HPrl=NaN,PolyDegree=POLY_DEGREE,Rpm=RPM,...
    NumImages=NUM_IMAGES,NumSegments=NUM_SEGMENTS,Filenames=filenames_new,...
    ScriptName="grooveTrack_Ncycle",...
    Note="N周分の正解データ（NUM_GROOVES=" + NUM_GROOVES + "、N本を別々に追跡。パラメータは grooveSelection.multiGroove）");

res_cnt = cycleMethodResult("centroid", allPts_cnt, xcoords, ycoords_cnt, y_comb_cnt, trackCntAudio);
res_max = cycleMethodResult("localMax", allPts_max, xcoords, ycoords_max, y_comb_max, trackMaxAudio);

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

% N本分のクリックと追跡の結果
mg = struct();
mg.numGrooves = NUM_GROOVES;
mg.seedsY = seedsY;
mg.y0Cnt = y0Cnt;
mg.y0Max = y0Max;
mg.minSeedGap = MIN_SEED_GAP;
mg.polyDegree = POLY_DEGREE;
mg.detrendScope = "photo";
mg.ampDivisor = AMP_DIV;
mg.yAbsCnt = yAbsCnt;
mg.yAbsMax = yAbsMax;
mg.foundCnt = foundCnt;
mg.foundMax = foundMax;

grooveSelection = struct();
grooveSelection.p1 = allP1;
grooveSelection.p2 = allP2;
grooveSelection.method = "tracking";
% 1本目のクリック。trackingSeeds で grooveTrack_1cycle.m・grooveHist_Ncycle.m が再現できる
grooveSelection.seeds = [ones(NUM_IMAGES,1), seedsY(:,1)];
grooveSelection.tracking = trk;
grooveSelection.multiGroove = mg;

matPath = saveCycleResult(cond, allImg, [res_cnt res_max], GrooveSelection=grooveSelection, ...
    FileName="cycleResult_origD_track" + NUM_GROOVES + "_" + date, Overwrite=false);
