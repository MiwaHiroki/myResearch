% interp2を使って疑似的な高解像度化を行う
% pkCentroidAndLocalMax_resample_1cycle.mをもとに作成
% 2026/07/01作成
% 形状抽出は重心法でやろうかな

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

iImg=1; % i=1~NUM_IMAGES
jSegment=1; % j=1~NUM_SEGMENTS


%%

% ------------------ここからローカルの"peak detection/"から持ってきたコード-------------------
% このセクションは実行しなくていい


% img_new = imread("./pictures/1111/original/" + filenames_new(9-i) + ".png");
img_new = imread(filenames_new(9-iImg) + ".png");
img_gray = rgb2gray(img_new);

[imgHeight,imgWidth] = size(img_gray);

divImgWidth = round(imgWidth / NUM_SEGMENTS);
xarray = [1:divImgWidth:imgWidth imgWidth+1]';

[img_omitMask,newWidth] = omitMask(img_gray, L_MASK);
imgData = ImageData(img_omitMask, [iImg;jSegment]);

dValue = DarknessMap(imgData);
dValue = setDiffTF(dValue, D_THRESH);
diffTF = dValue.diffTF;

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

WIDTH_THRESH = 5;
w_TH = WIDTH_THRESH / step;

extractor = GrooveExtractor(dValue);
for x=1:imgData.width
    [firstIdx, lastIdx] = extractor.findThresholdIntervals(dValue, x);
    [extractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
        extractor.findGrooveBottomIntervals(dValue,x,firstIdx,lastIdx,WIDTH_THRESH);
    % btmFirstIdx, btmLastIdx, numPeaksは今後不要になる予定

    centroidY = extractor.extractByCentroid(dValue,x);
    maxY = extractor.extractByLocalMax(dValue,x);

    pts_centroid.pksCell{x} = [x*ones(numPeaks,1), centroidY];
    pts_localMax.pksCell{x} = [x*ones(numPeaks,1), maxY];
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
% --------------------ここまで----------------------------------------------

%%

img_new = imread(filenames_new(9-iImg) + ".png");
img_gray = rgb2gray(img_new);

[height,width] = size(img_gray);

divWidth = round(width / NUM_SEGMENTS);
xarray = [1:divWidth:width width+1]';
img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

[img_omitMask,newWidth] = omitMask(img_small, L_MASK);
origImg = ImageData(img_omitMask, [iImg;jSegment]);
origWidth = origImg.width; origHeight = origImg.height;

origD = DarknessMap(origImg);
origD = origD.setDiffTF(D_THRESH);


% MUST AVOID THIS: INTERPOLATING IMAGE
% img_interp2 = interp2(xx,yy,origImg.img,x_q,y_q,INTERP_METHOD);
% intpImg = ImageData(img_interp2,[iImg,jSegment]);
% intpWidth = intpImg.width; intpHeight = intpImg.height;

% dMat_interp = interp2(xx,yy,dMat,x_q,y_q,INTERP_METHOD);
% intpWidth = size(dMat_interp,2);


% ------intpDの設定--------
step = 0.125;
INTERP_METHOD = "spline"; % method for interpolation
intpD = dInterp(origD,step,INTERP_METHOD);
intpD = intpD.setDiffTF(D_THRESH);



p_rsmpl = 8; q_rsmpl = 1;
rsmplD = dResample(origD,8,1);
rsmplD = rsmplD.setDiffTF(D_THRESH);




% % cells in which startIdx and endIdx are recorded.
% % for original img
% sIdxC = cell(1, origD.nCols);
% eIdxC = cell(1, origD.nCols);
% % for resampled img
% sIdxC_rsmpl = cell(1, rsmplD.nCols);
% eIdxC_rsmpl = cell(1, rsmplD.nCols);
% % for interpolated img
% sIdxC_intp = cell(1, intpD.nCols);
% eIdxC_intp = cell(1, intpD.nCols);

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


WIDTH_THRESH = 8;

origExtractor = GrooveExtractor(origD);
rsmplExtractor = GrooveExtractor(rsmplD);
for x=1:origImg.width
    [firstIdx, lastIdx] = origExtractor.findThresholdIntervals(origD, x);
    [origExtractor,~,~,numPeaks] = ...
        origExtractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,WIDTH_THRESH);
    % btmFirstIdx, btmLastIdx, numPeaksは今後不要になる予定

    centroidY = origExtractor.extractByCentroid(origD,x);
    maxY = origExtractor.extractByLocalMax(origD,x);

    pts_cnt.pksCell{x} = [x*ones(numPeaks,1), centroidY];
    pts_max.pksCell{x} = [x*ones(numPeaks,1), maxY];


    [firstIdx, lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD, x);
    [rsmplExtractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
        rsmplExtractor.findGrooveBottomIntervals(rsmplD, x, firstIdx, lastIdx, WIDTH_THRESH);

    centroidY = rsmplExtractor.extractByCentroid(rsmplD,x);
    maxY = rsmplExtractor.extractByLocalMax(rsmplD,x);

    pts_cnt_r.pksCell{x} = [x*ones(numPeaks,1), centroidY];
    pts_max_r.pksCell{x} = [x*ones(numPeaks,1), maxY];

end

sIdxs = vertcat(origExtractor.startIdxCells{:});
eIdxs = vertcat(origExtractor.endIdxCells{:});
pks_cnt = vertcat(pts_cnt.pksCell{:});
pks_max = vertcat(pts_max.pksCell{:});

pks_cnt_r = vertcat(pts_cnt_r.pksCell{:});
pks_max_r = vertcat(pts_max_r.pksCell{:});

intpExtractor = GrooveExtractor(intpD);
for x=1:intpD.nCols
    [firstIdx, lastIdx] = intpExtractor.findThresholdIntervals(intpD, x);
    [intpExtractor, btmFirstIdx, btmLastIdx, numPeaks] = ...
        intpExtractor.findGrooveBottomIntervals(intpD,x,firstIdx,lastIdx,WIDTH_THRESH);

    centroidY = intpExtractor.extractByCentroid(intpD,x);
    maxY = intpExtractor.extractByLocalMax(intpD,x);

    tmpPoints = [x*ones(numPeaks,1), centroidY];
    tmpPoints(:,1) = 1+(tmpPoints(:,1) - 1)*step;
    pts_cnt_intp.pksCell{x} = tmpPoints;

    tmpPoints = [x*ones(numPeaks,1), maxY];
    tmpPoints(:,1) = 1+(tmpPoints(:,1) - 1)*step;
    pts_max_intp.pksCell{x} = tmpPoints;

end

sIdxs_intp = vertcat(intpExtractor.startIdxCells{:});
eIdxs_intp = vertcat(intpExtractor.endIdxCells{:});
pks_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});
pks_max_intp = vertcat(pts_max_intp.pksCell{:});

%}

%%
% 結果の確認
fig = createFigure([0 0 10 10]);
% figure;
origImg.showImg("fit");
ax=gca;
% imshow(uint8(origImg.img), "InitialMagnification","fit");
hold on;
pts_cnt.showCandidates("cyan");
pts_cnt_r.showCandidates("magenta");
pts_cnt_intp.showCandidates("yellow");
% set(gca,'YDir','reverse','TickDir','out');
% set(gca,"XAxisLocation","top");
% xlabel("$x$");ylabel("$y$");
title("Peak Dots (mute section)");
% xticks(1:100:origImg.width);yticks(1:100:origImg.height);


legend(["original","resampled","interpolated ("+INTERP_METHOD+")"]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

% saveas(gcf,saveDir+"PkDots(muteSection)(orig,rsmpl,intp("+INTERP_METHOD+")).fig");

%%
MARKER_SIZE = 5;


% original data
p2_cnt = [0;0];

fig = figure;
% fig = createFigure([0 0 6 6]);
% origImg.showImg();
origImg.showImg("fit")
hold on;
scatter(pks_cnt(:,1),pks_cnt(:,2),MARKER_SIZE,'c','filled');
title("Peak Dots (centroid method)");
% pks_cntの傾きを補正したpks_cnt_corを得る
[p1_cnt,p2_cnt,pksCorCell] = fitGroove(jSegment,fig,p2_cnt,W_PRL,H_PRL,{pks_cnt});
pks_cnt_cor = pksCorCell{1};

BIN_WIDTH = 2; % BinWidth
[counts,edges] = histcounts(pks_cnt_cor(:,2),'BinWidth',BIN_WIDTH);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

[~,idx_hist] = min(abs(p1_cnt(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));

TOL_DISTANCE = 4;
% そのピークの中心からTOL_DISTANCE(pixel)以内にあるy座標
y_min = groove1Center - TOL_DISTANCE;
y_max = groove1Center + TOL_DISTANCE;

% f=figure; barh(centers,counts);
% set(gca,'YDir','reverse','xAxisLocation','top');box on
% % xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
% hold on;
% yline(y_min);yline(y_max);
% hold off;

points = [(1:origD.nCols)',NaN(origD.nCols,1)];

idxs = (pks_cnt_cor(:,2) >= y_min) & (pks_cnt_cor(:,2)<=y_max);
points(pks_cnt_cor(idxs,1),2) = pks_cnt_cor(idxs,2);

% 形状抽出に失敗した点を埋める
% 波形表示時の各信号の長さを揃えるため
points(:,2) = fillmissing(points(:,2),"linear");

points_fit = points;

p = polyfit(points(:,1),points(:,2),3);
points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

points_orig = points_fit;


% resampled data
p2_cnt = [0;0];

fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
origImg.showImg();
hold on;
scatter(pks_cnt_r(:,1),pks_cnt_r(:,2),MARKER_SIZE,'c','filled');
title("Peak Dots (centroid method)");
% pks_cntの傾きを補正したpks_cnt_corを得る
[p1_cnt,p2_cnt,pksCorCell] = fitGroove(jSegment,fig,p2_cnt,W_PRL,H_PRL,{pks_cnt_r});
pks_cnt_cor = pksCorCell{1};

BIN_WIDTH = 2; % BinWidth
[counts,edges] = histcounts(pks_cnt_cor(:,2),'BinWidth',BIN_WIDTH);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

[~,idx_hist] = min(abs(p1_cnt(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));

TOL_DISTANCE = 4;
% そのピークの中心からTOL_DISTANCE(pixel)以内にあるy座標
y_min = groove1Center - TOL_DISTANCE;
y_max = groove1Center + TOL_DISTANCE;

% f=figure; barh(centers,counts);
% set(gca,'YDir','reverse','xAxisLocation','top');box on
% % xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
% hold on;
% yline(y_min);yline(y_max);
% hold off;

points = [(1:origD.nCols)',NaN(origD.nCols,1)];

idxs = (pks_cnt_cor(:,2) >= y_min) & (pks_cnt_cor(:,2)<=y_max);
points(pks_cnt_cor(idxs,1),2) = pks_cnt_cor(idxs,2);

% 形状抽出に失敗した点を埋める
% 波形表示時の各信号の長さを揃えるため
points(:,2) = fillmissing(points(:,2),"linear");

points_fit = points;

p = polyfit(points(:,1),points(:,2),3);
points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

points_rsmpl = points_fit;


% interpolated data
p2_cnt = [0;0];

fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
origImg.showImg();
hold on;
pts_cnt_intp.showCandidates();
title("Peak Dots (centroid method)");
[p1_cnt,p2_cnt,pksCorCell] = fitGroove(jSegment,fig,p2_cnt,W_PRL,H_PRL,{pks_cnt_intp});
pks_cnt_cor = pksCorCell{1};

BIN_WIDTH = 2; % BinWidth
[counts,edges] = histcounts(pks_cnt_cor(:,2),'BinWidth',BIN_WIDTH);
centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

[~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST/step);

[~,idx_hist] = min(abs(p1_cnt(2) - centers(histPkLocs)));
groove1Center = centers(histPkLocs(idx_hist));

TOL_DISTANCE = 4;
% そのピークの中心からTOL_DISTANCE(pixel)以内にあるy座標
y_min = groove1Center - TOL_DISTANCE;
y_max = groove1Center + TOL_DISTANCE;

% f=figure; barh(centers,counts);
% set(gca,'YDir','reverse','xAxisLocation','top');box on
% % xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
% hold on;
% yline(y_min);yline(y_max);
% hold off;

points = [(1:intpD.nCols)',NaN(intpD.nCols,1)];

idxs = find((pks_cnt_cor(:,2) >= y_min) & (pks_cnt_cor(:,2)<=y_max));
points(:,1) = pks_cnt_cor(idxs,1);
points(:,2) = pks_cnt_cor(idxs,2);
% idxs = (pks_cnt_cor(:,2) >= y_min) & (pks_cnt_cor(:,2)<=y_max);
% points(pks_cnt_cor(idxs,1),2) = pks_cnt_cor(idxs,2);


% 形状抽出に失敗した点を埋める
% 波形表示時の各信号の長さを揃えるため
% points(:,2) = fillmissing(points(:,2),"linear");

points_fit = points;

p = polyfit(points(:,1),points(:,2),3);
points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

points_intp = points_fit;

%%
figure;hold on;
plot(points_orig(:,1),points_orig(:,2));
plot(points_rsmpl(:,1),points_rsmpl(:,2));
plot(points_intp(:,1),points_intp(:,2));
title("Groove Bottom Data");
xlabel("$x$");ylabel("$y$");
legend(["original","resampled","interpolated ("+INTERP_METHOD+")"]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

saveas(gcf,saveDir+"grooveCoords(muteSection)(orig,rsmpl,intp("+INTERP_METHOD+")).fig");

%%



