% pkCentroid_1cycle.m
% 高解像度化していない画像に対して重心法で1周分の音声を作る
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
dir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";

%%
allImg(TOTAL_SEGMENTS,1) = ImageData();
allOrigD(TOTAL_SEGMENTS,1) = DarknessValue();
allPts_max_origD(TOTAL_SEGMENTS,1) = GrooveCandidates();
allPts_cnt_origD(TOTAL_SEGMENTS,1) = GrooveCandidates();

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords = cell(TOTAL_SEGMENTS,1);
p2 = zeros(1,2);


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
        

        origD = DarknessValue(origImg);
        origD = origD.setDiffTF(D_THRESH);


        % objects in which groove candidates are recorded.
        % for original img
        pts_cnt = GrooveCandidates(origD);
        pts_max = GrooveCandidates(origD);

        W_TH = 8;
        
        for x=1:origImg.width
            [startIdx, endIdx] = getStartEndIdx(origD, x);
            [origD,~,~,pksNum] = ...
                getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
            % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

            cnt_x = origD.extractGrv_cnt(x);
            max_x = origD.extractGrv_max(x);

            pts_cnt.pksCell{x} = [x*ones(pksNum,1), cnt_x];
            pts_max.pksCell{x} = [x*ones(pksNum,1), max_x];
        end

        pks_cnt = vertcat(pts_cnt.pksCell{:});
        pks_max = vertcat(pts_max.pksCell{:});

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % fitGroove()を使って、溝1本分の形状データを抽出する
        fig = figure;
        origImg.showImg();
        % fig = createFigure([0 0 6 6]);
        % imshow(img_omitMask,"InitialMagnification","fit");
        hold on;
        pts_cnt.showCandidates();
        % scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),5,'c','filled');
        [p1,p2,pks_cor] = fitGroove(jSegment,fig,p2,w_prl,h_prl,pks_cnt);

        binWidth = 5; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        tol = 3;
        % そのピークの中心からtol(pixel)以内にあるy座標
        y_min = groove1Center - tol;
        y_max = groove1Center + tol;

        points = [(1:origD.imgWidth)',NaN(origD.nCols,1)];

        idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);

        points_x = pks_cor(idxs,1);
        points(points_x,2) = pks_cor(idxs,2);

        points(:,2) = fillmissing(points(:,2),"linear");

        points_fit = points;


        p = polyfit(points(:,1),points(:,2),3);
        points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
        points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

        %}

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % fitGroove()を使って、溝1本分の形状データを抽出する
        


        % データの保存
        allImg(kImgSmall) = origImg;
        allOrigD(kImgSmall) = origD;
        allPts_max_origD(kImgSmall) = pts_max;
        allPts_cnt_origD(kImgSmall) = pts_cnt;


        xcoords{kImgSmall,1} = points(:,1);
        ycoords{kImgSmall,1} = points_fit(:,2);

    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES


%%

y_comb = vertcat(ycoords{:}); % 平均を引く前の1周分のy座標（保存用）

figure;plot(y_comb);axis tight;
title("$y$ coordinates (centroid method)");xlabel("Sample");ylabel("$y$");

num_samples = length(y_comb);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;


y_comb_raw = y_comb;
y_comb_raw = y_comb_raw - mean(y_comb_raw);

amp_raw = y_comb_raw / (tol/2);
% y_raw_max = max(abs(y_comb_raw));
% amp_raw = y_comb_raw / y_raw_max;

figure;plot(tidx,amp_raw);
title("amplitude (centroid method)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);

origAudio = AudioData("audio (centroid method)(original)",amp_raw,fs);

fig = figure;origAudio.audioPlot();
saveas(fig,dir+origAudio.filename+"_amp","fig");saveas(fig,dir+origAudio.filename+"_amp","png");close;

fig = figure;origAudio.FFTPlot();
saveas(fig,dir+origAudio.filename+"_fft","fig");saveas(fig,dir+origAudio.filename+"_fft","png");close;

fig = figure;origAudio.spectrogramPlot(1024);
saveas(fig,dir+origAudio.filename+"_stft","fig");saveas(fig,dir+origAudio.filename+"_stft","png");close;

origAudio.saveAudio(dir);

%%
% cycleCondition.mより
% REQUIRED = ["Upsampling","Date","SaveDir", ...
        % "LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl"];

cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=dir,BinWidth=binWidth,DThresh=D_THRESH,...
    Filenames=filenames_new,HPrl=h_prl,LMask=L_MASK,NumImages=NUM_IMAGES,...
    NumSegments=NUM_SEGMENTS,Tol=tol,ThHist=TH_HIST,WTh=W_TH,...
    ScriptName="pkCentroid_1cycle");

res_cnt = cycleMethodResult("centroid", allPts_cnt_origD, xcoords, ycoords, y_comb, origAudio);
res_max = cycleMethodResult("localMax", allPts_max_origD,xcoords,ycoords,y_comb,origAudio);

matPath = saveCycleResult(cond, allImg, [res_cnt res_max]);
