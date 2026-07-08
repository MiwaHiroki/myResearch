% 2026/04/16作成
% pkCentroid.mをもとに作成
% 1x, 2x, 4x, 8xの画像それぞれについてcentroid法で溝の形状を抽出する
% 主にパラメータ設定のための.mファイル

%%
% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
% 画像の読み込みと基本パラメータの設定

% img_old = imread("./pictures/old/8x/DSC0113_8x.png");
img_newori = imread("./pictures/1111/original/DSC1111-00007-ori.png");
img_new2 = imread("./pictures/1111/2x/DSC1111-00007-2x.png");
img_new4 = imread("./pictures/1111/4x/DSC1111-00007-4x.png");
img_new8 = imread("./pictures/1111/8x/DSC1111-00007-8x.png");




%%
% 共通パラメータ設定
%%% --------------------------- %%%
l = 10;
th = 0.6;

date = "0421/";
dirbase = "./data/"+date;
%%% --------------------------- %%%


% originalのとき
% %{
%%% --------------------------- %%%
xstart_ori = 1001;
oriImgWidth = size(img_newori,2);
divImgWidth = round(oriImgWidth / l);
xstart_1x = xstart_ori;
img_gray = rgb2gray(img_newori);
img_small = img_gray(:, xstart_1x:xstart_1x+divImgWidth-1);
divImgHeight = size(img_small,1);

% 画像の表示
% figure;imshow(img_small);axis on;
% fig= createFigure([0 0 10 10]);imshow(img_small,"InitialMagnification","fit");axis on;
% title("original img");xlabel("$x$");ylabel("$y$");

w_th = 5; % 「山」の幅の最大値
dir = dirbase + "1x/";

h_prl = 8; % 平行四辺形の底辺
w_prl = divImgWidth; % 平行四辺形の高さ
th_hist = 250;

binWidth = 1; % BinWidth
%%% --------------------------- %%%
%}

% 8xのとき 
%{
%%% --------------------------- %%%
oriImgWidth = size(img_new8,2);
divImgWidth = round(oriImgWidth / l); % 1回でimgWidth(pixel)分のx座標を処理
xstart_8x = round(xstart_ori * (size(img_new8,2)/size(img_newori,2)));
img_gray = rgb2gray(img_new8);
img_small = img_gray(:, xstart_8x:xstart_8x+divImgWidth-1);
divImgHeight = size(img_small,1);

% figure;imshow(img_small);axis on;
% fig= createFigure([0 0 10 10]);imshow(img_small,"InitialMagnification","fit");axis on;
% title("8x img");xlabel("$x$");ylabel("$y$");

w_th = 30; % 「山」の幅の最大値
dirbase = dir + "/8x/";

h_prl = 60; % 平行四辺形の底辺
w_prl = divImgWidth; % 平行四辺形の高さ
th_hist = 1000;

binWidth = 5; % BinWidth
%%% --------------------------- %%%
%}


z = 1 - double(img_small) / 255;
z_th = z - th;
z_th(z_th<0) = 0;


x = 1;
D_x = z(:,x);
D_x_th = z_th(:,x);

% figure;plot(D_x);title("$D$ on $x$="+num2str(x) + " (original img)");xlabel("$x$");ylabel("$D_x$")

idxRef = zeros(divImgHeight,1);
% D_iの増減について調べ、メモした結果のようなベクトル
% D_iが0から+になるとき=「山の始まり」には1を
% D_iが+から0になるとき=「山の終わり」には-1を記録する。

for j=1:divImgHeight
    if j==1
        if D_x_th(j)>0
            idxRef(j)=1;
        end
    else
        if D_x_th(j)>0 && D_x_th(j-1)==0
            idxRef(j)=1;
        elseif D_x_th(j)==0 && D_x_th(j-1)>0
            idxRef(j)=-1;
        elseif j==divImgHeight && D_x_th(j)>0
            idxRef(j)=-1;
        end
    end
end


startIdx = find(idxRef==1);
endIdx = find(idxRef==-1);

if length(startIdx)~=length(endIdx)
    endIdx = [endIdx;divImgHeight];
end

btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
startIdx_btm = startIdx(btmIdx);
endIdx_btm = endIdx(btmIdx);

pksNum = length(btmIdx);
pk_x = zeros(pksNum,1); % x=xにおけるピーク

for k=1:pksNum % pk_x(k)の計算
    if startIdx_btm(k)>1 && endIdx_btm(k)<divImgHeight
        idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
    
        sigma_D = sum(D_x_th(idxs));
        sigma_jxD = sum(idxs .* D_x_th(idxs));
    
        pk_x(k) = sigma_jxD/sigma_D;
    end
end

figure;plot(D_x(:));
axis tight;
hold on;
yline(th);
hold off;
% xlim([1 1000]);
ylim([0 1]);
title("$D$ on $x$="+num2str(x));xlabel("$y$");ylabel("$D$");
colormap(flip(gray));
colorbar("eastoutside");
clim([0 1]);
saveas(gcf,dir+"D_1x.png");saveas(gcf,dir+"D_1x.fig");


% figure;plot(D_i);
% axis tight;
% hold on;
% for k=1:pksNum
%     xline(pk_i(k))
% end
% hold off;
% xlim([1 1000]);
% title("$D_{th}$ on $x$="+num2str(i));xlabel("$y$");ylabel("$D_{th}$");


pksCell = cell(1,divImgWidth);

% startIdx, endIdxのプロット用
sIdxC = cell(1,divImgWidth);
eIdxC = cell(1,divImgWidth);

for x=1:divImgWidth
    D_x_th = z_th(:,x);

    idxRef = zeros(divImgHeight,1);

    for j=1:divImgHeight
        if j==1
            if D_x_th(j)>0
                idxRef(j)=1;
            end
        else
            if D_x_th(j)>0 && D_x_th(j-1)==0
                idxRef(j)=1;
            elseif D_x_th(j)==0 && D_x_th(j-1)>0
                idxRef(j)=-1;
            elseif j==divImgHeight && D_x_th(j)>0
                idxRef(j)=-1;
            end
        end
    end

    % 山の幅が<w_thのもののみを選ぶ
    startIdx = find(idxRef==1);
    endIdx = find(idxRef==-1);

    if length(startIdx)~=length(endIdx)
        endIdx = [endIdx;divImgHeight];
    end

    btmIdx = find((endIdx-startIdx)<w_th); % 溝底に対応するstartIdxのIdxを調べる
    startIdx_btm = startIdx(btmIdx);
    endIdx_btm = endIdx(btmIdx);

    pksNum = length(btmIdx);
    pk_x = zeros(pksNum,1); % x=iにおけるピーク

    sIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
    eIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];


    for k=1:pksNum
        if startIdx_btm(k)>1 && endIdx_btm(k)<divImgHeight
            idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
        
            sigma_D = sum(D_x_th(idxs));
            sigma_jxD = sum(idxs .* D_x_th(idxs));
        
            pk_x(k) = sigma_jxD/sigma_D;
        end
    end
    
    pksCell{x} = [x*ones(pksNum,1), pk_x];
end

pks = vertcat(pksCell{:});
sIdxs = vertcat(sIdxC{:});
eIdxs = vertcat(eIdxC{:});

% fig = figure;
% imshow(img_small);
fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
axis on;ax=gca; % axis tight;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
title("Peak Dots");xlabel("$x$");ylabel("$y$");
% !!ファイル名を変える!!
saveas(fig,dir+"pkDots_1x.fig");saveas(fig,dir+"pkDots_1x.png");


fig = createFigure([0 0 10 15]);
imshow(img_small,"InitialMagnification","fit");
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
scatter(sIdxs(:,1),sIdxs(:,2),1,'yellow','filled');
scatter(eIdxs(:,1),eIdxs(:,2),1,'red','filled');
hold off;
title("Peak Dots and Reference Range");xlabel("$x$");ylabel("$y$")
% xlim([1 1000]);ylim([1 1000]);
saveas(fig,dir+"pkDotsRefRange.fig");saveas(fig,dir+"pkDotsRefRange.png")

%%
% 溝一本分の座標データの取得
fig = figure;
imshow(img_small);
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
title("Peak Dots");xlabel("$x$");ylabel("$y$");

p2 = [0;0];

% pksの傾きを補正したpks_corを得る
[p1,p2,pks_cor] = fitGroove(1,fig,p2,w_prl,h_prl,pks);

% xlim([1 1000]);ylim([1 1000]);
% exportgraphics(fig,"./data/0322/PkDotsCmethod.png","Resolution",600);


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

figure;
plot(selected_points_new(:,2));
xlabel("$x$");ylabel("$y$");
title("Groove Coordinates");
% !!!保存ファイル名変える!!!
saveas(gcf,dir + "grvCoords_8x.fig");
saveas(gcf,dir + "grvCoords_8x.png");
