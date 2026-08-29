% grooveBtmOnImage.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig1_2_grooveBtmOnImage.mと同じデータ・処理を使い、
% 100x100pxの画像上に検出した溝底点(centroid法)を重ねる
% 同じ溝底点を暗度の3次元表示に重ねたものはgrooveBtmOn3d.m
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （タイトル無し、pngのみ保存）
%
% axis("image")で正方形の画像を等倍表示するため、他のスライド用の図と違い
% キャンバスは正方形(FIG_W=FIG_H)にする

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "grooveBtmOnImage";

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";
PIXELS = 100;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 81;   % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

% grooveBtmOn3d.mで表示している範囲。矩形で示す
Y_VIEW = [1 40]; % 溝を横切る方向
X_VIEW = [1 10]; % 溝に平行な方向

% 図のサイズ[cm]とフォントサイズ[pt]（axis imageのため正方形キャンバスにする）
FIG_W = 9; FIG_H = 9;
FONT_TICK = 14; FONT_LABEL = 16;

MARKER_SIZE = 10;

%% 画像を読み込み、溝底点を検出する
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessMap(imgData);
origD = origD.setDiffTF(D_TH);

pts = GroovePointCloud(origD);
pts_max = GroovePointCloud(origD);
extractor = GrooveExtractor(origD);
for x = 1:imgData.width
    [firstIdx,lastIdx] = extractor.findThresholdIntervals(origD,x);
    [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_TH);
    pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(origD,x)];
    pts_max.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByLocalMax(origD,x)];
end

ptsXY = vertcat(pts.peakCells{:});
ptsX = ptsXY(:,1); ptsY = ptsXY(:,2);

ptsXY_max = vertcat(pts_max.peakCells{:});
ptsX_max = ptsXY_max(:,1); ptsY_max = ptsXY_max(:,2);


%% 描画(重心法)
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,ptsX,ptsY,MARKER_SIZE,"cyan","filled","o");
% grooveBtmOn3d.mで表示している範囲を矩形で示す
rectangle(ax,"Position",[X_VIEW(1) Y_VIEW(1) diff(X_VIEW) diff(Y_VIEW)], ...
    "EdgeColor","red","LineWidth",1.5);
hold(ax,"off");

% スライド用にタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top")
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存
saveSlideFigure(fig,saveDir,figName,FIG_W,FIG_H);

%% 描画(最大値法)
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,ptsX_max,ptsY_max,MARKER_SIZE,"cyan","filled","o");
% grooveBtmOn3d.mで表示している範囲を矩形で示す
% rectangle(ax,"Position",[X_VIEW(1) Y_VIEW(1) diff(X_VIEW) diff(Y_VIEW)], ...
    % "EdgeColor","red","LineWidth",1.5);
hold(ax,"off");

% スライド用にタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top")
xlabel(ax,"$x$"); ylabel(ax,"$y$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

saveSlideFigure(fig,saveDir,figName+"_localMax",FIG_W,FIG_H);

