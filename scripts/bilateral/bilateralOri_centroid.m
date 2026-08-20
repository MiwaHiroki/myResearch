% bilateralOri_centroid.m
% 高解像度化を行っていない画像(*-ori.png)にバイラテラルフィルタをかけ、
% 重心法で溝底点を抽出して画像上に表示する検討用スクリプト。
%
% 本プロジェクトは従来、画像そのものには前処理をかけず（omitMaskによる左右の
% マスク除去のみ）、暗度dMat側を高解像度化して溝底を取ってきた。ここでは
% 「画像を平滑化すると溝底点の検出がどう変わるか」を1セグメントで目視確認する。
% エッジ（溝の壁）を保ったままノイズが落ちれば閾値交差の区間が安定し、重心法の
% y座標のばらつきが減るはずで、逆にカーネルが大きすぎれば溝底が潰れる。
% その境目をカーネルサイズ3通りで見るのが目的。
%
% フィルタはomitMaskの後にかける。マスクの黒（輝度<=L_MASK）を平滑化に
% 巻き込まないため。imbilatfiltはuint8のまま返すので、後段の
% ImageData(double化) -> DarknessMap(dMat = 1 - img/255) の流れは変わらない。
%
% 出力（results/0820/bilateral/ori/）:
%   ori_filtered_k<NN>.png  フィルタ後の画像そのもの
%   ori_ptsFull_<cond>.png  セグメント全体に溝底点を重ねた図
%   ori_ptsView_<cond>.png  拡大範囲に溝底点を重ねた図
%   ori_compare.png/.fig    4条件（フィルタなし＋3通り）の比較図

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
IMG_INDEX = 8;      % DSC1111-00008-ori.png
J_SEGMENT = 5;      % 10分割したうちの何枚目か（中央付近＝マスクの影響が小さい）
NUM_SEGMENTS = 10;  % 細長い画像を10等分する

L_MASK = 20;      % Maskを取るためのluminanceのthreshold
D_THRESH = 0.6;   % 暗度の閾値
W_TH = 8;         % 溝底とみなす区間幅の上限[px]

% バイラテラルフィルタ
KERNEL_SIZES = [3 5 9];               % NeighborhoodSize（3通り、奇数）
SPATIAL_SIGMAS = (KERNEL_SIZES-1)/4;  % 既定 N=2*ceil(2*sigma)+1 の逆算 -> [0.5 1 2]
DEGREE_OF_SMOOTHING = 0.01*255^2;     % uint8入力に対するimbilatfiltの既定値と同値

% 表示用の拡大範囲（omitMask後のセグメント座標）
VIEW_ROWS = 101:200;
VIEW_COLS = 81:180;

MARKER_SIZE = 5;

% 保存先
saveDir = fullfile(mkdirFromDate(rootFolder,"0820"),"bilateral","ori");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
TAG = "ori";

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

%% 各条件でフィルタ→溝底点の抽出
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
title(tl,"bilateral filter on the original image");
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
