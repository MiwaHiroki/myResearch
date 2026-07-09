% interp2を使って疑似的な高解像度化を行う
% pkCentroidAndLocalMax_resample_1cycle.mをもとに作成
% 2026/07/01作成
% 形状抽出は重心法でやろうかな

%%
% 発表資料作成用
% set(0,'defaultTextInterpreter','latex');
% set(0,'defaultAxesTickLabelInterpreter','latex');
% set(0,'defaultLegendInterpreter','latex');
% set(0,'defaultColorbarTickLabelInterpreter','latex');

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
date = "0708";
dir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";


%%

i=1; % i=1~NUM_IMAGES
j=1; % j=1~NUM_SEGMENTS

img_new = imread(filenames_new(9-i) + ".png");
img_gray = rgb2gray(img_new);

[imgHeight,imgWidth] = size(img_gray);

divImgWidth = round(imgWidth / NUM_SEGMENTS);
xarray = [1:divImgWidth:imgWidth imgWidth+1]';

[img_omitMask,newWidth] = omitMask(img_gray, L_MASK);
imgData = ImageData(img_omitMask, [i;j]);

dValue = DarknessValue(imgData);
dValue = ddiff(dValue, D_THRESH);
diffTF = dValue.getDiffTF;

% dValue.dMatをinterp2で内挿してdMat_interpを作成
dMat = dValue.dMat;
[xx,yy] = meshgrid(1:newWidth,1:imgHeight);

step = 0.25;
[x_q,y_q] = meshgrid(1:step:newWidth,1:step:imgHeight);

dMat_interp = interp2(xx,yy,dMat,x_q,y_q,"cubic");


% startIdx, endIdxのプロット用
sIdxC = cell(1, imgData.width);
eIdxC = cell(1, imgData.width);

pts_centroid = GrooveCandidates(dValue);
pts_localMax = GrooveCandidates(dValue);

W_TH = 5;
w_TH = W_TH / step;

for x=1:imgData.width
    [startIdx, endIdx] = dValue.startEndIdx(x);
    [dValue,startIdx_btm,endIdx_btm,pksNum] = ...
        dValue.grooveBtmIdx(x,startIdx,endIdx,W_TH);
    % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

    cnt_x = dValue.extractGrv_cnt(x);
    max_x = dValue.extractGrv_max(x);

    pts_centroid.pksCell{x} = [x*ones(pksNum,1), cnt_x];
    pts_localMax.pksCell{x} = [x*ones(pksNum,1), max_x];
end

sIdxs = vertcat(sIdxC{:});
eIdxs = vertcat(eIdxC{:});
pks_cnt = vertcat(pts_centroid.pksCell{:});
pks_max = vertcat(pts_localMax.pksCell{:});

fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
imgData.showImg();
hold on;
scatter(pks_cnt(:,1),pks_cnt(:,2),3,'c','filled');
title("Peak Dots (centroid method)");

