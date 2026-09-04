% grooveShape3d.m (スライド用)
% 音響学会2026年9月 スライド用
% grooveBtmOn3d.mが暗度Dを3D表示しているのに対し、こちらは音溝そのものの
% 物理形状を3D模式図として表示する。音溝の断面が実際にどんな形かは分からない
% ため、平坦面(land)・斜面(slope)・溝底(bottom)の3種類の平面のみで構成する。
% grooveBtmOn3d.mと並べて比較できるよう、軸範囲・視点・図サイズはgrooveBtmOn3d.m
% と同じ値を用いる。
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （タイトル無し、pngのみ保存）

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "grooveShape3d";

%% パラメータ（grooveBtmOn3d.mと同じ表示範囲・視点・図サイズ）
Y_VIEW = [1 40]; % 溝を横切る方向
X_VIEW = [1 10]; % 溝に平行な方向
Z_VIEW = [0 1];
AZ = 30; EL = 30; % 視点

FIG_W = 12; FIG_H = 8;
FONT_TICK = 14; FONT_LABEL = 16;

%% 断面プロファイルの定義
% y方向の区切り位置。区間ごとの意味は以下の通り（実データ・目視確認による）:
%   [ 1, 6]: 隣（前）の溝の斜面がview端で切れた部分（一つ前の溝底はview範囲外）
%   [ 6,14]: 平坦面(land)
%   [14,21]: 斜面(slope)
%   [21,24]: 溝底(bottom)。実データでのGrooveExtractor検出範囲(y=21-24)と一致させる
%   [24,31]: 斜面(slope)
%   [31,40]: 平坦面(land)
Y_BREAKS = [1 6 14 21 24 31 40];
SLOPE_WIDTH = 21 - 14; % 他の斜面区間と同じ傾き率をview端の途中の斜面にも適用する
Z_BREAKS = [1 - (6-1)/SLOPE_WIDTH, 1, 1, 0.2, 0.2, 1, 1]; % land=1(高い), 溝底=0.2(低い)
X_EXTENT = [1 10]; % 溝に平行な方向。模式図のため断面形状を一様に押し出す

% 断面プロファイルの各区間が属するカテゴリ（Y_BREAKSの6区間に対応）
SEGMENT_TYPES = ["slope","land","slope","bottom","slope","land"];
% 各カテゴリの色（輝度値0-1）。実測値ではなく、視覚的に区別しやすいよう明示指定する
CATEGORIES = ["land","slope","bottom"];
CATEGORY_GRAY = [0.15, 0.9, 0.55]; % land(暗い) < bottom(中間) < slope(明るい)

numSegments = numel(Y_BREAKS) - 1;
segColors = zeros(numSegments,3);
for i = 1:numSegments
    g = CATEGORY_GRAY(CATEGORIES == SEGMENT_TYPES(i));
    segColors(i,:) = [g g g];
end

%% 描画
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

hold(ax,"on");
surfHandles = gobjects(1,numSegments);
for i = 1:numSegments
    y0 = Y_BREAKS(i); y1 = Y_BREAKS(i+1);
    zSeg = [Z_BREAKS(i) Z_BREAKS(i+1); Z_BREAKS(i) Z_BREAKS(i+1)];
    surfHandles(i) = surface(ax,[y0 y1],X_EXTENT,zSeg,"FaceColor",segColors(i,:),"EdgeColor","k");
end
hold(ax,"off");

xlim(ax,Y_VIEW); ylim(ax,X_VIEW); zlim(ax,Z_VIEW);
view(ax,AZ,EL);

% land/slope/bottomの色対応を示すlegend（各カテゴリの最初の区間を代表に使う）
legendHandles = gobjects(1,numel(CATEGORIES));
for k = 1:numel(CATEGORIES)
    idx = find(SEGMENT_TYPES == CATEGORIES(k), 1);
    legendHandles(k) = surfHandles(idx);
end
lgd = legend(ax,legendHandles,CATEGORIES,Location="southeast");
lgd.FontSize = FONT_TICK;
lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
legend(ax,"boxoff");

% スライド用にタイトルは出さない
xlabel(ax,"$y$"); ylabel(ax,"$x$"); zlabel(ax,"$z$");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;
ax.ZLabel.FontSize = FONT_LABEL;

% grooveBtmOn3d.mと大きさ・向きを揃えるため、同じ余白処理（tightenAxesを
% 呼ばずexportgraphicsのタイトクロップに任せる）を踏襲する

%% 保存
saveSlideFigure(fig,saveDir,figName,FIG_W,FIG_H);
