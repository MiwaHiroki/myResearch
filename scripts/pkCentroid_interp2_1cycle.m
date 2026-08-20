% interp2を使って疑似的な高解像度化を行う
% pkCentroid_interp2.mをもとに作成
% 2026/07/10作成

%%
% 発表資料作成用

setDefaultIntrpr();

%%
proj = currentProject();

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * 8; % 全部で80枚の画像


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
date = "0731";
dir = mkdirFromDate(proj.RootFolder,date);          % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";

% 以前保存したp1,p2で溝を自動選択する場合は、その結果.matのパスを指定する
% （空文字なら手動でginputにより選択する。詳細はREADMEの「溝の選択（fitGroove）」）
% PREV_RESULT_PATH = "";
PREV_RESULT_PATH = fullfile(proj.RootFolder,"experiments","0731","cycleResult_intpD_0731_2.mat");
if PREV_RESULT_PATH ~= ""
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    grooveSelection = prevResult.grooveSelection;
else
    grooveSelection = [];
end

%%

% 画像8*l枚分のImageData, DarknessMap, GroovePointCloudクラスオブジェクト
% 溝の形状抽出はすべてcentroid methodによる。
allImg(TOTAL_SEGMENTS,1) = ImageData();
allIntpD(TOTAL_SEGMENTS,1) = DarknessMap();
allPts_max_intpD(TOTAL_SEGMENTS,1) = GroovePointCloud();
allPts_cnt_intpD(TOTAL_SEGMENTS,1) = GroovePointCloud();
% 以下はpkCentroid_resample_1cycle.mにゆずる。
% allOrigD(TOTAL_SEGMENTS,1) = DarknessMap();
% allPts_max_origD(TOTAL_SEGMENTS,1) = GroovePointCloud();
% allPts_cnt_origD(TOTAL_SEGMENTS,1) = GroovePointCloud();

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords_max = cell(TOTAL_SEGMENTS,1);
ycoords_cnt = cell(TOTAL_SEGMENTS,1);
p2 = zeros(1,2);
allP1 = zeros(TOTAL_SEGMENTS,2); % fitGrooveで選んだp1,p2（次回以降の自動選択用に保存）
allP2 = zeros(TOTAL_SEGMENTS,2);

for iImg=1:NUM_IMAGES
    for jSegment=1:NUM_SEGMENTS
        kImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % 何番目のimgSmallか。kImgSmall = 1 ~ TOTAL_SEGMENTS

        img_new = imread(filenames_new(9-iImg) + ".png");
        img_gray = rgb2gray(img_new);

        [height,width] = size(img_gray);

        divWidth = round(width / NUM_SEGMENTS);
        xarray = [1:divWidth:width width+1]';
        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small, L_MASK);
        origImg = ImageData(img_omitMask, [iImg;jSegment]);
        origWidth = origImg.width;
        origHeight = origImg.height;
        

        origD = DarknessMap(origImg);
        origD = origD.setDiffTF(D_THRESH);


        % P_RSMPL = 8; Q_RSMPL = 1;
        % rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
        % rsmplD = rsmplD.setDiffTF(D_THRESH);

        QUERY_STEP = 0.125;
        INTERP_METHOD = "spline";
        intpD = dInterp(origD,QUERY_STEP,INTERP_METHOD);
        intpD = intpD.setDiffTF(D_THRESH);

        % objects in which groove candidates are recorded.
        % for original img
        % pts_cnt = GroovePointCloud(origD);
        % pts_max = GroovePointCloud(origD);

        % for resampled img
        % pts_cnt_r = GroovePointCloud(rsmplD);
        % pts_max_r = GroovePointCloud(rsmplD);

        % for interpolated img
        pts_cnt_intp = GroovePointCloud(intpD);
        pts_max_intp = GroovePointCloud(intpD);


        WIDTH_THRESH = 8;

        % origD, rsmplDから溝形状を抽出
        %{
        for x=1:origImg.width
            [startIdx, endIdx] = getStartEndIdx(origD, x);
            [origD,~,~,pksNum] = ...
                getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
            % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

            cnt_x = origD.extractGrv_cnt(x);
            max_x = origD.extractGrv_max(x);

            pts_cnt.peakCells{x} = [x*ones(pksNum,1), cnt_x];
            pts_max.peakCells{x} = [x*ones(pksNum,1), max_x];


            [startIdx, endIdx] = getStartEndIdx(rsmplD, x);
            [rsmplD,startIdx_btm,endIdx_btm,pksNum] = ...
                getGrooveBtmIdx(rsmplD, x, startIdx, endIdx, W_TH);

            cnt_x = rsmplD.extractGrv_cnt(x);
            max_x = rsmplD.extractGrv_max(x);

            pts_cnt_r.peakCells{x} = [x*ones(pksNum,1), cnt_x];
            pts_max_r.peakCells{x} = [x*ones(pksNum,1), max_x];
        end

        pks_cnt = vertcat(pts_cnt.peakCells{:});
        pks_max = vertcat(pts_max.peakCells{:});

        pks_cnt_r = vertcat(pts_cnt_r.peakCells{:});
        pks_max_r = vertcat(pts_max_r.peakCells{:});

        % fitGroove()を使って、溝1本分の形状データを抽出する

        %}

        intpExtractor = GrooveExtractor(intpD);
        for x=1:intpD.nCols
            [firstIdx, lastIdx] = intpExtractor.findThresholdIntervals(intpD,x);
            [intpExtractor, btmFirstIdx, btmLastIdx, numPeaks] = ...
                intpExtractor.findGrooveBottomIntervals(intpD,x,firstIdx,lastIdx,WIDTH_THRESH);

            centroidY = intpExtractor.extractByCentroid(intpD,x);
            maxY = intpExtractor.extractByLocalMax(intpD,x);

            tmpPoints = [x*ones(numPeaks,1), centroidY];
            tmpPoints(:,1) = 1+(tmpPoints(:,1)-1) * QUERY_STEP;
            pts_cnt_intp.peakCells{x} = tmpPoints;

            tmpPoints = [x*ones(numPeaks,1), maxY];
            tmpPoints(:,1) = 1+(tmpPoints(:,1)-1) * QUERY_STEP;
            pts_max_intp.peakCells{x} = tmpPoints;
        end

        pks_max_intp = vertcat(pts_max_intp.peakCells{:});
        pks_cnt_intp = vertcat(pts_cnt_intp.peakCells{:});

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % local maximum method, centroid method 共通の溝選択
        % 1回の選択でpks_max_intp,pks_cnt_intpの両方の傾きを補正したpksCorCellを得る
        if isempty(grooveSelection)
            fig = figure;
            origImg.showImage();
            hold on;
            pts_max_intp.showPoints();
            pts_cnt_intp.showPoints();
            [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w_prl,h_prl,{pks_max_intp,pks_cnt_intp});
        else
            % 保存済みの点で自動選択するのでfigureは作らない
            [p1,p2,pksCorCell] = fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_max_intp,pks_cnt_intp}, ...
                P1=grooveSelection.p1(kImgSmall,:), P2=grooveSelection.p2(kImgSmall,:));
        end
        pks_max_cor = pksCorCell{1};
        pks_cnt_cor = pksCorCell{2};

        allP1(kImgSmall,:) = p1;
        allP2(kImgSmall,:) = p2;

        tol = 3;
        binWidth = 5; % BinWidth

        % local maximum method
        points_fit = extractGrooveWaveform(pks_max_cor, p1(2), (1:QUERY_STEP:intpD.width)', ...
            BinWidth=binWidth, MinPeakHeight=TH_HIST, Tolerance=tol);

        xcoords{kImgSmall,1} = points_fit(:,1);
        ycoords_max{kImgSmall,1} = points_fit(:,2);


        % centroid method
        points_fit = extractGrooveWaveform(pks_cnt_cor, p1(2), (1:QUERY_STEP:intpD.width)', ...
            BinWidth=binWidth, MinPeakHeight=TH_HIST, Tolerance=tol);

        xcoords{kImgSmall,1} = points_fit(:,1);
        ycoords_cnt{kImgSmall,1} = points_fit(:,2);



        % データの保存
        allImg(kImgSmall) = origImg;
        allIntpD(kImgSmall) = intpD;
        allPts_max_intpD(kImgSmall) = pts_max_intp;
        allPts_cnt_intpD(kImgSmall) = pts_cnt_intp;
        % allOrigD(kImgSmall) = origD;
        % allPts_max_origD(kImgSmall) = pts_max;
        % allPts_cnt_origD(kImgSmall) = pts_cnt;

    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES


%%
% original, resample, interpの比較
%{
mkSize = 5; % marker size
fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
origImg.showImage();
hold on;
scatter(pks_cnt(:,1),pks_cnt(:,2),mkSize,'filled');
scatter(pks_cnt_r(:,1),pks_cnt_r(:,2),mkSize,'filled');
scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),mkSize,'filled');

title("Peak Dots (centroid method)");
legend(["not resampled","resampled","interpolated"]);
lgd = legend; lgd.ItemHitFcn=@togglevisibility;
%}

%%

y_comb_max = vertcat(ycoords_max{:});
y_comb_cnt = vertcat(ycoords_cnt{:});
% figure;plot(y_comb_max);axis tight;
% title("$y$ coordinates (Darkness interpolated)");xlabel("Sample");ylabel("$y$");

num_samples = length(y_comb_max);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;

y_mean0_max = y_comb_max - mean(y_comb_max);
y_mean0_cnt = y_comb_cnt - mean(y_comb_cnt);

amp_max = y_mean0_max / (tol/2);
amp_cnt = y_mean0_cnt / (tol/2);

intpMaxAudio = AudioData("audio ("+num2str(1/QUERY_STEP)+"x interp)(local max)",amp_max,fs);
intpCntAudio = AudioData("audio ("+num2str(1/QUERY_STEP)+"x interp)(centroid)",amp_cnt,fs);

fig = figure;intpMaxAudio.plotWaveform();
saveas(fig,dir+intpMaxAudio.filename+"_amp","fig");saveas(fig,dir+intpMaxAudio.filename+"_amp","png");close;

fig = figure;intpMaxAudio.plotFFT();
saveas(fig,dir+intpMaxAudio.filename+"_fft","fig");saveas(fig,dir+intpMaxAudio.filename+"_fft","png");close;

fig = figure;intpMaxAudio.plotSpectrogram(8192);
saveas(fig,dir+intpMaxAudio.filename+"_stft","fig");saveas(fig,dir+intpMaxAudio.filename+"_stft","png");close;

intpMaxAudio.saveAudio(dir);


fig = figure;intpCntAudio.plotWaveform();
saveas(fig,dir+intpCntAudio.filename+"_amp","fig");saveas(fig,dir+intpCntAudio.filename+"_amp","png");close;

fig = figure;intpCntAudio.plotFFT();
saveas(fig,dir+intpCntAudio.filename+"_fft","fig");saveas(fig,dir+intpCntAudio.filename+"_fft","png");close;

fig = figure;intpCntAudio.plotSpectrogram(8192);
saveas(fig,dir+intpCntAudio.filename+"_stft","fig");saveas(fig,dir+intpCntAudio.filename+"_stft","png");close;

intpCntAudio.saveAudio(dir);


%%
% 実験結果の保存
% 図の作成スクリプトは loadCycleResult でこの.matを読むだけにする
cond = cycleConditions( ...
    Upsampling="intpD", Date=date, SaveDir=dir, ExperimentDir=expDir, ...
    NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, ...
    LMask=L_MASK, ThHist=TH_HIST, DThresh=D_THRESH, WTh=WIDTH_THRESH, ...
    Tol=tol, BinWidth=binWidth, HPrl=h_prl, ...
    QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, ...
    Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");

res_max = cycleMethodResult("localMax", allPts_max_intpD, xcoords, ycoords_max, y_comb_max, intpMaxAudio);
res_cnt = cycleMethodResult("centroid", allPts_cnt_intpD, xcoords, ycoords_cnt, y_comb_cnt, intpCntAudio);

matPath = saveCycleResult(cond, allImg, [res_max res_cnt], ...
    GrooveSelection=struct('p1',allP1,'p2',allP2));
