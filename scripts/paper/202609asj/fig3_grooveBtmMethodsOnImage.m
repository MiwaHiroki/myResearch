% fig3_grooveBtmMethodsOnImage.m
% --------------!!!あまりにも見にくくて使えないかも!!!--------------------
% 音響学会2026年9月 原稿用のFigure 3（1段幅=79mm）
% PIXLES x PIXELS(px)の画像上に、局所的最大値法と重心法で抽出した溝底点を重ねて比較する
% どちらもアップサンプリングを行わない元データ(origD)から抽出する


setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig3_grooveBtmMethodsOnImage";

%% パラメータ
IMG_FILE = "DSC1111-00001-ori.png";
PIXELS = 50;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 1001; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

MARKER_SIZE = 3;

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
% 画像が正方形なので縦に長くなる。小さくしたい場合はFIG_W,FIG_Hを同じ比で縮める
FIG_W = 8.01; FIG_H = 8.96;
% subfigureの幅38mm
% FIG_W = 3.90; FIG_H = 3.60;
FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込み、2つの方法で溝底点を検出する
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessValue(imgData);
origD = origD.setDiffTF(D_TH);

pts_max = GrooveCandidates(origD); % 局所的最大値法
pts_cnt = GrooveCandidates(origD); % 重心法


for x = 1:imgData.width
    [startIdx,endIdx] = getStartEndIdx(origD,x);
    [origD,sIdxBtm,eIdxBtm,pksNum] = getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
    pts_max.pksCell{x} = [x*ones(pksNum,1), origD.extractGrv_max(x)];
    pts_cnt.pksCell{x} = [x*ones(pksNum,1), origD.extractGrv_cnt(x)];
end

pkDots_max = vertcat(pts_max.pksCell{:});
pkDots_cnt = vertcat(pts_cnt.pksCell{:});

%% 描画
% 凡例はTightInsetに含まれないので、tiledlayoutのPadding="tight"に余白を任せる
% （凡例をレイアウトのタイルに置くと、レイアウトが凡例のぶんの余白を確保する）
fig = createFigure([0 0 FIG_W FIG_H]);
t = tiledlayout(fig,1,1,"TileSpacing","tight","Padding","tight");

% showImgは使わず、axesを指定できるimagescで描く
ax = nexttile(t);
imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(pkDots_max(:,1),pkDots_max(:,2),5,"cyan","filled","o","MarkerFaceAlpha",0.5);
scatter(pkDots_cnt(:,1),pkDots_cnt(:,2),5,"magenta","filled","o","MarkerFaceAlpha",0.5);
% pts_max.showCandidates("red",MARKER_SIZE);
    % pts_cnt.showCandidates("cyan",MARKER_SIZE);
hold(ax,"off");

% 原稿ではキャプションを付けるので図中のタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

% lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
lgd = legend(ax,["local maximum","centroid"]);
% lgd.Layout.Tile = "north";
lgd.FontSize = FONT_TICK;
% lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
% legend(ax,"boxoff");

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
