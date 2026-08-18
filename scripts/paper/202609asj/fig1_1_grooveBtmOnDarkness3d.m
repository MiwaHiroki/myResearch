% fig1_1_grooveBtmOnDarkness3d.m
% 音響学会2026年9月 原稿用のFigure 1-1（1段内に横並びのsubfigure、幅=38mm）
% 元画像の暗度DをwaterfallでR3次元表示し、検出した溝底点をscatter3で重ねる
% 溝底点はアップサンプリングを行わない元データにcentroid法を適用して求める
% 同じ溝底点を画像上に表示したものがfig1_2_grooveBtmOnImage.m
% scripts/darkness3d.m を参考にした

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig1-1_grooveBtmOnDarkness3d";

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";
PIXELS = 100;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 81; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

% 表示する範囲。fig1-2の画像の一部にあたる
Y_VIEW = [1 40]; % 溝を横切る方向
X_VIEW = [1 10]; % 溝に平行な方向
Z_VIEW = [0.3 1];
AZ = 30; EL = 30; % 視点

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、subfigureの幅=38mm）
FIG_W = 3.84; FIG_H = 3.56;
FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込み、溝底点を検出する
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessMap(imgData);
origD = origD.setDiffTF(D_TH);

pts = GroovePointCloud(origD);
extractor = GrooveExtractor(origD);
for x = 1:imgData.width
    [firstIdx,lastIdx] = extractor.findThresholdIntervals(origD,x);
    [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_TH);
    pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(origD,x)];
end

ptsXY = vertcat(pts.peakCells{:});
ptsX = ptsXY(:,1); ptsY = ptsXY(:,2);

% 溝底点のy座標は非整数なので、waterfallの面に乗せるDは線形補間で求める
ptsD = zeros(size(ptsX));
for i = 1:numel(ptsX)
    ptsD(i) = interp1((1:origD.nRows)', origD.dMat(:,ptsX(i)), ptsY(i));
end

%% 描画
% waterfall(X,Y,Z)はsize(Z)=[length(Y) length(X)]を要求するのでdMatを転置する
% その結果、図の第1軸がy、第2軸がxになる
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

X = 1:origD.nRows;    % = y
Y = (1:origD.nCols)'; % = x
p = waterfall(ax,X,Y,origD.dMat',"Marker",".");
p.MarkerSize = 2;
hold(ax,"on");
scatter3(ax,ptsY,ptsX,ptsD,5,"cyan","filled","o");
hold(ax,"off");

xlim(ax,Y_VIEW); ylim(ax,X_VIEW); zlim(ax,Z_VIEW); clim(ax,[0 1]);
colormap(ax,flipud(gray));
view(ax,AZ,EL);

% 原稿ではキャプションを付けるので図中のタイトルは出さない
xlabel(ax,"$y$"); ylabel(ax,"$x$"); zlabel(ax,"$D$");
% 38mm幅では既定の目盛りが詰まるので刻みを明示する
xticks(ax,[20 40 60]); yticks(ax,[5 10]); zticks(ax,[0.4 0.7 1]);

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;
ax.ZLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
