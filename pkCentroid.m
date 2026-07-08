% 2026/03/01作成
% 山の重心(centroid)を溝の情報として利用する

%%
% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
% img_old = imread("./pictures/old/8x/DSC0113_8x.png");
img_new = imread("./pictures/1111/DSC1111-00007-8x.png");

imgWidth = 3000; % 1回でimgWidth(pixel)分のx座標を処理
xstart = 15001;
img_gray = rgb2gray(img_new);
img_small = img_gray(:,xstart:xstart+imgWidth-1);
imgHeight = size(img_small,1);

% figure;imshow(img_small);axis on;

z = 1 - double(img_small)/255;
th = 0.6;
z_th = z - th;
z_th(z_th<0) = 0;


%%
% iを固定して考える

% %{
i = 700;

D_i = z_th(:,i);

idxRef = zeros(imgHeight,1);
% D_iの増減について調べ、メモした結果のようなベクトル
% D_iが0から+になるとき=「山の始まり」には1を
% D_iが+から0になるとき=「山の終わり」には-1を記録する。

for j=1:imgHeight
    if j==1
        if D_i(j)>0
            idxRef(j)=1;
        end
    else
        if D_i(j)>0 && D_i(j-1)==0
            idxRef(j)=1;
        elseif D_i(j)==0 && D_i(j-1)>0
            idxRef(j)=-1;
        elseif j==imgHeight && D_i(j)>0
            idxRef(j)=-1;
        end
    end
end



startIdx = find(idxRef==1);
endIdx = find(idxRef==-1);

w_th = 30; % 「山」の幅の最大値
btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
startIdx_btm = startIdx(btmIdx);
endIdx_btm = endIdx(btmIdx);

pksNum = length(btmIdx);
pk_i = zeros(pksNum,1); % x=iにおけるピーク

for k=1:pksNum
    if startIdx_btm(k)>1 && endIdx_btm(k)<imgHeight
        idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
    
        sigma_D = sum(D_i(idxs));
        sigma_jxD = sum(idxs .* D_i(idxs));
    
        pk_i(k) = sigma_jxD/sigma_D;
    end
end

figure;plot(z(:,i));
axis tight;
hold on;
yline(th);
hold off;
xlim([1 1000]);ylim([0 1]);
title("$D$ on $x$="+num2str(i));xlabel("$y$");ylabel("$D$");
colormap(flip(gray));
colorbar("eastoutside");
clim([0 1]);


% figure;plot(D_i);
% axis tight;
% hold on;
% for k=1:pksNum
%     xline(pk_i(k))
% end
% hold off;
% xlim([1 1000]);
% title("$D_{th}$ on $x$="+num2str(i));xlabel("$y$");ylabel("$D_{th}$");

%}

%%
% iを固定した状態で、局所的最大値を使った方法との比較を行う
[tmpPks,tmpLocs,w,p] = findpeaks(z(:,1),...
    'MinPeakHeight',0.5,...
    'MinPeakDistance',50,...
    'MinPeakWidth',10);

% product = w.*p;
% idx = find(product < th_prd);
% 
% num = length(idx);
% 
% tmpPksX = k * ones(num,1);
% tmpPksY = zeros(num,1);
% tmpPksY(:,1) = tmpLocs(idx);

figure;findpeaks(z(:,i),"MinPeakHeight",0.5,...
    "MinPeakDistance",50,...
    "MinPeakWidth",10);
hold on;
for k=1:pksNum
    xline(pk_i(k));
end
xlim([1 1000]);ylim([0 1]);
hold off;

%%
% 前セクションではiを固定したが、iを1からimgWidthまで繰り返し行う。
% 結果を画像上にプロット


pksCell = cell(1,imgWidth);
w_th = 40;

% startIdx, endIdxのプロット用
sIdxC = cell(1,imgWidth);
eIdxC = cell(1,imgWidth);

for i=1:imgWidth
    D_i = z_th(:,i);

    idxRef = zeros(imgHeight,1);

    for j=1:imgHeight
        if j==1
            if D_i(j)>0
                idxRef(j)=1;
            end
        else
            if D_i(j)>0 && D_i(j-1)==0
                idxRef(j)=1;
            elseif D_i(j)==0 && D_i(j-1)>0
                idxRef(j)=-1;
            elseif j==imgHeight && D_i(j)>0
                idxRef(j)=-1;
            end
        end
    end

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

    % 山の幅が<w_thのもののみを選ぶ
    startIdx = find(idxRef==1);
    endIdx = find(idxRef==-1);

    if length(startIdx)~=length(endIdx)
        endIdx = [endIdx;imgHeight];
    end

    btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
    startIdx_btm = startIdx(btmIdx);
    endIdx_btm = endIdx(btmIdx);

    pksNum = length(btmIdx);
    pk_i = zeros(pksNum,1); % x=iにおけるピーク

    sIdxC{1,i} = [i*ones(pksNum,1), startIdx_btm];
    eIdxC{1,i} = [i*ones(pksNum,1), endIdx_btm];


    for k=1:pksNum
        if startIdx_btm(k)>1 && endIdx_btm(k)<imgHeight
            idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
        
            sigma_D = sum(D_i(idxs));
            sigma_jxD = sum(idxs .* D_i(idxs));
        
            pk_i(k) = sigma_jxD/sigma_D;
        end
    end
    pksCell{i} = [i*ones(pksNum,1), pk_i];
end

pks = vertcat(pksCell{:});

% fig = figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
title("Peak Dots (centroid method)");xlabel("$x$");ylabel("$y$");

% saveas(gcf,"./data/0325/PkDots.fig")
% saveas(gcf,"./data/0325/PkDots.png")


%%
w_prl = imgWidth; % 平行四辺形の高さ
h_prl = 60; % 平行四辺形の底辺

% この2つはfor文に含めないように注意
p2 = [0;0];
th_hist = 1000;

% pksの傾きを補正したpks_corを得る
[p1,p2,pks_cor] = fitGroove(1,fig,p2,w_prl,h_prl,pks);

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
selected_points_new = pks_cor(idxs,:);

%%
figure;
plot(selected_points_new(:,2));
xlabel("$x$");ylabel("$y$");
title("Groove Coordinates (centroid method)");
dir = "./data/0325/";
saveas(gcf,dir + "grvCoords.fig");
saveas(gcf,dir + "grvCoords.png");


%%
% startIdx, endIdxの位置もプロット
% どこの情報を使用しているかを説明
sIdxs = vertcat(sIdxC{:});
eIdxs = vertcat(eIdxC{:});

% figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
scatter(sIdxs(:,1),sIdxs(:,2),1,'yellow','filled');
scatter(eIdxs(:,1),eIdxs(:,2),1,'red','filled');
hold off;
title("Peak Dots and Reference Range");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethodRefRange.png","Resolution",600);


%%