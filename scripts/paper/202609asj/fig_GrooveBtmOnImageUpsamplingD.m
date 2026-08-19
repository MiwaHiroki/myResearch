% fig3_grooveBtmMethodsOnImage.mからコピー
% 音響学会2026年9月 原稿用のFigure 3?（1段幅=79mm）
% PIXLES x PIXELS(px)の画像上に、オリジナルの暗度とリサンプルした暗度(と二次元内挿した暗度?)
% から得た溝底点を重ねて比較する
% すべて重心法を使う

% =====================メモ=====================
% 2通りまでの結果しか表示しないならPIXELS=30とすればよい
% 3通り以上の結果を表示する場合，PIXELS=10とした方がいい
% 別スクリプトでfigureを作る-->fig_grvBtmOnImgOrigUpsamplingD.mへ

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

% PIXELS = 10;    % 切り出す画像の一辺
% Y_OFFSET = 146;  % 切り出し開始位置（行=y）
% X_OFFSET = 111; % 切り出し開始位置（列=x）


D_TH = 0.61; % 暗度の閾値
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

origD = DarknessMap(imgData);
origD = origD.setDiffTF(D_TH);

rsmplD = dResample(origD, P_RSMPL, Q_RSMPL);
rsmplD = rsmplD.setDiffTF(D_TH);

intpD = dInterp(origD, QUERY_STEP, INTERP_METHOD);
intpD = intpD.setDiffTF(D_TH);

pts_max_orig = GroovePointCloud(origD); % 局所的最大値法
pts_max_rsmpl = GroovePointCloud(origD); % 局所的最大値法

% 重心法
pts_cnt_orig = GroovePointCloud(origD);
pts_cnt_rsmpl = GroovePointCloud(rsmplD);
pts_cnt_intp = GroovePointCloud(intpD);

origExtractor = GrooveExtractor(origD);
rsmplExtractor = GrooveExtractor(rsmplD);
intpExtractor = GrooveExtractor(intpD);
for x = 1:imgData.width
    [firstIdx,lastIdx] = origExtractor.findThresholdIntervals(origD,x);
    [origExtractor,~,~,numPeaks] = origExtractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_TH);
    pts_max_orig.peakCells{x} = [x*ones(numPeaks,1), origExtractor.extractByLocalMax(origD,x)];
    pts_cnt_orig.peakCells{x} = [x*ones(numPeaks,1), origExtractor.extractByCentroid(origD,x)];

    [firstIdx,lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD,x);
    [rsmplExtractor,~,~,numPeaks] = rsmplExtractor.findGrooveBottomIntervals(rsmplD,x,firstIdx,lastIdx,W_TH);
    pts_max_rsmpl.peakCells{x} = [x*ones(numPeaks,1), rsmplExtractor.extractByLocalMax(rsmplD,x)];
    pts_cnt_rsmpl.peakCells{x} = [x*ones(numPeaks,1), rsmplExtractor.extractByCentroid(rsmplD,x)];

    [firstIdx,lastIdx] = intpExtractor.findThresholdIntervals(intpD,x);
    [intpExtractor,btmFirstIdx,btmLastIdx,numPeaks] = intpExtractor.findGrooveBottomIntervals(intpD,x,firstIdx,lastIdx,W_TH);
    pts_cnt_intp.peakCells{x} = [x*ones(numPeaks,1), intpExtractor.extractByCentroid(intpD,x)];

end

pkDots_max_orig = vertcat(pts_max_orig.peakCells{:});
pkDots_cnt_orig = vertcat(pts_cnt_orig.peakCells{:});

pkDots_max_rsmpl = vertcat(pts_max_rsmpl.peakCells{:});
pkDots_cnt_rsmpl = vertcat(pts_cnt_rsmpl.peakCells{:});

pkDots_intp = vertcat(pts_cnt_intp.peakCells{:});

%% 描画
% 凡例はTightInsetに含まれないので、tiledlayoutのPadding="tight"に余白を任せる
% （凡例をレイアウトのタイルに置くと、レイアウトが凡例のぶんの余白を確保する）
fig = createFigure([0 0 FIG_W FIG_H]);
t = tiledlayout(fig,1,1,"TileSpacing","tight","Padding","tight");

% showImageは使わず、axesを指定できるimagescで描く
ax = nexttile(t);
imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");

% パターン1: orig(max), orig(cnt), rsmpl(cnt)
scatter(pkDots_max_orig(:,1),pkDots_max_orig(:,2),MARKER_SIZE,"magenta",Marker="*")
scatter(pkDots_cnt_orig(:,1),pkDots_cnt_orig(:,2),MARKER_SIZE,"yellow",Marker="*");
% scatter(pkDots_max_rsmpl(:,1),pkDots_max_rsmpl(:,2),MARKER_SIZE,"green",Marker="*");
scatter(pkDots_cnt_rsmpl(:,1),pkDots_cnt_rsmpl(:,2),MARKER_SIZE,"cyan",Marker="*");

% パターン2: orig(cnt), rsmpl(cnt)
% pts_cnt_orig.showPoints("magenta",MARKER_SIZE);
% pts_cnt_rsmpl.showPoints("cyan",MARKER_SIZE);

% 使わない
% pts_cnt_intp.showPoints("yellow",MARKER_SIZE);

hold(ax,"off");

% xlim(ax,[X_OFFSET,X_OFFSET+PIXELS-1]);
% ylim(ax,[Y_OFFSET,Y_OFFSET+PIXELS-1])

% 原稿ではキャプションを付けるので図中のタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");

% lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
% lgd = legend(ax,["original","resampled","interpolated"]);
lgd = legend(ax,["original (local max)","original (centroid)","resampled (centroid)"]); % パターン1
% lgd = legend(ax,["original","resampled"]); % パターン2

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
% savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
savePaperFigure(fig,saveDir,figName+"_30x30",FIG_W,FIG_H);
% savePaperFigure(fig,saveDir,figName+"_2_30x30",FIG_W,FIG_H);
