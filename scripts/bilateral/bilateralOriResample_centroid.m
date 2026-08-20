% bilateralOriResample_centroid.m
% 高解像度化を行っていない画像(*-ori.png)にバイラテラルフィルタをかけ、そのあと
% 暗度の1次元リサンプル(dResample)を行い、重心法で溝底点を抽出して画像上に表示する。
%
% bilateralOri_centroid.mとの違いはDarknessMapをdResample(map,8,1)で
% 8倍にしてから閾値処理・重心法にかける点だけ。フィルタで画素値のノイズを
% 落としてからリサンプルすると、リサンプル後の暗度カーブ（＝溝底の重心位置）が
% どれだけ安定するかを見るのが目的。
%
% 溝底のy座標はextractByCentroid内で (idx-1)/scaleFactor.row + 1 により
% 元画像座標へ戻されるので、リサンプル前の画像にそのまま重ねられる。
% dResampleは列数を変えない（scaleFactor.colは1のまま）のでxの戻しは不要。
%
% 出力（results/0820/bilateral/oriRsmpl/）:
%   oriRsmpl_filtered_k<NN>.png  フィルタ後の画像そのもの
%   oriRsmpl_ptsFull_<cond>.png  セグメント全体に溝底点を重ねた図
%   oriRsmpl_ptsView_<cond>.png  拡大範囲に溝底点を重ねた図
%   oriRsmpl_compare.png/.fig    4条件（フィルタなし＋3通り）の比較図

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
IMG_INDEX = 8;      % DSC1111-00008-ori.png
J_SEGMENT = 5;      % 10分割したうちの何枚目か（中央付近＝マスクの影響が小さい）
NUM_SEGMENTS = 10;  % 細長い画像を10等分する

L_MASK = 20;      % Maskを取るためのluminanceのthreshold
D_THRESH = 0.6;   % 暗度の閾値
W_TH = 8;         % 溝底とみなす区間幅の上限[px]（元画像座標。内部でscaleFactor.rowが掛かる）

% 暗度の1次元リサンプル
P_RSMPL = 8; Q_RSMPL = 1;

% バイラテラルフィルタ
KERNEL_SIZES = [3 5 9];               % NeighborhoodSize（3通り、奇数）
SPATIAL_SIGMAS = (KERNEL_SIZES-1)/4;  % 既定 N=2*ceil(2*sigma)+1 の逆算 -> [0.5 1 2]
DEGREE_OF_SMOOTHING = 0.01*255^2;     % uint8入力に対するimbilatfiltの既定値と同値

% 表示用の拡大範囲（omitMask後のセグメント座標）
VIEW_ROWS = 101:200;
VIEW_COLS = 81:180;

MARKER_SIZE = 5;

% 保存先
saveDir = fullfile(mkdirFromDate(rootFolder,"0820"),"bilateral","oriRsmpl");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
TAG = "oriRsmpl";

%% 画像の読み込みと分割（img_small）
imgPath = fullfile(rootFolder,"data","pictures","1111","original", ...
    "DSC1111-0000"+num2str(IMG_INDEX)+"-ori.png");
img_gray = rgb2gray(imread(imgPath));

[~,width] = size(img_gray);
divWidth = round(width / NUM_SEGMENTS);
xarray = [1:divWidth:width width+1]';
img_small = img_gray(:, xarray(J_SEGMENT):xarray(J_SEGMENT+1)-1);

[img_omitMask,~] = omitMask(img_small, L_MASK);

% 拡大範囲が画像からはみ出さないようにする
viewRows = VIEW_ROWS(VIEW_ROWS <= size(img_omitMask,1));
viewCols = VIEW_COLS(VIEW_COLS <= size(img_omitMask,2));

%% 各条件でフィルタ→リサンプル→溝底点の抽出
numConds = numel(KERNEL_SIZES) + 1; % フィルタなし＋カーネル3通り
condLabels = strings(numConds,1);
condTitles = strings(numConds,1);
condImgs = cell(numConds,1);
condPks = cell(numConds,1);

for iCond = 1:numConds
    if iCond == 1
        img_cond = img_omitMask;
        condLabels(iCond) = "none";
        condTitles(iCond) = "no filter";
    else
        kSize = KERNEL_SIZES(iCond-1);
        img_cond = imbilatfilt(img_omitMask, DEGREE_OF_SMOOTHING, ...
            SPATIAL_SIGMAS(iCond-1), 'NeighborhoodSize', kSize);
        condLabels(iCond) = "k" + sprintf("%02d",kSize);
        condTitles(iCond) = "kernel $" + kSize + "\times" + kSize + "$";
        imwrite(img_cond, fullfile(saveDir, TAG+"_filtered_"+condLabels(iCond)+".png"));
    end

    imgData = ImageData(img_cond, [IMG_INDEX; J_SEGMENT]);

    map = DarknessMap(imgData);
    map = dResample(map, P_RSMPL, Q_RSMPL);
    map = map.setDiffTF(D_THRESH);

    condImgs{iCond} = img_cond;
    condPks{iCond} = detectCentroidPoints(map, W_TH);

    fprintf("%-10s : %6d points\n", condLabels(iCond), size(condPks{iCond},1));
end

%% 条件ごとの図（セグメント全体・拡大範囲）
for iCond = 1:numConds
    figFull = createFigure([0 0 12 6]);
    axFull = axes(figFull); %#ok<LAXES>
    showPointsOnImage(axFull, condImgs{iCond}, condPks{iCond}, ...
        condTitles(iCond), MARKER_SIZE);
    exportgraphics(figFull, ...
        fullfile(saveDir, TAG+"_ptsFull_"+condLabels(iCond)+".png"), ...
        "Resolution",300,"BackgroundColor","white");

    [imgView, pksView] = cropView(condImgs{iCond}, condPks{iCond}, viewRows, viewCols);
    figView = createFigure([0 0 6 6]);
    axView = axes(figView); %#ok<LAXES>
    showPointsOnImage(axView, imgView, pksView, condTitles(iCond), MARKER_SIZE);
    exportgraphics(figView, ...
        fullfile(saveDir, TAG+"_ptsView_"+condLabels(iCond)+".png"), ...
        "Resolution",300,"BackgroundColor","white");
end

%% 4条件の比較図（拡大範囲）
figCmp = createFigure([0 0 12 12]);
tl = tiledlayout(figCmp,2,2,"TileSpacing","compact","Padding","tight");
for iCond = 1:numConds
    [imgView, pksView] = cropView(condImgs{iCond}, condPks{iCond}, viewRows, viewCols);
    ax = nexttile(tl);
    showPointsOnImage(ax, imgView, pksView, condTitles(iCond), MARKER_SIZE);
end
title(tl,"bilateral filter + "+P_RSMPL+"x resampled darkness");
exportgraphics(figCmp, fullfile(saveDir, TAG+"_compare.png"), ...
    "Resolution",300,"BackgroundColor","white");
savefig(figCmp, fullfile(saveDir, TAG+"_compare.fig"));

%% ローカル関数
function pks = detectCentroidPoints(map, widthThresh)
% 重心法で溝底点を抽出し、[x y]のNx2行列（元画像座標）で返す。
% CLAUDE.mdのGrooveExtractor呼び出しイディオムに準拠。
    pts = GroovePointCloud(map);
    extractor = GrooveExtractor(map);
    for x = 1:map.nCols
        [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
        [extractor,~,~,numPeaks] = ...
            extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,widthThresh);
        pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(map,x)];
    end
    pks = vertcat(pts.peakCells{:});
end

function [imgView, pksView] = cropView(img, pks, viewRows, viewCols)
% 拡大範囲を切り出し、その範囲に入る点の座標を切り出し後の原点に合わせる。
    imgView = img(viewRows, viewCols);
    inView = pks(:,1) >= viewCols(1) & pks(:,1) <= viewCols(end) & ...
        pks(:,2) >= viewRows(1) & pks(:,2) <= viewRows(end);
    pksView = pks(inView,:) - [viewCols(1)-1, viewRows(1)-1];
end

function showPointsOnImage(ax, img, pks, titleStr, markerSize)
% ImageData.showImageはaxesを指定できずXAxisLocationを上に固定するため、
% paper/202609asjの図と同様にimagescで描く。titleと重ならないようx軸は下に置く。
    imagesc(ax, img);
    colormap(ax, gray);
    clim(ax, [0 255]);
    axis(ax, "image");
    hold(ax, "on");
    scatter(ax, pks(:,1), pks(:,2), markerSize, "cyan", "filled", "o");
    hold(ax, "off");
    set(ax, "YDir","reverse", "TickDir","out");
    xlabel(ax, "$x$"); ylabel(ax, "$y$");
    title(ax, titleStr);
end
