% 2026/04/03 作成
% D_thに頼らない、よりロバストなピーク検出方法を考える
% さらに、高解像度化による画像のノイズ(?)に左右されない方法を考える
% findpeaksを使い、局所的最大値付近のデータを使ってより精度の高いピーク検出を行う。

%%
% 資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
% set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
% 準備

% img_old = imread("./pictures/old/8x/DSC0113_8x.png");
img_new = imread("./pictures/1111/DSC1111-00007-8x.png");

imgWidth = 3000; % 1回でimgWidth(pixel)分のx座標を処理
xstart = 15001;
img_gray = rgb2gray(img_new);
img_small = img_gray(:,xstart:xstart+imgWidth-1);
imgHeight = size(img_small,1);

% figure;imshow(img_small);axis on;

z = 1 - double(img_small)/255;

%%
% xを固定
x = 1;

D_x = z(:,x);


% パラメータの設定を考える用のfigure

figure;imshow(img_small);
axis on;
title("img");xlabel("$x$");ylabel("$y$");
xlim([1 1000]);ylim([1 1000]);

figure;findpeaks(D_x,Annotate="extents");
title("Local Maximum of $D_x$");xlabel("$y$");ylabel("$D_x$");
xlim([1 1000]);

figure;findpeaks(D_x,Annotate="extents",MinPeakDistance=50);
title("Local Maximum of $D_x$");xlabel("$y$");ylabel("$D_x$");
xlim([1 1000]);


%%
mind = 50;
maxPrd = 30;

% あるx座標における局所的最大値の情報
% [pks_x, locs_x, w_x, p_x] = findpeaks(D_x,MinPeakDistance=mind);
[pks_x, locs_x, w_x, p_x] = findpeaks(D_x,MinPeakDistance=mind,...
    MinPeakWidth=5);

prd = w_x .* p_x;

btmIdx = find(prd<maxPrd);
pksNum = length(btmIdx);

LRidxs = zeros(pksNum,2);

% 局所的最大値の左側
LRidxs(:,1) = round(locs_x(btmIdx) - w_x(btmIdx));
LRidxs(LRidxs(:,1)<1, 1) = 1;

LRidxs(:,2) = round(locs_x(btmIdx) + w_x(btmIdx));
LRidxs(LRidxs(:,2)>imgHeight, 1) = imgHeight;

pk_x = zeros(pksNum,1);

for k=1:pksNum
    if LRidxs(k,1)>1 && LRidxs(k,2)<imgHeight
        calcIdxs = (LRidxs(k,1):LRidxs(k,2))';

        sigma_D = sum(D_x(calcIdxs));
        sigma_jxD = sum(calcIdxs .* D_x(calcIdxs));

        pk_x(k) = sigma_jxD/sigma_D;
    end
end

figure;findpeaks(D_x,"MinPeakDistance",mind);
hold on;
for k=1:pksNum
    xline(pk_x(k));
end
hold off;
title("Local Maximums and Peak Centroids");xlabel("$x$");ylabel("$y$");

%%
mind = 50;
maxPrd = 10;
pksCell = cell(1,imgWidth);

for x=1:imgWidth
    D_x = z(:,x);

    % [pks_x, locs_x, w_x, p_x] = findpeaks(D_x,MinPeakDistance=mind);
    [pks_x, locs_x, w_x, p_x] = findpeaks(D_x,MinPeakDistance=mind,...
        MinPeakWidth=10);

    prd = w_x .* p_x;

    btmIdx = find(prd<maxPrd);
    pksNum = length(btmIdx);

    LRidxs = zeros(pksNum,2);

    % 局所的最大値の左側
    LRidxs(:,1) = round(locs_x(btmIdx) - w_x(btmIdx));
    LRidxs(LRidxs(:,1)<1, 1) = 1;

    LRidxs(:,2) = round(locs_x(btmIdx) + w_x(btmIdx));
    LRidxs(LRidxs(:,2)>imgHeight, 1) = imgHeight;

    pk_x = zeros(pksNum,1);

    for k=1:pksNum
        if LRidxs(k,1)>1 && LRidxs(k,2)<imgHeight
            calcIdxs = (LRidxs(k,1):LRidxs(k,2))';

            sigma_D = sum(D_x(calcIdxs));
            sigma_jxD = sum(calcIdxs .* D_x(calcIdxs));

            pk_x(k) = sigma_jxD/sigma_D;
        end
    end
    
    pksCell{x} = [x*ones(pksNum,1), pk_x];
end

pks = vertcat(pksCell{:});

fig = figure;
imshow(img_small);
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
title("Peak Dots (centroid method using findpeaks)");xlabel("$x$");ylabel("$y$");

