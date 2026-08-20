% bilateral8x_centroid.m
% Photoshopで8xに高解像度化した画像(*-8x.png)にバイラテラルフィルタをかけ、
% 重心法で溝底点を抽出して画像上に表示する検討用スクリプト。
%
% 画像側が既に高解像度化されているので、DarknessMap側のdResample/dInterpによる
% 再アップサンプリングは行わない（scaleFactorは1のまま）。高解像度化で持ち込まれた
% 補間ノイズ・階調の段差が平滑化でどう変わるかを見るのが目的。
%
% 切り出しについて: *-8x.pngは30000x3736pxあり、1/10セグメントでも
% 3736x3000px = 11Mpxになる。大きなカーネルのimbilatfiltが現実的な時間で
% 終わらないため、元画像座標で指定した窓（ORI_ROWS/ORI_COLS、既定200x200px）に
% 対応する8x側の領域だけを切り出して処理する。窓はセグメント内の相対位置で指定する。
% 対応付けは scripts/progress/showPhotoshopGrooveExtraction.m と同じ
% 「(idx-1)*scale+1」。縦は8倍ちょうどだが横は 30000/4005 = 7.49倍で倍率が違う。
%
% omitMaskはかけない。切り出す窓はセグメント内部でマスク（左右の無効領域）を
% 含まないため。フィルタがマスクの黒を巻き込まない点は他の2本と同じ。
%
% 出力（results/0820/bilateral/photoshop8x/）:
%   photoshop8x_filtered_k<NN>.png  フィルタ後の画像そのもの
%   photoshop8x_ptsFull_<cond>.png  切り出した領域全体に溝底点を重ねた図
%   photoshop8x_ptsView_<cond>.png  さらに拡大した範囲に溝底点を重ねた図
%   photoshop8x_compare.png/.fig    4条件（フィルタなし＋3通り）の比較図

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
IMG_INDEX = 8;      % DSC1111-00008-8x.png
J_SEGMENT = 5;      % 10分割したうちの何枚目か（中央付近＝マスクの影響が小さい）
NUM_SEGMENTS = 10;  % 細長い画像を10等分する

% 処理する窓（元画像座標。行は画像全体、列はセグメント先頭からのオフセット）
ORI_ROWS = 101:300;
ORI_COLS = 101:300;

D_THRESH = 0.6;   % 暗度の閾値
W_TH_8X = 64;     % 溝底とみなす区間幅の上限[px]。8x画像上の画素で直接指定する
                  % （元画像の8px相当。scaleFactor.rowは1のまま）

% バイラテラルフィルタ（8x画素で効くので元画像より大きめに取る）
% 元画像の[3 5 9]と厳密に揃えるなら 8*[3 5 9]+1 = [25 41 73] だが、73は計算が重い
KERNEL_SIZES = [9 17 25];             % NeighborhoodSize（3通り、奇数）
SPATIAL_SIGMAS = (KERNEL_SIZES-1)/4;  % 既定 N=2*ceil(2*sigma)+1 の逆算 -> [2 4 6]
DEGREE_OF_SMOOTHING = 0.01*255^2;     % uint8入力に対するimbilatfiltの既定値と同値

% 表示用の拡大範囲（切り出した8x領域の中での座標）
VIEW_ROWS = 1:800;
VIEW_COLS = 1:800;

MARKER_SIZE = 5;

% 保存先
saveDir = fullfile(mkdirFromDate(rootFolder,"0820"),"bilateral","photoshop8x");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
TAG = "photoshop8x";

%% 画像の読み込みと切り出し
oriInfo = imfinfo(fullfile(rootFolder,"data","pictures","1111","original", ...
    "DSC1111-0000"+num2str(IMG_INDEX)+"-ori.png"));
hOri = oriInfo.Height; wOri = oriInfo.Width;

x8Path = fullfile(rootFolder,"data","pictures","1111","8x", ...
    "DSC1111-0000"+num2str(IMG_INDEX)+"-8x.png");
img8x_gray = rgb2gray(imread(x8Path));
[h8x,w8x] = size(img8x_gray);

rowScale = h8x/hOri; % 縦（溝を横切る方向）の拡大率
colScale = w8x/wOri; % 横（溝に平行な方向）の拡大率

% 元画像座標での窓（列はJ_SEGMENT番目のセグメント先頭からのオフセット）
divWidth = round(wOri / NUM_SEGMENTS);
xarray = [1:divWidth:wOri wOri+1]';
segFirstCol = xarray(J_SEGMENT);

oriRows = ORI_ROWS;
oriCols = segFirstCol + ORI_COLS - 1;

% 対応する8x画像上の範囲
rows8x = (round((oriRows(1)-1)*rowScale)+1) : (round((oriRows(end)-1)*rowScale)+1);
cols8x = (round((oriCols(1)-1)*colScale)+1) : (round((oriCols(end)-1)*colScale)+1);

img_crop = img8x_gray(rows8x, cols8x);
clear img8x_gray % 30000x3736pxを保持し続けない

fprintf("8x crop: %d x %d px\n", size(img_crop,1), size(img_crop,2));

% 拡大範囲が切り出した画像からはみ出さないようにする
viewRows = VIEW_ROWS(VIEW_ROWS <= size(img_crop,1));
viewCols = VIEW_COLS(VIEW_COLS <= size(img_crop,2));

%% 各条件でフィルタ→溝底点の抽出
numConds = numel(KERNEL_SIZES) + 1; % フィルタなし＋カーネル3通り
condLabels = strings(numConds,1);
condTitles = strings(numConds,1);
condImgs = cell(numConds,1);
condPks = cell(numConds,1);

for iCond = 1:numConds
    if iCond == 1
        img_cond = img_crop;
        condLabels(iCond) = "none";
        condTitles(iCond) = "no filter";
    else
        kSize = KERNEL_SIZES(iCond-1);
        img_cond = imbilatfilt(img_crop, DEGREE_OF_SMOOTHING, ...
            SPATIAL_SIGMAS(iCond-1), 'NeighborhoodSize', kSize);
        condLabels(iCond) = "k" + sprintf("%02d",kSize);
        condTitles(iCond) = "kernel $" + kSize + "\times" + kSize + "$";
        imwrite(img_cond, fullfile(saveDir, TAG+"_filtered_"+condLabels(iCond)+".png"));
    end

    imgData = ImageData(img_cond, [IMG_INDEX; J_SEGMENT]);

    map = DarknessMap(imgData);
    map = map.setDiffTF(D_THRESH);

    condImgs{iCond} = img_cond;
    condPks{iCond} = detectCentroidPoints(map, W_TH_8X);

    fprintf("%-10s : %6d points\n", condLabels(iCond), size(condPks{iCond},1));
end

%% 条件ごとの図（切り出し領域全体・拡大範囲）
for iCond = 1:numConds
    figFull = createFigure([0 0 8 8]);
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
title(tl,"bilateral filter on the Photoshop 8x image");
exportgraphics(figCmp, fullfile(saveDir, TAG+"_compare.png"), ...
    "Resolution",300,"BackgroundColor","white");
savefig(figCmp, fullfile(saveDir, TAG+"_compare.fig"));

%% ローカル関数
function pks = detectCentroidPoints(map, widthThresh)
% 重心法で溝底点を抽出し、[x y]のNx2行列（画像座標）で返す。
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
