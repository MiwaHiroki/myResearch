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

iImg=1; % i=1~NUM_IMAGES
iSegment=1; % j=1~NUM_SEGMENTS

img_new = imread(filenames_new(9-iImg) + ".png");
img_gray = rgb2gray(img_new);

[height,width] = size(img_gray);

divWidth = round(width / NUM_SEGMENTS);
xarray = [1:divWidth:width width+1]';
img_small = img_gray(:, xarray(iSegment):xarray(iSegment+1)-1);

[img_omitMask,newWidth] = omitMask(img_small, L_MASK);
origImg = ImageData(img_omitMask, [iImg;iSegment]);
origWidth = origImg.width; origHeight = origImg.height;

% interpolation
[xx,yy] = meshgrid(1:origWidth, 1:origHeight);

step = 0.25; % the distance between query points, rRatio will be 1/step
[x_q,y_q] = meshgrid(1:step:origWidth, 1:step:origHeight);

method = "linear"; % method for interpolation
img_interp2 = interp2(xx,yy,origImg.img,x_q,y_q,method);
intpImg = ImageData(img_interp2,[iImg,iSegment]);
intpWidth = intpImg.width; intpHeight = intpImg.height;

origD = DarknessValue(origImg);
origD = setDiffTF(origD, D_THRESH);

p_rsmpl = 8; q_rsmpl = 1;
rsmplD = dResample(origD,8,1);

intpD = DarknessValue(intpImg);
intpD = setDiffTF(intpD, D_THRESH);


% cells in which startIdx and endIdx are recorded.
% for original img
sIdxC = cell(1, origWidth);
eIdxC = cell(1, origWidth);
% for resampled img
sIdxC_rsmpl = cell(1,origWidth);
eIdxC_rsmpl = cell(1,origWidth);
% for interpolated img
sIdxC_intp = cell(1,intpWidth);
eIdxC_intp = cell(1,intpWidth);

% objects in which groove candidates are recorded.
% for original img
pts_cnt = GrooveCandidates(origD);
pts_max = GrooveCandidates(origD);
% for resampled img
pts_cnt_r = GrooveCandidates(rsmplD);
pts_max_r = GrooveCandidates(rsmplD);
% for interpolated img
pts_cnt_intp = GrooveCandidates(intpD);
pts_max_intp = GrooveCandidates(intpD);


W_TH = 8;
W_TH_INTERP = W_TH / step;

for x=1:origWidth
    [startIdx, endIdx] = getStartEndIdx(origD, x);
    [origD,~,~,pksNum] = ...
        getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
    % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

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

sIdxs = vertcat(sIdxC{:});
eIdxs = vertcat(eIdxC{:});
pks_cnt = vertcat(pts_cnt.pksCell{:});
pks_max = vertcat(pts_max.pksCell{:});

pks_cnt_r = vertcat(pts_cnt_r.pksCell{:});
pks_max_r = vertcat(pts_max_r.pksCell{:});


for x=1:intpWidth
    [startIdx, endIdx] = intpD.getStartEndIdx(x);
    [intpD, startIdx_btm, endIdx_btm, pksNum] = ...
        getGrooveBtmIdx(intpD,x,startIdx,endIdx,W_TH_INTERP);

    cnt_x = intpD.extractGrv_cnt(x);
    max_x = intpD.extractGrv_max(x);

    tmpPoints = [x*ones(pksNum,1), cnt_x];
    tmpPoints = 1+(tmpPoints-1)*step;
    pts_cnt_intp.pksCell{x} = tmpPoints;
    pts_max_intp.pksCell{x} = [x*ones(pksNum,1), max_x];
end

sIdxs_intp = vertcat(sIdxC_intp{:});
eIdxs_intp = vertcat(eIdxC_intp{:});
pks_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});
pks_max_intp = vertcat(pts_max_intp.pksCell{:});



%%
fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
origImg.showImg();
hold on;
scatter(pks_cnt(:,1),pks_cnt(:,2),3,'filled');
scatter(pks_cnt_r(:,1),pks_cnt_r(:,2),3,'filled');
scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),3,'filled');

title("Peak Dots (centroid method)");
legend(["not resampled","resampled","interpolated"]);
lgd = legend; lgd.ItemHitFcn=@togglevisibility;
