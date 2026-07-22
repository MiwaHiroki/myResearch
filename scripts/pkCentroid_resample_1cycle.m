% 2026/06/02作成
% pkCentroid_resample.mをもとに作成
% 重心法で1周分の音声を作成するプログラム

%%
filenames_new = strings(8,1);
filenames_old = strings(8,1);
for i=1:8
    filenames_old(i) = "DSC0" + num2str(i+112) + "_8x";
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end


L_mask = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
th_hist = 100; % threshold of the peak height in the histogram

D_th = 0.6;

% 保存用
date = "0602";
dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date;

%%
l = 10; % 細長い画像を10等分する

p_rsmpl = 8; q_rsmpl = 1;
rRatio = p_rsmpl / q_rsmpl;

xcoords = cell(8*l,1);
ycoords = cell(8*l,1);
p2 = zeros(1,2);

for i=1:8
    % img_old = imread("./pictures/old/8x/" + filenameC_old(9-i) + ".png");
    % img_gray = rgb2gray(img_old);
    % img_new = imread("./pictures/1111/original/" + filenames_new(9-i) + ".png");
    img_new = imread(filenames_new(9-i) + ".png");
    img_gray = rgb2gray(img_new);
    
    imgWidth = size(img_gray,2); % 1回でimgWidth(pixel)分のx座標を処理
    divImgWidth = round(imgWidth/l);
    xarray = [1:divImgWidth:imgWidth imgWidth+1]';

    for j=1:l
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small,L_mask);
        % imgHeight = size(img_omitMask,1);
        z = 1 - double(img_omitMask)/255;

        % 溝底の座標
        pksCell_r = cell(1,newWidth);

        % startIdx, endIdxのプロット用
        sIdxC_r = cell(1,newWidth);
        eIdxC_r = cell(1,newWidth);

        for x=1:newWidth
            D_x = z(:,x);
            D_x_r = resample(D_x,p_rsmpl,q_rsmpl);

            TF_D_x_r = (D_x_r>D_th);
            diff_TF_r = diff(TF_D_x_r);
            startIdx = find(diff_TF_r==1)+1;
            endIdx = find(diff_TF_r==-1);

            if endIdx(1)<startIdx(1)
                endIdx = endIdx(2:length(endIdx));
            end

            if endIdx(end)<startIdx(end)
                startIdx = startIdx(1:length(startIdx)-1);
            end

            w_th_r = 5*rRatio; % 「山」の幅の最大値
            btmIdx = find((endIdx-startIdx)<w_th_r); % 溝底に対応するstartIdxのIdxを調べる
            startIdx_btm = startIdx(btmIdx);
            endIdx_btm = endIdx(btmIdx);

            pksNum = length(btmIdx);
            pk_i = zeros(pksNum,1); % x=iにおけるピーク

            sIdxC_r{1,x} = [x*ones(pksNum,1), startIdx_btm];
            eIdxC_r{1,x} = [x*ones(pksNum,1), endIdx_btm];

            for k=1:pksNum % それぞれのピークの座標を求める
                idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

                sigma_D = sum(D_x_r(idxs));
                sigma_jxD = sum(idxs .* D_x_r(idxs));

                pk_i(k) = sigma_jxD/sigma_D;
            end

            pksCell_r{x} = [x*ones(pksNum,1), pk_i];
        end

        sIdxs_r = vertcat(sIdxC_r{:});
        eIdxs_r = vertcat(eIdxC_r{:});
        pks_r = vertcat(pksCell_r{:});

        sIdxs_r(:,2) = 1 + (sIdxs_r(:,2)-1)/rRatio;
        eIdxs_r(:,2) = 1 + (eIdxs_r(:,2)-1)/rRatio;
        pks_r(:,2) = 1 + (pks_r(:,2)-1)/rRatio;

        w_prl = newWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        fig = figure;
        imshow(img_omitMask);
        % fig = createFigure([0 0 6 6]);
        % imshow(img_small,"InitialMagnification","fit");
        axis on;ax=gca;
        set(ax,'YDir','reverse','TickDir','out')
        set(ax,"XAxisLocation","top")
        hold on;
        scatter(pks_r(:,1),pks_r(:,2),3,'c','filled');
        title("Peak Dots (centroid method)");xlabel("$x$");ylabel("$y$");   

        % pksの傾きを補正したpks_corを得る
        [p1,p2,pks_cor] = fitGroove(j,fig,p2,w_prl,h_prl,pks_r);

        % xlim([1 1000]);ylim([1 1000]);
        % exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

        binWidth = 5; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

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

        xcoords{(i-1)*l+j,1} = points(:,1);
        ycoords{(i-1)*l+j,1} = points_fit(:,2);
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



