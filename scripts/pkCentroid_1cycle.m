% pkCentroid_1cycle.m
% 高解像度化していない画像に対して局所的最大値法と重心法で1周分の音声を作る
% 2026/07/31作成


setDefaultIntrpr();
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
PREV_RESULT_PATH = "";
if PREV_RESULT_PATH ~= ""
    prevResult = loadCycleResult(PREV_RESULT_PATH);
    grooveSelection = prevResult.grooveSelection;
else
    grooveSelection = [];
end

%%
allImg(TOTAL_SEGMENTS,1) = ImageData();
allOrigD(TOTAL_SEGMENTS,1) = DarknessMap();
allPts_max_origD(TOTAL_SEGMENTS,1) = GroovePointCloud();
allPts_cnt_origD(TOTAL_SEGMENTS,1) = GroovePointCloud();

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1); % xcoordsは共通
ycoords_cnt = cell(TOTAL_SEGMENTS,1); % centroid method
ycoords_max = cell(TOTAL_SEGMENTS,1); % local maximum method
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


        % objects in which groove candidates are recorded.
        % for original img
        pts_cnt = GroovePointCloud(origD);
        pts_max = GroovePointCloud(origD);

        WIDTH_THRESH = 8;

        extractor = GrooveExtractor(origD);
        for x=1:origImg.width
            [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
            [extractor,~,~,numPeaks] = ...
                extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,WIDTH_THRESH);
            % btmFirstIdx, btmLastIdx, numPeaksは今後不要になる予定

            centroidY = extractor.extractByCentroid(origD,x);
            maxY = extractor.extractByLocalMax(origD,x);

            pts_cnt.peakCells{x} = [x*ones(numPeaks,1), centroidY];
            pts_max.peakCells{x} = [x*ones(numPeaks,1), maxY];
        end

        pks_cnt = vertcat(pts_cnt.peakCells{:});
        pks_max = vertcat(pts_max.peakCells{:});

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % fitGroove()を使って、溝1本分の形状データを抽出する
        % local maximum method, centroid method 共通の溝選択
        % 1回の選択でpks_max,pks_cntの両方の傾きを補正したpksCorCellを得る
        if isempty(grooveSelection)
            fig = figure;
            origImg.showImage();
            hold on;
            pts_max.showPoints();
            pts_cnt.showPoints();
            [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w_prl,h_prl,{pks_max,pks_cnt});
        else
            % 保存済みの点で自動選択するのでfigureは作らない
            [p1,p2,pksCorCell] = fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_max,pks_cnt}, ...
                P1=grooveSelection.p1(kImgSmall,:), P2=grooveSelection.p2(kImgSmall,:));
        end
        pks_max_cor = pksCorCell{1};
        pks_cnt_cor = pksCorCell{2};

        allP1(kImgSmall,:) = p1;
        allP2(kImgSmall,:) = p2;

        tol = 3;
        binWidth = 5; % BinWidth

        % local maximum method
        points_fit = extractGrooveWaveform(pks_max_cor, p1(2), (1:origD.nCols)', ...
            BinWidth=binWidth, MinPeakHeight=TH_HIST, Tolerance=tol);

        xcoords{kImgSmall,1} = points_fit(:,1);
        ycoords_max{kImgSmall,1} = points_fit(:,2);

        % centroid method
        points_fit = extractGrooveWaveform(pks_cnt_cor, p1(2), (1:origD.nCols)', ...
            BinWidth=binWidth, MinPeakHeight=TH_HIST, Tolerance=tol);

        xcoords{kImgSmall,1} = points_fit(:,1);
        ycoords_cnt{kImgSmall,1} = points_fit(:,2);

        % データの保存
        allImg(kImgSmall) = origImg;
        allOrigD(kImgSmall) = origD;
        allPts_max_origD(kImgSmall) = pts_max;
        allPts_cnt_origD(kImgSmall) = pts_cnt;



    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES


%%
y_comb_max = vertcat(ycoords_max{:}); % 平均を引く前の1周分のy座標（保存用）
y_comb_cnt = vertcat(ycoords_cnt{:}); % 平均を引く前の1周分のy座標（保存用）

figure;
plot(y_comb_max);hold on;axis tight;
plot(y_comb_cnt);
title("$y$ coordinates (original)");
legend(["local max","centroid"])
xlabel("$x$");ylabel("$y$");

num_samples = length(y_comb_cnt);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;


y_mean0_max = y_comb_max;
y_mean0_max = y_mean0_max - mean(y_mean0_max);

y_mean0_cnt = y_comb_cnt;
y_mean0_cnt = y_mean0_cnt - mean(y_mean0_cnt);

amp_max = y_mean0_max / (tol/2);
amp_cnt = y_mean0_cnt / (tol/2);
% y_raw_max = max(abs(y_comb_raw));
% amp_raw = y_comb_raw / y_raw_max;

figure;plot(tidx,amp_max);
title("amplitude (local maximum method)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);

origMaxAudio = AudioData("audio (local maximum method)(original)",amp_max,fs);
origCntAudio = AudioData("audio (centroid method)(original)",amp_cnt,fs);

fig = figure;origMaxAudio.plotWaveform();
saveas(fig,dir+origMaxAudio.filename+"_amp","fig");saveas(fig,dir+origMaxAudio.filename+"_amp","png");close;

fig = figure;origMaxAudio.plotFFT();
saveas(fig,dir+origMaxAudio.filename+"_fft","fig");saveas(fig,dir+origMaxAudio.filename+"_fft","png");close;

fig = figure;origMaxAudio.plotSpectrogram(1024);
saveas(fig,dir+origMaxAudio.filename+"_stft","fig");saveas(fig,dir+origMaxAudio.filename+"_stft","png");close;

origMaxAudio.saveAudio(dir);


fig = figure;origCntAudio.plotWaveform();
saveas(fig,dir+origCntAudio.filename+"_amp","fig");saveas(fig,dir+origCntAudio.filename+"_amp","png");close;

fig = figure;origCntAudio.plotFFT();
saveas(fig,dir+origCntAudio.filename+"_fft","fig");saveas(fig,dir+origCntAudio.filename+"_fft","png");close;

fig = figure;origCntAudio.plotSpectrogram(1024);
saveas(fig,dir+origCntAudio.filename+"_stft","fig");saveas(fig,dir+origCntAudio.filename+"_stft","png");close;

origCntAudio.saveAudio(dir);


%%
% cycleCondition.mより
% REQUIRED = ["Upsampling","Date","SaveDir", ...
        % "LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl"];

cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=dir,ExperimentDir=expDir,...
    BinWidth=binWidth,DThresh=D_THRESH,...
    Filenames=filenames_new,HPrl=h_prl,LMask=L_MASK,NumImages=NUM_IMAGES,...
    NumSegments=NUM_SEGMENTS,Tol=tol,ThHist=TH_HIST,WTh=WIDTH_THRESH,...
    ScriptName="pkCentroid_1cycle");

res_max = cycleMethodResult("localMax", allPts_max_origD,xcoords,ycoords_max,y_comb_max,origMaxAudio);
res_cnt = cycleMethodResult("centroid", allPts_cnt_origD, xcoords, ycoords_cnt, y_comb_cnt, origCntAudio);


matPath = saveCycleResult(cond, allImg, [res_cnt res_max], ...
    GrooveSelection=struct('p1',allP1,'p2',allP2));
