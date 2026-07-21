% 2026/04/16, pkCentroid_1cycle.mをもとに作成
% 1周分の溝データをつくる
% original, 2x, 4x, 8xそれぞれについて同じプログラムを適用し、結果を比較する

%%
% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
filenameC_new1 = cell(8,1);
filenameC_new2 = cell(8,1);
filenameC_new4 = cell(8,1);
filenameC_new8 = cell(8,1);
filenameC_old = cell(8,1);
for y=1:8
    filenameC_old{y} = "DSC0" + num2str(y+112) + "_8x";
    filenameC_new1{y} = "DSC1111-0000" + num2str(y) + "-ori";
    filenameC_new2{y} = "DSC1111-0000" + num2str(y) + "-2x";
    filenameC_new4{y} = "DSC1111-0000" + num2str(y) + "-4x";
    filenameC_new8{y} = "DSC1111-0000" + num2str(y) + "-8x";
end

l = 10; % 傾き補正のために何分割するか

L_mask = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する

D_th = 0.6;

% 保存用
date = "0421";


%%
% 8x

%{
% それぞれのdivImgから得られる座標データの保存
xcoords = cell(8*l,1);
ycoords = cell(8*l,1);

w_min = 5;
w_max = 40;
% w_min, w_max: 溝底のみを選択するのに必要。
% D_xが正となる範囲の幅を使って溝底を選択する。w_min, w_maxはその最小値と最大値

th_hist = 1000; % threshold of the peak height in the histogram
%}

p2 = [0;0];

for i=1:8
    % img_old = imread("./pictures/old/8x/" + filenameC_old{9-i} + ".png");
    % img_gray = rgb2gray(img_old);
    img_new = imread("./pictures/1111/8x/" + filenameC_new8{9-i} + ".png");
    img_gray = rgb2gray(img_new);
    readImgWidth = size(img_gray,2);

    divImgWidth = round(readImgWidth/l); % 1回でimgWidth(pixel)分のx座標を処理
    xarray = [1:divImgWidth:readImgWidth readImgWidth+1];

    w_prl = divImgWidth; % 平行四辺形の高さ
    h_prl = 60; % 平行四辺形の底辺


    for j=1:l
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small,L_mask);
        imgHeight = size(img_omitMask,1);
        z = 1 - double(img_omitMask)/255;

        z_th = z - D_th;
        z_th(z_th<0) = 0;

        pksCell = cell(1,newWidth);

        for x=1:newWidth % 各x座標でピーク点を得る
            D_x = z_th(:,x);

            idxRef = zeros(imgHeight,1);

            for y=1:imgHeight % idxRefの整理
                if y==1
                    if D_x(y)>0
                        idxRef(y)=1;
                    end
                else
                    if D_x(y)>0 && D_x(y-1)==0
                        idxRef(y)=1;
                    elseif D_x(y)==0 && D_x(y-1)>0
                        idxRef(y)=-1;
                    elseif y==imgHeight && D_x(y)>0
                        idxRef(y)=-1;
                    end

                    % D_x(imgHeight-1)=0, D_x(imgHeight)>0のときの対処法を考える
                    % 2026/03/28記 
                
                end
            end

            % 山の幅が<w_thのもののみを選ぶ
            startIdx = find(idxRef==1);
            endIdx = find(idxRef==-1);

            if length(startIdx)~=length(endIdx)
                endIdx = [endIdx;imgHeight];
            end

            btmIdx = find((endIdx-startIdx)<w_max & (endIdx-startIdx)>w_min); % 溝底に対応するstartIdxのIdxを調べる
            startIdx_btm = startIdx(btmIdx);
            endIdx_btm = endIdx(btmIdx);

            pksNum = length(btmIdx);
            pk_i = zeros(pksNum,1); % x=iにおけるピーク


            for k=1:pksNum
                if startIdx_btm(k)>1 && endIdx_btm(k)<imgHeight
                    idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

                    sigma_D = sum(D_x(idxs));
                    sigma_jxD = sum(idxs .* D_x(idxs));

                    pk_i(k) = (startIdx_btm(k) + endIdx_btm(k)) / 2;
                    % pk_i(k) = sigma_jxD/sigma_D;
                end
            end
            
            pksCell{x} = [x*ones(pksNum,1), pk_i];
        end

        pks = vertcat(pksCell{:});

             
        

        fig = figure;
        imshow(img_omitMask);
        % fig = createFigure([0 0 6 6]);
        % imshow(img_small,"InitialMagnification","fit");
        axis on;ax=gca;
        set(ax,'YDir','reverse','TickDir','out')
        set(ax,"XAxisLocation","top")
        hold on;
        scatter(pks(:,1),pks(:,2),1,'c','filled');
        title("Peak Dots (centroid method)");xlabel("$x$");ylabel("$y$");        

        saveas(fig,"./data/"+date+"/8x/"...
            +date+"_pkDots_i"+num2str(i)+"_j"+num2str(j)+".fig");

        % pksの傾きを補正したpks_corを得る
        [p1,p2,pks_cor] = fitGroove(j,fig,p2,w_prl,h_prl,pks);

        % xlim([1 1000]);ylim([1 1000]);
        % exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

        binWidth = 5; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        tol = 25;
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


%%

% soundCheck(amplitude_raw,fs,date+"_raw",dir+"pkDots_1111_wmax40wmin5/","raw");
% soundCheck(amplitude_fill,fs,date+"_fill","./data/0325_fill_","");
soundCheck(amplitude_raw,fs,date+"_raw",dir,"raw");

% audiowrite(dir+"pkDots_1111_wmax40wmin5/"+"1cycle_raw.wav",amplitude_raw,fs);
% audiowrite("./audio files/1cycle_pkCentroid_"+date+"_fill.wav",amplitude_fill,fs);
audiowrite(dir+date+"_1cycle_raw.wav",amplitude_raw,fs);


%%
