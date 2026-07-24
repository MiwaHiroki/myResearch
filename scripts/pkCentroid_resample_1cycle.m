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
date = "0721";
dir = mkdirFromDate(proj.RootFolder,date);

%%

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords = cell(TOTAL_SEGMENTS,1);
p2 = zeros(1,2);

% for iImg=1:NUM_IMAGES
for iImg=1:1
    % img_old = imread("./pictures/old/8x/" + filenameC_old(9-iImg) + ".png");
    % img_gray = rgb2gray(img_old);
    % img_new = imread("./pictures/1111/original/" + filenames_new(9-iImg) + ".png");
    img_new = imread(filenames_new(9-iImg) + ".png");
    img_gray = rgb2gray(img_new);
    
    imgWidth = size(img_gray,2); % 1回でimgWidth(pixel)分のx座標を処理
    divImgWidth = round(imgWidth/NUM_SEGMENTS);
    xarray = [1:divImgWidth:imgWidth imgWidth+1]';

    % for jSegment=1:NUM_SEGMENTS
    for jSegment=1:1
        iImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % iImgSmall: 1 ~ NUM_IMAGES * NUM_SEGMENTS

        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

        [img_omitMask,~] = omitMask(img_small,L_MASK);
        origImg = ImageData(img_omitMask, [iImg;jSegment]);
        origWidth = origImg.width;
        origHeight = origImg.height;
        
        % z = 1 - double(img_omitMask)/255;
        origD = DarknessValue(origImg);
        origD = origD.ddiff(D_THRESH);

        P_RSMPL = 8; Q_RSMPL = 1;
        rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
        rsmplD = rsmplD.ddiff(D_THRESH);

        % objects in which groove candidates are recorded.
        % for original img
        pts_cnt = GrooveCandidates(origD);
        pts_max = GrooveCandidates(origD);
        % for resampled img
        pts_cnt_r = GrooveCandidates(rsmplD);
        pts_max_r = GrooveCandidates(rsmplD);

        % 溝底の座標
        % pksCell_r = cell(1,newWidth);
        % sIdxC_r = cell(1,newWidth);
        % eIdxC_r = cell(1,newWidth);

        W_TH = 8;
        
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

        fig = figure;
        origImg.showImg();
        % imshow(img_omitMask);
        % fig = createFigure([0 0 6 6]);
        % imshow(img_small,"InitialMagnification","fit");
        hold on;
        % scatter(pks_cnt_r(:,1),pks_cnt_r(:,2),3,'c','filled');
        pts_cnt_r.showCandidates();
        title("Peak Dots (centroid method)");%xlabel("$x$");ylabel("$y$");   
        % pksの傾きを補正したpks_corを得る
        [p1,p2,pks_cor] = fitGroove(jSegment,fig,p2,w_prl,h_prl,pks_cnt_r);

        % xlim([1 1000]);ylim([1 1000]);
        % exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

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

        idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
        points = pks_cor(idxs,:);

        points_fit = points;

        p = polyfit(points(:,1),points(:,2),3);
        points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
        points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

        xcoords{iImgSmall,1} = points(:,1);
        ycoords{iImgSmall,1} = points_fit(:,2);
    end
end

%%
y_comb_raw = vertcat(ycoords{:});

figure;plot(y_comb_raw);axis tight;
title("$y$ coordinates (centroid method)");xlabel("Sample");ylabel("$y$");

num_samples = length(y_comb_raw);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;

y_comb_raw = y_comb_raw - mean(y_comb_raw);

amplitude_raw = y_comb_raw / (tol/2);
% y_raw_max = max(abs(y_comb_raw));
% amplitude_raw = y_comb_raw / y_raw_max;

figure;plot(tidx,amplitude_raw);
title("amplitude (centroid method)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);



