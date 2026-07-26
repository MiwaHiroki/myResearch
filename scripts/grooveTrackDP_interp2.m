% fitGroove()の手動平行四辺形選択の代替として、
% 候補点(pks)のグラフ上で最短経路探索(DP)を行い1本の溝を自動選択する。
% コストを水平方向(溝に沿う方向)より垂直方向(溝を横切る方向)に大きく設定することで、
% 隣接する溝への飛び移りやホコリ境界の誤検出点を避けることをねらう。
% まずはimg_small(1セグメント)に対する動作確認。
% 2026/07/26作成

%%
setDefaultIntrpr();

%%
proj = currentProject();
rootFolder = proj.RootFolder;

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する

filenames_new = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end

L_MASK = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
D_THRESH = 0.6;

iImg = 1; % i=1~NUM_IMAGES
jSegment = 1; % j=1~NUM_SEGMENTS

%%
% img_smallの切り出し

img_new = imread(fullfile(rootFolder,"data","pictures",filenames_new(9-iImg)+".png"));
img_gray = rgb2gray(img_new);

[height,width] = size(img_gray);

divWidth = round(width / NUM_SEGMENTS);
xarray = [1:divWidth:width width+1]';
img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

[img_omitMask,newWidth] = omitMask(img_small, L_MASK);
origImg = ImageData(img_omitMask, [iImg;jSegment]);
origWidth = origImg.width; origHeight = origImg.height;

origD = DarknessValue(origImg);
origD = origD.setDiffTF(D_THRESH);

%%
% interp2による疑似高解像度化と、centroid法による溝候補点(pks)の抽出

QUERY_STEP = 0.25;
INTERP_METHOD = "spline";
intpD = dInterp(origD,QUERY_STEP,INTERP_METHOD);
intpD = intpD.setDiffTF(D_THRESH);

pts_cnt_intp = GrooveCandidates(intpD);

W_TH = 8;

for x=1:intpD.nCols
    [startIdx, endIdx] = intpD.getStartEndIdx(x);
    [intpD, startIdx_btm, endIdx_btm, pksNum] = ...
        getGrooveBtmIdx(intpD,x,startIdx,endIdx,W_TH);

    cnt_x = intpD.extractGrv_cnt(x);

    tmpPoints = [x*ones(pksNum,1), cnt_x];
    tmpPoints(:,1) = 1+(tmpPoints(:,1)-1) * QUERY_STEP;
    pts_cnt_intp.pksCell{x} = tmpPoints;
end

pks_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});

%%
% 溝候補点の表示と、追跡の始点(p1)の手動選択
% p1はfitGroove()と同じく、img_small左端付近における溝のy座標を1点クリックするだけでよい

fig = figure;
origImg.showImg("fit");
hold on;
pts_cnt_intp.showCandidates();
title("Groove Candidates (centroid method, interpolated)");

p1 = ginput(1);

%%
% DPによる最短経路探索で1本の溝を選択する
% cost(j->i) = LAMBDA_X*(x_i-x_j) + LAMBDA_Y*(y_i-y_j)^2
% LAMBDA_Y > LAMBDA_X とすることで、垂直方向(溝を横切る方向)への移動を
% 水平方向(溝に沿う方向)への移動より高コストにする

LAMBDA_X = 1;   % 水平方向(溝に沿う方向)の移動コストの重み
LAMBDA_Y = 15;  % 垂直方向(溝を横切る方向)の移動コストの重み
MAX_GAP = 15;   % 遡って探索するx方向の最大距離[px]。ホコリ等の欠損区間を飛び越えられる幅の目安

[X_sorted, sortIdx] = sort(pks_cnt_intp(:,1));
Y_sorted = pks_cnt_intp(sortIdx,2);
nPts = length(X_sorted);

pathCost = inf(nPts,1);
prevNode = zeros(nPts,1); % 0は始点p1からの遷移を表す

x0 = 1; y0 = p1(2); % 始点(img_small左端、手動クリックしたy座標)

winStart = 1;
for i = 1:nPts
    while X_sorted(i) - X_sorted(winStart) > MAX_GAP
        winStart = winStart + 1;
    end

    bestCost = LAMBDA_X*(X_sorted(i)-x0) + LAMBDA_Y*(Y_sorted(i)-y0)^2;
    bestPrev = 0;

    for j = winStart:i-1
        if X_sorted(j) < X_sorted(i) && isfinite(pathCost(j))
            c = pathCost(j) + LAMBDA_X*(X_sorted(i)-X_sorted(j)) + LAMBDA_Y*(Y_sorted(i)-Y_sorted(j))^2;
            if c < bestCost
                bestCost = c;
                bestPrev = j;
            end
        end
    end

    pathCost(i) = bestCost;
    prevNode(i) = bestPrev;
end

lastX = max(X_sorted);
endCandidates = find(X_sorted == lastX);
[~,tmpI] = min(pathCost(endCandidates));
endNode = endCandidates(tmpI);

trackedIdx = zeros(nPts,1);
cnt = 0;
node = endNode;
while node ~= 0
    cnt = cnt+1;
    trackedIdx(cnt) = node;
    node = prevNode(node);
end
trackedIdx = flipud(trackedIdx(1:cnt));

trackedPts = [X_sorted(trackedIdx), Y_sorted(trackedIdx)];

%%
% 結果の確認

fig = figure;
origImg.showImg("fit");
hold on;
scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),5,'c','filled');
plot(trackedPts(:,1),trackedPts(:,2),'r-','LineWidth',1.5);
scatter(p1(1),p1(2),40,'y','filled','^');
title("Groove Tracking by DP (img\_small, LAMBDA\_X="+LAMBDA_X+", LAMBDA\_Y="+LAMBDA_Y+")");
legend(["candidates","tracked path","seed point p1"]);
