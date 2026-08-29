% photoshopNoise.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/archive/noiseDetail.mの後半（DSC1111-00007を使う部分）を、
% 現行のDarknessMap/GrooveExtractorパイプラインで書き直したもの。
% 既製の画像編集ソフト(Photoshop)による8倍高解像度化が生む、溝底検出のノイズ
% （不安定な検出点）を、元画像(1x)と高解像度化後(8x)の対比で示す
%
% noiseDetail.mのfindpeaksベースの閾値(minh/maxh/mind/max_prd)は現行の
% findGrooveBottomIntervals(D_TH,W_TH)ベースの抽出とは対応しないため使用しない。
% 溝底点抽出は8x画像に対して局所的最大値法を用いる
%
% 画像は8x/originalの2つの異なるフォルダから同時に読むため、他のスクリプトの
% 「bareファイル名＋カレントフォルダ依存」の慣習ではなく、proj.RootFolderから
% フルパスを組み立てる

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
IMG_8X_FILE = fullfile(proj.RootFolder,"data","pictures","1111","8x","DSC1111-00007-8x.png");
IMG_1X_FILE = fullfile(proj.RootFolder,"data","pictures","1111","original","DSC1111-00007-ori.png");

% 高解像度化された画像の参照範囲（元スクリプト指定のまま）
Y_RANGE_8X = 1001:2000;
X_RANGE_8X = 15001:16000;

% 元画像の参照範囲（元スクリプト指定のまま）
Y_RANGE_1X = 186:217;
X_RANGE_1X = 2005:2036;

D_TH = 0.6; % 暗度の閾値（fig1_1/fig1_2等と同じ。8xでも暗度のコントラストは変わらない）
% 溝底とみなす区間幅の上限[px]。origD用のW_TH=8を8xアップサンプル分だけ8倍にした値
% （下限フィルタは付けない＝Photoshopが生むノイズをそのまま図に出す）。
% 参考: scripts/photoshop_centroid_1cycle.mの二重閾値はW_MIN=8, W_MAX=65[px]
W_TH = 64;

% ズーム領域（元スクリプト指定のまま）
h = 250;
w = 250;
xs = 1;
ys = 481;

% 図のサイズ[cm]とフォントサイズ[pt]（axis imageのため正方形キャンバスにする）
FIG_W = 9; FIG_H = 9;
FONT_TICK = 14; FONT_LABEL = 16;

MARKER_SIZE = 4;

%% 画像を読み込み、8x画像で溝底点を検出する
imgUpsampledFull = rgb2gray(imread(IMG_8X_FILE));
imgUpsampled = imgUpsampledFull(Y_RANGE_8X,X_RANGE_8X);

imgOriginalFull = rgb2gray(imread(IMG_1X_FILE));
imgOriginalCrop = imgOriginalFull(Y_RANGE_1X,X_RANGE_1X);

imgData = ImageData(imgUpsampled,[1;1]);

map = DarknessMap(imgData);
map = map.setDiffTF(D_TH);

pts = GroovePointCloud(map);
extractor = GrooveExtractor(map);
for x = 1:imgData.width
    [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
    [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,W_TH);
    pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByLocalMax(map,x)];
end

ptsXY = vertcat(pts.peakCells{:});
ptsX = ptsXY(:,1); ptsY = ptsXY(:,2);

%% 描画1: 8x画像全体＋検出点＋ズーム領域の矩形
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgUpsampled);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,ptsX,ptsY,MARKER_SIZE,"cyan","filled","o");
rectangle(ax,"Position",[xs ys w h],"EdgeColor","red","LineWidth",1.5);
hold(ax,"off");

set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax);
saveSlideFigure(fig,saveDir,"photoshopNoise",FIG_W,FIG_H);

%% 描画2: 同じデータをズーム領域に拡大表示（検出点・矩形も表示）
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgUpsampled);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,ptsX,ptsY,MARKER_SIZE,"cyan","filled","o");
rectangle(ax,"Position",[xs ys w h],"EdgeColor","red","LineWidth",1.5);
hold(ax,"off");

xlim(ax,[xs xs+w-1]); ylim(ax,[ys ys+h-1]);
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax);
saveSlideFigure(fig,saveDir,"photoshopNoise_zoom",FIG_W,FIG_H);

%% 描画3: 同じズーム領域を検出点なしで表示（8x画像そのものの見た目）
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgUpsampled);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");

xlim(ax,[xs xs+w-1]); ylim(ax,[ys ys+h-1]);
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax);
saveSlideFigure(fig,saveDir,"photoshopNoise_8x",FIG_W,FIG_H);

%% 描画4: 対応する元画像(1x)の同位置の小領域（検出点なし）
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgOriginalCrop);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");

set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax);
saveSlideFigure(fig,saveDir,"photoshopNoise_1x",FIG_W,FIG_H);
