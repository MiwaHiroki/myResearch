% darknessProfile.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig2_darknessProfile.mをもとに、以下の3枚を
% 1図1ファイルのpngとして書き出す
%   1. darknessProfile_column        - 画像 + x=X_Cの位置を示す縦線
%   2. darknessProfile_profile       - 元スクリプトfig2-1相当（x=X_Cの暗度断面）
%                                       今回のみカラーバーを表示する
%   3. darknessProfile_grooveBtmRange - 元スクリプトfig2-2相当（全列の溝底区間を
%                                       赤点・黄点で表示）
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （タイトル無し、pngのみ保存）。ただし図の大きさは今回に限り8cm×8cm（[[slide-figure-size]]
% の標準12cm×8cmではなく、正方形画像に合わせて3図とも揃える）。

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";
PIXELS = 30;    % 切り出す画像の一辺
Y_OFFSET = 136; % 切り出し開始位置（行=y）
X_OFFSET = 111; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

X_C = 1;         % 暗度分布を見る列（元スクリプトのX_C=30から変更）
Y_VIEW = [1 30]; % 表示するyの範囲

MARKER_SIZE = 8;

% 1の縦線の色と2のプロット線の色をこの値で揃える（既定の1本目の線色）
LINE_COLOR = [0 0.4470 0.7410];

% 図のサイズ[cm]とフォントサイズ[pt]。大きさは今回に限り3図とも8cm×8cmにする
FIG_W = 8; FIG_H = 8;
FIG_W_COLUMN = FIG_W + 2; % 1はカラーバーを追加する分、横幅を+2cmする
FONT_TICK = 14; FONT_LABEL = 16;

%% 画像を読み込み、各列の溝底区間を求める
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessMap(imgData);
origD = origD.setDiffTF(D_TH);

extractor = GrooveExtractor(origD);
sIdxBtmCell = cell(1,origD.nCols);
eIdxBtmCell = cell(1,origD.nCols);

for x = 1:imgData.width
    [startIdx,endIdx] = extractor.findThresholdIntervals(origD,x);
    [extractor,sIdxBtm,eIdxBtm,pksNum] = extractor.findGrooveBottomIntervals(origD,x,startIdx,endIdx,W_TH);

    sIdxBtmCell{x} = [x*ones(pksNum,1), sIdxBtm];
    eIdxBtmCell{x} = [x*ones(pksNum,1), eIdxBtm];

    if x==X_C
        sIdxBtm_C = sIdxBtm;
        eIdxBtm_C = eIdxBtm;
    end
end

allsIdxBtm = vertcat(sIdxBtmCell{:});
alleIdxBtm = vertcat(eIdxBtmCell{:});

% dMat上のインデックスを元画像のy座標に戻す（等倍なら恒等）
sY = (sIdxBtm_C - 1)/origD.scaleFactor.row + 1;
eY = (eIdxBtm_C - 1)/origD.scaleFactor.row + 1;
allsIdxBtm(:,2) = (allsIdxBtm(:,2) - 1)/origD.scaleFactor.row + 1;
alleIdxBtm(:,2) = (alleIdxBtm(:,2) - 1)/origD.scaleFactor.row + 1;

%% 描画1: 切り出した画像 + x=X_Cの位置を示す縦線（2の線色と揃える）
% カラーバーを追加するのでtiledlayout+Padding="tight"で余白を確保する
% ([[colorbar-figure-caution]]参照。axis imageのため横幅をFIG_W_COLUMNに広げる)
fig = createFigure([0 0 FIG_W_COLUMN FIG_H]);
t = tiledlayout(fig,1,1,"Padding","tight");
ax = nexttile(t);

imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
xline(ax,X_C,"-","LineWidth",1.5,"Color",LINE_COLOR);
hold(ax,"off");

set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");
xticks(ax,[10 20 30]); yticks(ax,[10 20 30]);

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

% カラーバー: 軸ラベルは付けない（画素値0-255の参照用）
c = colorbar(ax);
c.Layout.Tile = "east";
c.FontSize = FONT_TICK;

saveSlideFigure(fig,saveDir,"darknessProfile_column",FIG_W_COLUMN,FIG_H);

%% 描画2(fig2-1相当): x=X_Cでの暗度断面。今回のみカラーバーを表示する
% カラーバーがあるのでtiledlayout+Padding="tight"で余白を確保する
% ([[colorbar-figure-caution]]参照。単体axesの自動レイアウトはラベルが見切れうる）
fig = createFigure([0 0 FIG_W FIG_H]);
t = tiledlayout(fig,1,1,"Padding","tight");
ax = nexttile(t); % plotDarknessColumnはgcaに描くのでnexttileを先に呼ぶ

p = origD.plotDarknessColumn(X_C,ShowTitle=false,ShowColorbar=false,ShowLineMarker=true);
p.Color = LINE_COLOR; % 1の縦線と色を揃える
hold(ax,"on");
yline(ax,D_TH,"-","LineWidth",0.5,"Color","k");
scatter(ax,sY,origD.dMat(sIdxBtm_C,X_C),MARKER_SIZE,"red","filled","o");
scatter(ax,eY,origD.dMat(eIdxBtm_C,X_C),MARKER_SIZE,"yellow","filled","o","MarkerEdgeColor","k");
hold(ax,"off");

xlim(ax,Y_VIEW);
lgd = legend(ax,["$D$","$D_\mathrm{th}$","start","end"],Location="southwest");
lgd.FontSize = FONT_TICK;
lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
legend(ax,"boxoff");

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

% カラーバー: 今回のみ表示する。DarknessMap.plotDarknessColumnのShowColorbar=trueは
% colorbar("eastoutside")を直書きしているため使わず、[[colorbar-figure-caution]]の
% 手順（tiledlayout + c.Layout.Tile="east"）で自前に付ける
colormap(ax,flip(gray));
clim(ax,[0 1]);
c = colorbar(ax);
c.Layout.Tile = "east";
c.FontSize = FONT_TICK;

saveSlideFigure(fig,saveDir,"darknessProfile_profile",FIG_W,FIG_H);

%% 描画3(fig2-2相当): 画像上に全列の溝底区間の始点・終点を表示
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,allsIdxBtm(:,1),allsIdxBtm(:,2),MARKER_SIZE,"red","filled","o");
scatter(ax,alleIdxBtm(:,1),alleIdxBtm(:,2),MARKER_SIZE,"yellow","filled","o");
hold(ax,"off");

set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");
xticks(ax,[10 20 30]); yticks(ax,[10 20 30]);

ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax);
saveSlideFigure(fig,saveDir,"darknessProfile_grooveBtmRange",FIG_W,FIG_H);
