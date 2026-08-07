% 2026/06/02作成
% pkCentroid_resample.mをもとに作成
% 重心法で1周分の音声を作成するプログラム
%%
setDefaultIntrpr();
proj = currentProject();

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * NUM_IMAGES; % 全部で80枚の画像


filenames_new = strings(NUM_IMAGES,1);
filenames_old = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames_old(i) = "DSC0" + num2str(i+112) + "_8x";
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end


L_MASK = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
TH_HIST = 150; % threshold of the peak height in the histogram

D_THRESH = 0.6;

% 保存用
date = "0807";
dir = mkdirFromDate(proj.RootFolder,date);          % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先

% 以前保存したp1,p2で溝を自動選択する場合は、その結果.matのパスを指定する
% （空文字なら手動でginputにより選択する。詳細はREADMEの「溝の選択（fitGroove）」）
PREV_RESULT_PATH = "";
% PREV_RESULT_PATH = fullfile(proj.RootFolder,"experiments","0807","cycleResult_rsmplD_0807.mat");
if PREV_RESULT_PATH ~= ""
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    grooveSelection = prevResult.grooveSelection;
else
    grooveSelection = [];
end

%%

% 画像8*l枚分のImageData, DarknessMap, GroovePointCloudクラスオブジェクト
% local maximum method, centroid method両方
% origDからも溝底候補点を求めるが、そこから音声は作っていないので保存しない
allImg(TOTAL_SEGMENTS,1) = ImageData();
allRsmplD(TOTAL_SEGMENTS,1) = DarknessMap();
allPts_max_rsmplD(TOTAL_SEGMENTS,1) = GroovePointCloud();
allPts_cnt_rsmplD(TOTAL_SEGMENTS,1) = GroovePointCloud();


% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords_max = cell(TOTAL_SEGMENTS,1);
ycoords_cnt = cell(TOTAL_SEGMENTS,1);
p2 = zeros(1,2);
allP1 = zeros(TOTAL_SEGMENTS,2); % fitGrooveで選んだp1,p2（次回以降の自動選択用に保存）
allP2 = zeros(TOTAL_SEGMENTS,2);

for iImg=1:NUM_IMAGES
% for iImg=1:1 % 動作テスト
    % img_old = imread("./pictures/old/8x/" + filenameC_old(9-iImg) + ".png");
    % img_gray = rgb2gray(img_old);
    % img_new = imread("./pictures/1111/original/" + filenames_new(9-iImg) + ".png");
    img_new = imread(filenames_new(9-iImg) + ".png");
    img_gray = rgb2gray(img_new);
    
    imgWidth = size(img_gray,2); % 1回でimgWidth(pixel)分のx座標を処理
    divImgWidth = round(imgWidth/NUM_SEGMENTS);
    xarray = [1:divImgWidth:imgWidth imgWidth+1]';

    for jSegment=1:NUM_SEGMENTS
    % for jSegment=1:1 % 動作テスト
        kImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % iImgSmall: 1 ~ TOTAL_SEGMENTS

        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

        [img_omitMask,~] = omitMask(img_small,L_MASK);
        origImg = ImageData(img_omitMask, [iImg;jSegment]);
        origWidth = origImg.width;
        origHeight = origImg.height;
        
        % z = 1 - double(img_omitMask)/255;
        origD = DarknessMap(origImg);
        origD = origD.setDiffTF(D_THRESH);

        P_RSMPL = 8; Q_RSMPL = 1;
        rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
        rsmplD = rsmplD.setDiffTF(D_THRESH);

        % objects in which groove candidates are recorded.
        % for original img
        % pts_cnt = GroovePointCloud(origD);
        % pts_max = GroovePointCloud(origD);
        % for resampled img
        pts_cnt_r = GroovePointCloud(rsmplD);
        pts_max_r = GroovePointCloud(rsmplD);

        % 溝底の座標
        % pksCell_r = cell(1,newWidth);
        % sIdxC_r = cell(1,newWidth);
        % eIdxC_r = cell(1,newWidth);
        
        WIDTH_THRESH = 8;

        rsmplExtractor = GrooveExtractor(rsmplD);
        for x=1:origImg.width
            [firstIdx, lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD, x);
            [rsmplExtractor,~,~,numPeaks] = ...
                rsmplExtractor.findGrooveBottomIntervals(rsmplD,x,firstIdx,lastIdx,WIDTH_THRESH);
            % btmFirstIdx, btmLastIdx, numPeaksは今後不要になる予定

            centroidY = rsmplExtractor.extractByCentroid(rsmplD,x);
            maxY = rsmplExtractor.extractByLocalMax(rsmplD,x);

            pts_cnt_r.pksCell{x} = [x*ones(numPeaks,1), centroidY];
            pts_max_r.pksCell{x} = [x*ones(numPeaks,1), maxY];
        end


        
        % origDに対する解析 --> pkCentroid_1cycle.mへ
        %{
        for x=1:origImg.width
            [startIdx, endIdx] = getStartEndIdx(origD,x);
            [origD,~,~,pksNum] = ...
                getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);

            cnt_x = origD.extractGrv_cnt(x);
            max_x = origD.extractGrv_max(x);

            pts_cnt.pksCell{x} = [x*ones(pksNum,1), cnt_x];
            pts_max.pksCell{x} = [x*ones(pksNum,1), max_x];

            [startIdx, endIdx] = getStartEndIdx(rsmplD, x);
            [rsmplD,startIdx_btm,endIdx_btm,pksNum] = ...
                getGrooveBtmIdx(rsmplD, x, startIdx, endIdx, W_TH);

            cnt_x = rsmplD.extractGrv_cnt(x);
            max_x = rsmplD.extractGrv_max(x);

            pts_cnt_r.pksCell{x} = [x*ones(pksNum,1), cnt_x];
            pts_max_r.pksCell{x} = [x*ones(pksNum,1), max_x];
        end

        % figGroove()の使用のために必要
        pks_cnt = vertcat(pts_cnt.pksCell{:});
        pks_max = vertcat(pts_max.pksCell{:});
        %}

        pks_cnt_r = vertcat(pts_cnt_r.pksCell{:});
        pks_max_r = vertcat(pts_max_r.pksCell{:});

        % sIdxs_r = vertcat(sIdxC_r{:});
        % eIdxs_r = vertcat(eIdxC_r{:});
        % pks_r = vertcat(pksCell_r{:});

        % sIdxs_r(:,2) = 1 + (sIdxs_r(:,2)-1)/rRatio;
        % eIdxs_r(:,2) = 1 + (eIdxs_r(:,2)-1)/rRatio;
        % pks_r(:,2) = 1 + (pks_r(:,2)-1)/rRatio;

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % local maximum method, centroid method 共通の溝選択
        % 1回の選択でpks_max_r,pks_cnt_rの両方の傾きを補正したpksCorCellを得る
        if isempty(grooveSelection)
            fig = figure;
            origImg.showImg();
            hold on;
            pts_max_r.showPoints();
            pts_cnt_r.showPoints();
            title("Peak Dots (local max \& centroid)");
            [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w_prl,h_prl,{pks_max_r,pks_cnt_r});
        else
            % 保存済みの点で自動選択するのでfigureは作らない
            [p1,p2,pksCorCell] = fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_max_r,pks_cnt_r}, ...
                P1=grooveSelection.p1(kImgSmall,:), P2=grooveSelection.p2(kImgSmall,:));
        end
        pks_max_cor = pksCorCell{1};
        pks_cnt_cor = pksCorCell{2};

        allP1(kImgSmall,:) = p1;
        allP2(kImgSmall,:) = p2;

        tol = 3;
        binWidth = 5; % BinWidth

        % local maximum method
        [counts,edges] = histcounts(pks_max_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        % そのピークの中心からtol(pixel)以内にあるy座標
        y_min = groove1Center - tol;
        y_max = groove1Center + tol;

        points = [(1:origD.nCols)',NaN(origD.nCols,1)];

        idxs = (pks_max_cor(:,2) >= y_min) & (pks_max_cor(:,2)<=y_max);
        points(pks_max_cor(idxs,1),2) = pks_max_cor(idxs,2);

        points(:,2) = fillmissing(points(:,2),"linear");

        points_fit = points;

        p = polyfit(points(:,1),points(:,2),3);
        points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
        points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

        xcoords{kImgSmall,1} = points(:,1);
        ycoords_max{kImgSmall,1} = points_fit(:,2);

        % centroid method
        [counts,edges] = histcounts(pks_cnt_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        % そのピークの中心からtol(pixel)以内にあるy座標
        y_min = groove1Center - tol;
        y_max = groove1Center + tol;

        points = [(1:origD.nCols)',NaN(origD.nCols,1)];

        idxs = (pks_cnt_cor(:,2) >= y_min) & (pks_cnt_cor(:,2)<=y_max);
        points(pks_cnt_cor(idxs,1),2) = pks_cnt_cor(idxs,2);

        points(:,2) = fillmissing(points(:,2),"linear");

        points_fit = points;

        p = polyfit(points(:,1),points(:,2),3);
        points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
        points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

        xcoords{kImgSmall,1} = points(:,1);
        ycoords_cnt{kImgSmall,1} = points_fit(:,2);



        allImg(kImgSmall) = origImg;
        allRsmplD(kImgSmall) = rsmplD;
        allPts_max_rsmplD(kImgSmall) = pts_max_r;
        allPts_cnt_rsmplD(kImgSmall) = pts_cnt_r;
        
    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES

%%
y_comb_max = vertcat(ycoords_max{:}); % 平均を引く前の1周分のy座標（保存用）
y_comb_cnt = vertcat(ycoords_cnt{:}); % 平均を引く前の1周分のy座標（保存用）

figure;
plot(y_comb_max);hold on;axis tight;
plot(y_comb_cnt);
title("$y$ coordinates (1-D resampling)");
legend(["local max","centroid"])
xlabel("$x$");ylabel("$y$");

num_samples = length(y_comb_max);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;


y_mean0_max = y_comb_max;
y_mean0_max = y_mean0_max - mean(y_mean0_max);

y_mean0_cnt = y_comb_cnt;
y_mean0_cnt = y_mean0_cnt - mean(y_mean0_cnt);


amp_max = y_mean0_max / (tol/2);
amp_cnt = y_mean0_cnt / (tol/2);

figure;plot(tidx,amp_max);
title("amplitude (local maximum method)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);

rsmplMaxAudio = AudioData("audio (local maximum method)("+num2str(rsmplD.scaleFactor.row)+"x resampled)",amp_max,fs);

fig = figure;rsmplMaxAudio.audioPlot();
saveas(fig,dir+rsmplMaxAudio.filename+"_amp","fig");saveas(fig,dir+rsmplMaxAudio.filename+"_amp","png");close;

fig = figure;rsmplMaxAudio.FFTPlot();
saveas(fig,dir+rsmplMaxAudio.filename+"_fft","fig");saveas(fig,dir+rsmplMaxAudio.filename+"_fft","png");close;

fig = figure;rsmplMaxAudio.spectrogramPlot(1024);
saveas(fig,dir+rsmplMaxAudio.filename+"_stft","fig");saveas(fig,dir+rsmplMaxAudio.filename+"_stft","png");close;

rsmplMaxAudio.saveAudio(dir);


rsmplCntAudio = AudioData("audio (centroid method)("+num2str(rsmplD.scaleFactor.row)+"x resampled)",amp_cnt,fs);

fig = figure;rsmplCntAudio.audioPlot();
saveas(fig,dir+rsmplCntAudio.filename+"_amp","fig");saveas(fig,dir+rsmplCntAudio.filename+"_amp","png");close;

fig = figure;rsmplCntAudio.FFTPlot();
saveas(fig,dir+rsmplCntAudio.filename+"_fft","fig");saveas(fig,dir+rsmplCntAudio.filename+"_fft","png");close;

fig = figure;rsmplCntAudio.spectrogramPlot(1024);
saveas(fig,dir+rsmplCntAudio.filename+"_stft","fig");saveas(fig,dir+rsmplCntAudio.filename+"_stft","png");close;

rsmplCntAudio.saveAudio(dir);


%%
% 実験結果の保存
% 図の作成スクリプトは loadCycleResult でこの.matを読むだけにする
cond = cycleConditions( ...
    Upsampling="rsmplD", Date=date, SaveDir=dir, ExperimentDir=expDir, ...
    NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, ...
    LMask=L_MASK, ThHist=TH_HIST, DThresh=D_THRESH, WTh=WIDTH_THRESH, ...
    Tol=tol, BinWidth=binWidth, HPrl=h_prl, ...
    PRsmpl=P_RSMPL, QRsmpl=Q_RSMPL, ...
    Filenames=filenames_new, ScriptName="pkCentroid_resample_1cycle");

res_max = cycleMethodResult("localMax", allPts_max_rsmplD, xcoords, ycoords_max, y_comb_max, rsmplMaxAudio);
res_cnt = cycleMethodResult("centroid", allPts_cnt_rsmplD, xcoords, ycoords_cnt, y_comb_cnt, rsmplCntAudio);

matPath = saveCycleResult(cond, allImg, [res_max res_cnt], ...
    GrooveSelection=struct('p1',allP1,'p2',allP2));
