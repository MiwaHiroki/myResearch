% fig1_2_grooveBtmOnImage.m
% 音響学会2026年9月 原稿用のFigure 1-2（1段内に横並びのsubfigure、幅=38mm）
% 100x100pxの画像上に、検出した溝底点を重ねる
% 溝底点はアップサンプリングを行わない元データにcentroid法を適用して求める
% 同じ溝底点を暗度の3次元表示に重ねたものがfig1_1_grooveBtmOnDarkness3d.m

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig1-2_grooveBtmOnImage";

%% パラメータ
IMG_FILE = "DSC1111-00001-ori.png";
PIXELS = 100;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 1001; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

% fig1-1で表示している範囲。矩形で示す
Y_VIEW = [1 60]; % 溝を横切る方向
X_VIEW = [1 10]; % 溝に平行な方向

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、subfigureの幅=38mm）
% 高さはfig1-1の出力とそろえる
FIG_W = 3.90; FIG_H = 3.60;
FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込み、溝底点を検出する
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessValue(imgData);
origD = origD.setDiffTF(D_TH);

pts = GrooveCandidates(origD);
for x = 1:imgData.width
    [startIdx,endIdx] = getStartEndIdx(origD,x);
    [origD,~,~,pksNum] = getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
    pts.pksCell{x} = [x*ones(pksNum,1), origD.extractGrv_cnt(x)];
end

ptsXY = vertcat(pts.pksCell{:});
ptsX = ptsXY(:,1); ptsY = ptsXY(:,2);

%% 描画
% showImgは使わず、axesを指定できるimagescで描く
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,ptsX,ptsY,1.5,"red","filled","o");
% fig1-1で表示している範囲を矩形で示す
rectangle(ax,"Position",[X_VIEW(1) Y_VIEW(1) diff(X_VIEW) diff(Y_VIEW)], ...
    "EdgeColor","cyan","LineWidth",0.5);
hold(ax,"off");

% 原稿ではキャプションを付けるので図中のタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
xlabel(ax,"$x$"); ylabel(ax,"$y$");
% 38mm幅では既定の目盛りが詰まるので刻みを明示する
xticks(ax,[50 100]); yticks(ax,[50 100]);

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
