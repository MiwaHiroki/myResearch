% phothshop_centroid_1cycle.m
% 202609asjにおいて，従来法(2026/03に発表したデータ)との比較が必要。
% photoshopで8xに高解像度化を行ったデータに対して，重心法で音声を作成する
% 

setDefaultIntrpr();
proj = currentProject();

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * 8; % 全部で80枚の画像


filenames = strings(NUM_IMAGES,1);

for i=1:NUM_IMAGES
    filenames(i) = "DSC1111-0000" + num2str(i) + "-8x";
end


L_MASK = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
TH_HIST = 150*8; % threshold of the peak height in the histogram

D_THRESH = 0.6;

% 保存用
date = "0802";
dir = mkdirFromDate(proj.RootFolder,date);          % 図・音声の出力先
expDir = experimentDir(proj.RootFolder,date);       % 実験結果.matの保存先
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";

%%
allImg(TOTAL_SEGMENTS,1) = ImageData();
allOrigD(TOTAL_SEGMENTS,1) = DarknessMap();
allPts_cnt_8xD(TOTAL_SEGMENTS,1) = GrooveCandidates();

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords = cell(TOTAL_SEGMENTS,1); % local maximum method
p2_cnt = zeros(1,2);


for iImg=1:NUM_IMAGES
    for jSegment=1:NUM_SEGMENTS
        kImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % 何番目のimgSmallか。kImgSmall = 1 ~ TOTAL_SEGMENTS

        img_new = imread(filenames(9-iImg) + ".png");
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
        % origD.scaleFactor.row = 8; origD.scaleFactor.col = 8;

        dMat = origD.dMat;

        % objects in which groove candidates are recorded.
        pts_cnt = GrooveCandidates(origD);

        W_MAX = 65;
        W_MIN = 8; % 「山」の最小の幅。小さすぎる山は無視する
        % W_MAX = 8;
        extractor = GrooveExtractor(origD);
        for x=1:origImg.width
            [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
            % 標準のfindGrooveBottomIntervals（上限閾値のみ）ではなく、
            % 上限W_MAXと下限W_MINの両方でフィルタする独自ロジック
            % [extractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
            %     extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_MAX);

            btmIntervalIdx = find(((lastIdx-firstIdx) < W_MAX*origD.scaleFactor.row) &...
                (lastIdx-firstIdx) > W_MIN*origD.scaleFactor.row);

            btmFirstIdx = firstIdx(btmIntervalIdx);
            btmLastIdx = lastIdx(btmIntervalIdx);

            numPeaks = length(btmIntervalIdx);

            extractor.startIdxCells{1,x} = [x*ones(numPeaks,1), btmFirstIdx];
            extractor.endIdxCells{1,x} = [x*ones(numPeaks,1), btmLastIdx];

            centroidY = extractor.extractByCentroid(origD,x);

            pts_cnt.pksCell{x} = [x*ones(numPeaks,1), centroidY];
        end

        % pksCell = cell(newWidth,1);
        % for k=1:newWidth % 各x座標についてピークを見つけ、pksCellに格納
        %     minh = 0.5;maxh = 0.75; % Min & MaxPeakHeight
        %     mind = 50; % MinPeakDistance
        %     minp = 0.2; % MinPeakProminence
        %     th_prd = 10; % threshold of the product
        %     % product = peakWidth * peakProminence
        % 
        %     % [tmpPks,tmpLocs,w,p] = findpeaks(z(:,k),...
        %     %     'MinPeakDistance',mind,...
        %     %     'MinPeakProminence',minp);
        % 
        %     [tmpPks,tmpLocs,w,p] = findpeaks(dMat(:,k),...
        %         'MinPeakHeight',minh,...
        %         'MinPeakDistance',mind,...
        %         'MinPeakWidth',10);
        %     % idx=find(tmpPks<maxh);
        % 
        %     product = w.*p;
        %     idx = find(product < th_prd);
        % 
        %     num = length(idx);
        % 
        %     tmpPksX = k * ones(num,1);
        %     tmpPksY = zeros(num,1);
        %     tmpPksY(:,1) = tmpLocs(idx);
        % 
        %     pksCell{k,1} = [tmpPksX tmpPksY];
        % 
        % end

        pkDots_cnt = vertcat(pts_cnt.pksCell{:});
        % pkDots_cnt = vertcat(pksCell{:});

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 60; % 平行四辺形の底辺

        % fitGroove()を使って、溝1本分の形状データを抽出する
        % local maximum method
        fig = figure;
        origImg.showImg();
        % fig = createFigure([0 0 6 6]);
        % imshow(img_omitMask,"InitialMagnification","fit");
        hold on;
        scatter(pkDots_cnt(:,1),pkDots_cnt(:,2),5,'c','filled');
        % scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),5,'c','filled');
        [p1_cnt,p2_cnt,pks_cor] = fitGroove(jSegment,fig,p2_cnt,w_prl,h_prl,pkDots_cnt);

        binWidth = 5*8; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

        [~,idx_hist] = min(abs(p1_cnt(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        tol = 3*8;
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

        xcoords{kImgSmall,1} = points(:,1);
        ycoords{kImgSmall,1} = points_fit(:,2);

        %}

        % データの保存
        allImg(kImgSmall) = origImg;
        allOrigD(kImgSmall) = origD;
        allPts_cnt_8xD(kImgSmall) = pts_cnt;

    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES


%%
y_comb_cnt = vertcat(ycoords{:}); % 平均を引く前の1周分のy座標（保存用）

figure;
plot(y_comb_cnt);hold on;axis tight;
title("$y$ coordinates (original)");
xlabel("$x$");ylabel("$y$");

num_samples = length(y_comb_cnt);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;


y_mean0_cnt = y_comb_cnt;
y_mean0_cnt = y_mean0_cnt - mean(y_mean0_cnt);

amp_cnt = y_mean0_cnt / (tol/2);
% y_raw_cnt = cnt(abs(y_comb_raw));
% amp_raw = y_comb_raw / y_raw_cnt;

figure;plot(tidx,amp_cnt);
title("amplitude (photoshop-centroid)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);

origCntAudio = AudioData("audio (photoshop-centroid)",amp_cnt,fs);

fig = figure;origCntAudio.audioPlot();
saveas(fig,dir+origCntAudio.filename+"_amp","fig");saveas(fig,dir+origCntAudio.filename+"_amp","png");close;

fig = figure;origCntAudio.FFTPlot();
saveas(fig,dir+origCntAudio.filename+"_fft","fig");saveas(fig,dir+origCntAudio.filename+"_fft","png");close;

fig = figure;origCntAudio.spectrogramPlot(8192);
saveas(fig,dir+origCntAudio.filename+"_stft","fig");saveas(fig,dir+origCntAudio.filename+"_stft","png");close;

origCntAudio.saveAudio(dir);



%%
% cycleCondition.mより
% REQUIRED = ["Upsampling","Date","SaveDir", ...
        % "LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl"];

cond = cycleConditions(...
    Upsampling="origD",Date=date,SaveDir=dir,ExperimentDir=expDir,...
    BinWidth=binWidth,DThresh=D_THRESH,...
    Filenames=filenames,HPrl=h_prl,LMask=L_MASK,NumImages=NUM_IMAGES,...
    NumSegments=NUM_SEGMENTS,Tol=tol,ThHist=TH_HIST,WTh=W_MAX,...
    ScriptName="photoshop_centroid_1cycle",Note="used W_MIN="+num2str(W_MIN));

res_cnt = cycleMethodResult("centroid", allPts_cnt_8xD,xcoords,ycoords,y_comb_cnt,origCntAudio);


matPath = saveCycleResult(cond, allImg, res_cnt);
