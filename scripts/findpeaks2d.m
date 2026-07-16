% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
set(0,'defaultAxesFontSize',16)

%%
img = imread('./pictures/1111/DSC1111-00002-8x.png');
% img_gray = rgb2gray(img);

[xmax,ymax] = size(img);

widthIdx = 1001:1600;
heightIdx = 1001:1600;
img_small = img(heightIdx,widthIdx);
% figure;imshow(img_small);title("DSC1111-00002-8x");

img_small = double(img_small);

%画素値の大きなピーク
% figure;findpeaks(img_small(:,500),'MinPeakDistance',10)


%%
%{
tmp = 1;
n = 50; % 各yについて、ピークを最大何個記録するか
pksX = zeros(n*ymax,1); % ピークのx座標を格納
pksY = zeros(n*ymax,1); % ピークのy座標を格納

thresh1 = 0.2;thresh2 = 0.5; % 溝の底を抽出するには二つの閾値が必要
    
for i=1:xmax
    [pks,locs] = findpeaks(z_new(:,i),'MinPeakHeight',thresh1);
    num = nnz(pks<thresh2);
    idx = find(pks<thresh2); % ピークの位置が<0.5のもののindex
    locs = locs(idx);

    % [pks,locs] = findpeaks(z_new(:,i));
    % num = length(pks);
    % 
    pksX(tmp:tmp+num-1) = i;
    pksY(tmp:tmp+num-1) = locs;
    tmp = tmp+num;
end

pksX = pksX(1:tmp); % 値のある範囲のみを選択
pksY = pksY(1:tmp);

figure;
imshow(img_small)
hold on
scatter(pksX,pksY,1,'filled');
xlabel('X');ylabel('Y')
title('peak(z new)')
hold off
%}

%%
% 画像をそのまま（トリミングせずに）行う処理
% 1/8周の画像の左右の端に、溝から大きく外れたピーク点が現れる

%{
pksCell = cell(xmax,1);

thresh1 = 0.2;thresh2 = 0.6; % ピークの高さについての閾値
d = 20; % MinPeakDistance
minw = 20; % MinPeakWidth
minp = 0.2; % MinPeakProminence
maxp = 0.7; % MaxPeakProminence


for i=1:xmax
    [tmpPks,tmpLocs,w,p] = findpeaks(z_new(:,i),...
        'MinPeakProminence',minp,...
        'MinPeakHeight',thresh1);...
        %,'MinPeakDistance',d);
    
    % num = nnz(tmpPks < thresh2);
    % idx = find(tmpPks < thresh2); % ピークの位置が<0.5のもののindex

    idx = find(p < maxp); % ピークのプロミネンスが<maxpのもののindex
    num = length(idx);

    tmpPksX = zeros(num,1);
    tmpPksY = tmpPksX;

    tmpPksX(:,1) = i;
    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{i,1} = [tmpPksX tmpPksY];

end

pks = vertcat(pksCell{:,:});

figure;
imshow(img_small);
set(gca,'YDir','reverse')
title('peaks')
xlabel('X');ylabel('Y');
hold on
axis equal
scatter(pks(:,1),pks(:,2),3,'filled');
hold off
%}

%% 
% マスク部分=輝度値が0のところを取り除く
% 輝度値が0の部分に内接する長方形を作成し
% その内側を新しい画像(img_omitMask)として処理を行う

[height,width] = size(img_small);

th = 20; % 閾値
img_omitMask = omitMask(img_small,th);
% figure;imshow(img_omitMask)


%%
z = double(img_omitMask)*(-2/255)+1;

pksCell = cell(max(widthIdx)-min(widthIdx),1);

thresh1 = 0.3;
thresh2 = 0.6;
minWidth = 50;
minw = 20; % MinPeakWidth
minp = 0.2; % MinPeakProminence
maxp = 0.8; % MaxPeakProminence


for i=1:size(img_omitMask,2)
    [tmpPks,tmpLocs,w,p] = findpeaks(z(:,i),...
        'MinPeakProminence',minp);

    product = w.*p;
    % 溝底のproductは10~20くらい

    idx = find(product < 20);
    num = length(idx);

    tmpPksX = i*ones(num,1);
    tmpPksY = tmpPksX;

    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{i,1} = [tmpPksX tmpPksY];
end

pks = vertcat(pksCell{:,1});

%%
figure;
imshow(uint8(img_omitMask));
set(gca,'YDir','reverse')
title('peak dots on a image')
xlabel('X');ylabel('Y');
hold on
axis equal
scatter(pks(:,1),pks(:,2),10,'filled','cyan');
hold off
