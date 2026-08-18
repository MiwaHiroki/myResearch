% pkCentroid_resample.m
% 2026/05/10作成
% pkCentroid.mをもとに作成
% D_xをリサンプルし、startIdx, endIdxの真値からのずれを減らしたい。
% 高解像度化を行っていない、./pictures/1111/original/~~の写真を使う。

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
date = "0721";
saveDir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";

%%

iImg = 1;
jSegment = 1;

img_new = imread(filenames_new(9-iImg) + ".png");
img_gray = rgb2gray(img_new);

[height,width] = size(img_gray);

divWidth = round(width / NUM_SEGMENTS);
xarray = [1:divWidth:width width+1]';
img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

[img_omitMask,newWidth] = omitMask(img_small, L_MASK);
origImg = ImageData(img_omitMask, [iImg;jSegment]);

origD = DarknessMap(origImg);
origD = origD.setDiffTF(D_THRESH);

p_rsmpl = 8; q_rsmpl = 1;
rsmplD = dResample(origD,8,1);
rsmplD = rsmplD.setDiffTF(D_THRESH);

% x = x_cにおけるD
% origD at x=x_cとrsmplD at x=x_cを重ねて表示
% あとでやる...たぶん


% for original img
pts_cnt = GroovePointCloud(origD);
pts_max = GroovePointCloud(origD);
% for resampled img
pts_cnt_r = GroovePointCloud(rsmplD);
pts_max_r = GroovePointCloud(rsmplD);

origExtractor = GrooveExtractor(origD);
rsmplExtractor = GrooveExtractor(rsmplD);
for x=1:origImg.width
    [firstIdx, lastIdx] = origExtractor.findThresholdIntervals(origD, x);

    WIDTH_THRESH = 8;
    [origExtractor,~,~,numPeaks] = ...
        origExtractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,WIDTH_THRESH);
    % btmFirstIdx, btmLastIdx, numPeaksは今後不要になる予定

    centroidY = origExtractor.extractByCentroid(origD,x);
    maxY = origExtractor.extractByLocalMax(origD,x);

    pts_cnt.peakCells{x} = [x*ones(numPeaks,1), centroidY];
    pts_max.peakCells{x} = [x*ones(numPeaks,1), maxY];


    [firstIdx, lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD, x);
    [rsmplExtractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
        rsmplExtractor.findGrooveBottomIntervals(rsmplD, x, firstIdx, lastIdx, WIDTH_THRESH);

    centroidY = rsmplExtractor.extractByCentroid(rsmplD,x);
    maxY = rsmplExtractor.extractByLocalMax(rsmplD,x);

    pts_cnt_r.peakCells{x} = [x*ones(numPeaks,1), centroidY];
    pts_max_r.peakCells{x} = [x*ones(numPeaks,1), maxY];

end

sIdxs = vertcat(origExtractor.startIdxCells{:});
eIdxs = vertcat(origExtractor.endIdxCells{:});


figure;
origImg.showImg();
hold on;
pts_max.showPoints();
pts_cnt.showPoints();
pts_max_r.showPoints();
pts_cnt_r.showPoints();
title("Peak Dots from Original and Resampled Darkness")

legend(["original (localMax)","original (centroid)","resampled (localMax)","resampled (centroid)"]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;


%%
% xを固定して考える

%{
x_c = 1; % constant

D_x = z(:,x_c);
D_x_th = z_th(:,x_c);

% idxRef = zeros(imgHeight,1);
% for y=1:imgHeight
%     if y==1
%         if D_x_th(y)>0
%             idxRef(y)=1;
%         end
%     elseif y<imgHeight
%         if D_x_th(y)==0 && D_x_th(y+1)>0
%             idxRef(y)=1;
%         elseif D_x_th(y-1)>0 && D_x_th(y)==0
%             idxRef(y)=-1;
%         end
%     else
%         if D_x_th(y)>0
%             idxRef(y)=-1;
%         end
%     end
% end
% 
% startIdx = find(idxRef==1);
% endIdx = find(idxRef==-1);


% idxRefの代わりになるもの
TF_D_x = (D_x>th);
diff_TF = diff(TF_D_x);
diff_TF = [diff_TF;0];
startIdx = find(diff_TF==1)+1;
endIdx = find(diff_TF==-1);

if endIdx(1)<startIdx(1)
    endIdx = endIdx(2:length(endIdx));
end

if endIdx(end)<startIdx(end)
    startIdx = startIdx(1:length(startIdx)-1);
end

w_th = 5; % 「山」の幅の最大値
btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
startIdx_btm = startIdx(btmIdx);
endIdx_btm = endIdx(btmIdx);

pksNum = length(btmIdx);
pk_i = zeros(pksNum,1); % x=iにおけるピーク

for k=1:pksNum
    if startIdx_btm(k)>1 && endIdx_btm(k)<imgHeight
        idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
    
        sigma_D = sum(D_x_th(idxs));
        sigma_jxD = sum(idxs .* D_x_th(idxs));
    
        pk_i(k) = sigma_jxD/sigma_D;
    end
end

figure;plot(D_x(:));
axis tight;
hold on;
yline(th);
hold off;
xlim([1 100]);
ylim([0 1]);
title("$D$ on $x$="+num2str(x_c));xlabel("$y$");ylabel("$D$");
colormap(flip(gray));
colorbar("eastoutside");
clim([0 1]);

% pk_iを重ねて表示
% figure;plot(D_i);
% axis tight;
% hold on;
% for k=1:pksNum
%     xline(pk_i(k))
% end
% hold off;
% xlim([1 1000]);
% title("$D_{th}$ on $x$="+num2str(i));xlabel("$y$");ylabel("$D_{th}$");

% startIdx, endIdxも表示
figure;
plot(z(:,x_c),"-","Marker",".","MarkerSize",5);
axis tight;
hold on;yline(th);
scatter(startIdx_btm(:),z(startIdx_btm,x_c),5,"r","filled");
scatter(endIdx_btm(:),z(endIdx_btm,x_c),5,"y","filled");
hold off;
xlim([1 100]);
ylim([0 1]);
title("$D$ and reference range");xlabel("$y$");ylabel("$D$");
colormap(flip(gray));colorbar("eastoutside");clim([0 1]);

%}

%%

% -----------------ここから下は昔のスクリプト---------------------------------

% リサンプルしたデータに対してcentroid methodを使った結果

pksCell = cell(1,divImgWidth);
pksCell_max = cell(1,divImgWidth);

% startIdx, endIdxのプロット用
sIdxC = cell(1,divImgWidth);
eIdxC = cell(1,divImgWidth);

for x=1:divImgWidth
    D_x = z(:,x);
    % idxRef = zeros(imgHeight,1);
    % for y=1:imgHeight
    %     if y==1
    %         if D_x_th(y)>0
    %             idxRef(y)=1;
    %         end
    %     elseif y<imgHeight
    %         if D_x_th(y)==0 && D_x_th(y+1)>0
    %             idxRef(y)=1;
    %         elseif D_x_th(y-1)>0 && D_x_th(y)==0
    %             idxRef(y)=-1;
    %         end
    %     else
    %         if D_x_th(y)>0
    %             idxRef(y)=-1;
    %         end
    %     end
    % end

    % 幅に制限を設けない
    %{
    startIdx = find(idxRef==1);
    endIdx = find(idxRef==-1);

    pksNum = nnz(idxRef==1);
    pk_i = zeros(pksNum,1);
    
    for k=1:pksNum
        idxs = (startIdx(k):endIdx(k))';

        sigma_D = sum(D_i(idxs));
        sigma_jxD = sum(idxs.*D_i(idxs));

        pk_i(k) = sigma_jxD / sigma_D;
    end
    %}
    
    TF_D_x = (D_x>th);
    diff_TF = [diff(TF_D_x)];
    startIdx = find(diff_TF==1)+1;
    endIdx = find(diff_TF==-1);
    
    if endIdx(1)<startIdx(1)
        endIdx = endIdx(2:length(endIdx));
    end
    
    if endIdx(end)<startIdx(end)
        startIdx = startIdx(1:length(startIdx)-1);
    end

    % 山の幅が<w_thのもののみを選ぶ
    btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
    startIdx_btm = startIdx(btmIdx);
    endIdx_btm = endIdx(btmIdx);

    pksNum = length(btmIdx);
    pk_i = zeros(pksNum,1); % x=iにおけるピーク

    sIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
    eIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];

    % centroid method
    for k=1:pksNum
        idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

        sigma_D = sum(D_x(idxs));
        sigma_jxD = sum(idxs .* D_x(idxs));

        pk_i(k) = sigma_jxD/sigma_D;
    end
    pksCell{x} = [x*ones(pksNum,1), pk_i];

    % local maximum method
    for k=1:pksNum
        idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
        if isscalar(idxs)
            pk_i(k) = idxs;
        else
            [~,pk_i(k)] = max(D_x(idxs));
            pk_i(k) = pk_i(k) + startIdx_btm(k) - 1;
        end
    end
    pksCell_max{x} = [x*ones(pksNum,1), pk_i];
end

pks = vertcat(pksCell{:});
pks_max = vertcat(pksCell_max{:});

% fig = figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
hold on;
scatter(pks(:,1),pks(:,2),3,'c','filled');
title("Peak Dots (centroid method)");xlabel("$x$");ylabel("$y$");

% saveas(gcf,dir+date+"PkDots.fig")
% saveas(gcf,dir+date+"PkDots.png")


% startIdx, endIdxの位置もプロット
% どこの情報を使用しているかを説明
sIdxs = vertcat(sIdxC{:});
eIdxs = vertcat(eIdxC{:});

% figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks(:,1),pks(:,2),3,'c','filled');
scatter(sIdxs(:,1),sIdxs(:,2),3,'yellow','filled');
scatter(eIdxs(:,1),eIdxs(:,2),3,'red','filled');
hold off;
title("Peak Dots and Reference Range");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethodRefRange.png","Resolution",600);
% saveas(gcf,dir+date+"PkDotsAndRefRange.fig")
% saveas(gcf,dir+date+"PkDotsAndRefRange.png")

%%
% リサンプルを行う
p_rsmpl = 8; q_rsmpl = 1;
rRatio = p_rsmpl / q_rsmpl;
D_x_r = resample(D_x,p_rsmpl,q_rsmpl);

% リサンプルされたデータの表示
% figure;plot(D_x_r);
% axis tight;
% hold on;
% yline(th);
% hold off;
% % xlim([1 round(p_rsmpl/q_rsmpl)*100]);
% ylim([0 1]);
% colormap(flip(gray));colorbar("eastoutside");clim([0 1]);
% title("$D$ ("+num2str(p_rsmpl/q_rsmpl)+"x resampled)");xlabel("$y$");ylabel("$D$");

% idx_r(1)=1にしたい
idx_r = 1+(0:length(D_x_r)-1)'/(p_rsmpl/q_rsmpl);

% 元のデータに重ねて表示
figure;plot(D_x,"-","Marker","x","MarkerSize",5,"MarkerFaceColor","auto");
axis tight; hold on;
plot(idx_r,D_x_r,"-","Marker",".","MarkerSize",5,"MarkerFaceColor","auto");
xlim([1 100]);
ylim([0 1]);
title("$D$ (original and "+num2str(p_rsmpl/q_rsmpl)+"x resampled)");xlabel("$y$");ylabel("$D$");
legend(["original data";"resamled data"]);
saveas(gcf,dir+date+"D_xAndD_x_r.fig");saveas(gcf,dir+date+"D_xAndD_x_r.png");

%%
% リサンプルされたデータについても、startIdx, endIdxを表示

TF_D_x_r = (D_x_r>th);
diff_TF_r = diff(TF_D_x_r);
startIdx = find(diff_TF_r==1)+1;
endIdx = find(diff_TF_r==-1);

if endIdx(1)<startIdx(1)
    endIdx = endIdx(2:length(endIdx));
end

if endIdx(end)<startIdx(end)
    startIdx = startIdx(1:length(startIdx)-1);
end

w_th_r = w_th*rRatio; % 「山」の幅の最大値
btmIdx = find((endIdx-startIdx)<w_th_r); % 溝底に対応するstartIdxのIdxを調べる
startIdx_btm = startIdx(btmIdx);
endIdx_btm = endIdx(btmIdx);

pksNum = length(btmIdx);
pk_i = zeros(pksNum,1); % x=iにおけるピーク

for k=1:pksNum
    idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

    sigma_D = sum(D_x_r(idxs));
    sigma_jxD = sum(idxs .* D_x_r(idxs));

    pk_i(k) = sigma_jxD/sigma_D;
end

% figure;plot(D_x_r(:));
% axis tight;
% hold on;
% yline(th);
% hold off;
% xlim([1 100*rRatio]);
% ylim([0 1]);
% title("$D$ on $x$="+num2str(x_c)+" ("+num2str(rRatio)+"x resampled)");xlabel("$y$");ylabel("$D$");
% colormap(flip(gray));
% colorbar("eastoutside");
% clim([0 1]);

% pk_iを重ねて表示
% figure;plot(D_i);
% axis tight;
% hold on;
% for k=1:pksNum
%     xline(pk_i(k))
% end
% hold off;
% xlim([1 1000]);
% title("$D_{th}$ on $x$="+num2str(i));xlabel("$y$");ylabel("$D_{th}$");

% startIdx, endIdxも表示
figure;
plot(D_x_r,"-","Marker",".","MarkerSize",5,"MarkerFaceColor","blue")
axis tight;
hold on;yline(th);
scatter(startIdx_btm(:),D_x_r(startIdx_btm),5,"r","filled");
scatter(endIdx_btm(:),D_x_r(endIdx_btm),5,"y","filled");
hold off;
xlim([1 100*rRatio]);
ylim([0 1]);
title("$D$ and reference range"+" ("+num2str(rRatio)+"x resampled)");xlabel("$y$");ylabel("$D$");
colormap(flip(gray));colorbar("eastoutside");clim([0 1]);

%%
% リサンプル後のデータを画像上に表示
% p_rsmpl, q_rsmplについては前セクションと同じパラメータを使用する
% centroid method(重心法(仮))を使う。

pksCell_r = cell(1,divImgWidth);

% startIdx, endIdxのプロット用
sIdxC_r = cell(1,divImgWidth);
eIdxC_r = cell(1,divImgWidth);

for x=1:divImgWidth
    D_x = z(:,x);
    D_x_r = resample(D_x,p_rsmpl,q_rsmpl);

    TF_D_x_r = (D_x_r>th);
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

% figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks_r(:,1),pks_r(:,2),3,'c','filled');
scatter(sIdxs_r(:,1),sIdxs_r(:,2),3,'yellow','filled');
scatter(eIdxs_r(:,1),eIdxs_r(:,2),3,'red','filled');
hold off;
title("Peak Dots and Reference Range (resampled)");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethodRefRange.png","Resolution",600);

% リサンプルする前のデータと重ねて表示
figure;
imshow(img_small);
% fig = createFigure([0 0 10 15]);
% imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks(:,1),pks(:,2),3,'b',"filled");
scatter(pks_r(:,1),pks_r(:,2),3,'c','filled');
legend(["original","resampled"]);
hold off;
title("Peak Dots and Reference Range (resampled)");xlabel("$x$");ylabel("$y$")

% xlim([1 1000]);ylim([1 1000]);

%%
% Local Maximum Method

pksCell_r_max = cell(1,divImgWidth);

for x=1:divImgWidth
    D_x = z(:,x);
    D_x_r = resample(D_x,p_rsmpl,q_rsmpl);

    startIdx_btm = sIdxC_r{1,x};
    endIdx_btm = eIdxC_r{1,x};

    pksNum = size(endIdx_btm,1);
    pk_i = zeros(pksNum,1); % x=iにおけるピーク

    for k=1:pksNum % それぞれのピークの座標を求める
        idxs = (startIdx_btm(k,2):endIdx_btm(k,2))';
        if isscalar(idxs)
            pk_i(k) = idxs;
        else
            [~,pk_i(k)] = max(D_x_r(idxs));
            pk_i(k) = pk_i(k) + startIdx_btm(k,2) -1 ;
        end
    end

    pksCell_r_max{x} = [x*ones(pksNum,1), pk_i];
end

pks_r_max = vertcat(pksCell_r_max{:});
pks_r_max(:,2) = (pks_r_max(:,2)-1) / rRatio + 1;

% Local Maximum Method
% figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks_r_max(:,1),pks_r_max(:,2),3,'c','o','filled');
hold off;
title("Peak Dots and Reference Range (Local Maximum Method)");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);

%%
% Centroid Method & Local Maximum Method
% figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
% scatter(pks(:,1),pks(:,2),3,'blue',"filled");
scatter(pks_r(:,1),pks_r(:,2),3,'cyan','filled');
scatter(pks_r_max(:,1),pks_r_max(:,2),3,'blue','filled');
hold off;
title("Peak Dots and Reference Range");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);
% legend(["centroid (original)","centroid (resampled)","local maximum (resampled)"])
legend(["centroid (resampled)","local maximum (resampled)"])

%%
%{
ここから先3セクションでは、以下のデータについて
画像一枚分から得た形状データを比較する

(0. リサンプルしていないデータ、local maximum method)
　<--これについては今回作成しなかった（2026/06/02, 同日にプログラムを書いた）
1. リサンプルしていないデータ、centroid method
2. リサンプルしたデータ、centroid method
3. リサンプルしたデータ、local maximum method

%}

%%
% リサンプルしていないデータでLocal Maximum Methodによって得たデータpks_max
fig = figure;
imshow(img_small,"InitialMagnification","fit");axis tight
hold on;
scatter(pks_max(:,1),pks_max(:,2),3,'c','filled');
xlabel("$x$");ylabel("$y$")

w_prl = divImgWidth; % 平行四辺形の高さ
h_prl = 8; % 平行四辺形の底辺

% この2つはfor文に含めないように注意
p2 = [0;0];
th_hist = 125;

% pksの傾きを補正したpks_corを得る
[p1,p2,pksCorCell] = fitGroove(1,fig,p2,w_prl,h_prl,{pks_max});
pks_cor = pksCorCell{1};

% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

binWidth = 5; % BinWidth
[counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

[~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));


tol = 4;
% そのピークの中心からtol(pixel)以内にあるy座標
y_min = groove1Center - tol;
y_max = groove1Center + tol;

idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
points_max_ori = pks_cor(idxs,:);

%%
% リサンプルしていないデータでcentroid Methodによって得たデータpks

fig = figure;
imshow(img_small,"InitialMagnification","fit");axis tight
hold on;
scatter(pks(:,1),pks(:,2),3,'c','filled');
xlabel("$x$");ylabel("$y$")

w_prl = divImgWidth; % 平行四辺形の高さ
h_prl = 8; % 平行四辺形の底辺

% この2つはfor文に含めないように注意
p2 = [0;0];
th_hist = 125;

% pksの傾きを補正したpks_corを得る
[p1,p2,pksCorCell] = fitGroove(1,fig,p2,w_prl,h_prl,{pks});
pks_cor = pksCorCell{1};

% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

binWidth = 5; % BinWidth
[counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

[~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));


tol = 4;
% そのピークの中心からtol(pixel)以内にあるy座標
y_min = groove1Center - tol;
y_max = groove1Center + tol;

idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
points_centroid_ori = pks_cor(idxs,:);


%%
% D_x_rに対するCentroid Methodのデータpks_rについて

fig = figure;
imshow(img_small,"InitialMagnification","fit");axis tight
hold on;
scatter(pks_r(:,1),pks_r(:,2),3,'c','filled');
xlabel("$x$");ylabel("$y$")

w_prl = divImgWidth; % 平行四辺形の高さ
h_prl = 8; % 平行四辺形の底辺

p2 = [0;0];
th_hist = 125;

% pksの傾きを補正したpks_corを得る
[p1,p2,pksCorCell] = fitGroove(1,fig,p2,w_prl,h_prl,{pks_r});
pks_cor = pksCorCell{1};

% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

binWidth = 5; % BinWidth
[counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

[~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));


tol = 4;
% そのピークの中心からtol(pixel)以内にあるy座標
y_min = groove1Center - tol;
y_max = groove1Center + tol;

idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
points_centroid_rspml = pks_cor(idxs,:);


%%
% リサンプルしたD_x_rについて、local maximum methodによるデータ

fig = figure;
imshow(img_small,"InitialMagnification","fit");axis tight
hold on;
scatter(pks_r_max(:,1),pks_r_max(:,2),3,'c','filled');
xlabel("$x$");ylabel("$y$")

w_prl = divImgWidth; % 平行四辺形の高さ
h_prl = 8; % 平行四辺形の底辺

% この2つはfor文に含めないように注意
p2 = [0;0];
th_hist = 125;

% pksの傾きを補正したpks_corを得る
[p1,p2,pksCorCell] = fitGroove(1,fig,p2,w_prl,h_prl,{pks_r_max});
pks_cor = pksCorCell{1};

% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);

binWidth = 5; % BinWidth
[counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

[~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));



tol = 4;
% そのピークの中心からtol(pixel)以内にあるy座標
y_min = groove1Center - tol;
y_max = groove1Center + tol;

idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
points_max_rspml = pks_cor(idxs,:);


%%
figure;hold on;
plot(points_max_ori(:,2));
plot(points_centroid_ori(:,2));
plot(points_max_rspml(:,2));
plot(points_centroid_rspml(:,2));
hold off;
axis tight;
xlabel("$x$");ylabel("$y$");
legend(["local maximum method (original)";...
        "centroid method (original)";...
        "local maximum method (resampled)";...
        "centroid method (resampled)"]);

lgd = legend;
lgd.ItemHitFcn = @togglevisibility;


%%
% 4つのデータを画像上に重ねて表示

fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");axis on;axis tight
hold on;
scatter(pks_max(:,1),pks_max(:,2),3,"filled")
scatter(pks(:,1),pks(:,2),3,"filled")
scatter(pks_r_max(:,1),pks_r_max(:,2),3,'filled');
scatter(pks_r(:,1),pks_r(:,2),3,"filled");
xlabel("$x$");ylabel("$y$")

legend(["local maximum method (original)";...
        "centroid method (original)";...
        "local maximum method (resampled)";...
        "centroid method (resampled)"]);

lgd = legend;
lgd.ItemHitFcn = @togglevisibility;

%%
% リサンプルしたデータで
% centroid methodとlocal maximum methodの比較
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");axis on;axis tight
hold on;
scatter(pks_r(:,1),pks_r(:,2),3,"filled");
scatter(pks_r_max(:,1),pks_r_max(:,2),3);
xlabel("$x$");ylabel("$y$")

legend(["centroid method (resampled)";"local maximum method (resampled)"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;


