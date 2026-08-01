% fig3_grooveBtmMethodsOnImage.mからコピー
% 音響学会2026年9月 原稿用のFigure 3?（1段幅=79mm）
% PIXLES x PIXELS(px)の画像上に、オリジナルの暗度とリサンプルした暗度(と二次元内挿した暗度?)
% から得た溝底点を重ねて比較する
% すべて重心法を使う

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_grooveBtmOnImageUpsamplingD";

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";
PIXELS = 30;    % 切り出す画像の一辺
Y_OFFSET = 136;  % 切り出し開始位置（行=y）
X_OFFSET = 111; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
% W_TH = 8;   % 溝底とみなす区間幅の上限[px] なぜかこっちだとうまくいかない
W_TH = 5;   % 溝底とみなす区間幅の上限[px]

MARKER_SIZE = 20;

P_RSMPL = 8; Q_RSMPL = 1;
QUERY_STEP = 0.125;
INTERP_METHOD = "spline";

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

rsmplD = dResample(origD, P_RSMPL, Q_RSMPL);
rsmplD = rsmplD.setDiffTF(D_TH);

intpD = dInterp(origD, QUERY_STEP, INTERP_METHOD);
intpD = intpD.setDiffTF(D_TH);

pts_cnt_orig = GrooveCandidates(origD); % 重心法
pts_cnt_rsmpl = GrooveCandidates(rsmplD);
pts_cnt_intp = GrooveCandidates(intpD);

for x = 1:imgData.width
    [startIdx,endIdx] = getStartEndIdx(origD,x);
    [origD,~,~,pksNum] = getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
    pts_cnt_orig.pksCell{x} = [x*ones(pksNum,1), origD.extractGrv_cnt(x)];

    [startIdx,endIdx] = getStartEndIdx(rsmplD,x);
    [rsmplD,~,~,pksNum] = getGrooveBtmIdx(rsmplD,x,startIdx,endIdx,W_TH);
    pts_cnt_rsmpl.pksCell{x} = [x*ones(pksNum,1), rsmplD.extractGrv_cnt(x)];
    
    [startIdx,endIdx] = getStartEndIdx(intpD,x);
    [intpD,sIdxBtm,eIdxBtm,pksNum] = getGrooveBtmIdx(intpD,x,startIdx,endIdx,W_TH);
    pts_cnt_intp.pksCell{x} = [x*ones(pksNum,1), intpD.extractGrv_cnt(x)];

end

pkDots_orig = vertcat(pts_cnt_orig.pksCell{:});
pkDots_rsmpl = vertcat(pts_cnt_rsmpl.pksCell{:});
pkDots_intp = vertcat(pts_cnt_intp.pksCell{:});

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
% scatter(pkDots_max(:,1),pkDots_max(:,2),5,"cyan","filled","o","MarkerFaceAlpha",0.5);
% scatter(pkDots_cnt(:,1),pkDots_cnt(:,2),5,"magenta","filled","o","MarkerFaceAlpha",0.5);
pts_cnt_orig.showCandidates("magenta",MARKER_SIZE);
pts_cnt_rsmpl.showCandidates("cyan",MARKER_SIZE);
% pts_cnt_intp.showCandidates("cyan",MARKER_SIZE);
hold(ax,"off");

% xlim(ax,[X_OFFSET,X_OFFSET+PIXELS-1]);
% ylim(ax,[Y_OFFSET,Y_OFFSET+PIXELS-1])

% 原稿ではキャプションを付けるので図中のタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

% lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
% lgd = legend(ax,["original","resampled","interpolated"]);
lgd = legend(ax,["original","resampled"]);
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
