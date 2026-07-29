% fig_darknessProfile.m
% 音響学会2026年9月 原稿用のFigure（1段幅=79mm）
% ある画像のx=X_Cにおける暗度Dの分布（溝を横切るy方向）を図示する
% 閾値D_thの水平線と、溝底とみなした区間の始点startIdx・終点endIdxを重ねる

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
% 出力ファイル名。LaTeXで扱えるよう英数字と-_のみを使う
FIG_NAME_PROFILE = "fig2-1_darknessProfile";       % x=X_Cの断面
FIG_NAME_IMAGE = "fig2-2_grooveBtmRangeOnImage";   % 画像上の区間始点・終点

%% パラメータ
IMG_FILE = "DSC1111-00001-ori.png";
PIXELS = 50;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 1001; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

X_C = 50;        % 暗度分布を見る列
Y_VIEW = [1 50]; % 表示するyの範囲

MARKER_SIZE = 3;


% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
% FIG_W = 7.93; FIG_H = 5.08;
FIG_W = 3.90; FIG_H = 3.60;

FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込み、x=X_Cの溝底区間を求める
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessValue(imgData);
origD = origD.setDiffTF(D_TH);

sIdxBtmCell = cell(1,origD.nCols);
eIdxBtmCell = cell(1,origD.nCols);

for x=1:imgData.width
    [startIdx,endIdx] = getStartEndIdx(origD,x);
    [origD,sIdxBtm,eIdxBtm,pksNum] = getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);

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


%% 描画(x=X_Cでの断面)
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);

% 原稿ではキャプションを付けるので図中のタイトルは出さない
% カラーバーは線グラフには不要なので出さない
origD.plotD_x(X_C,ShowTitle=false,ShowColorbar=false,ShowLineMarker=true);
hold(ax,"on");
yline(ax,D_TH,"-","LineWidth",0.5,"Color","k");
scatter(ax,sY,origD.dMat(sIdxBtm,X_C),8,"red","filled","o");
scatter(ax,eY,origD.dMat(eIdxBtm,X_C),8,"yellow","filled","o");
hold(ax,"off");

xlim(ax,Y_VIEW);
lgd = legend(ax,["$D$","$D_\mathrm{th}$","start","end"],Location="southeast");
lgd.FontSize = FONT_TICK;
lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
legend(ax,"boxoff");

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存(x=X_Cでの断面)
savePaperFigure(fig,saveDir,FIG_NAME_PROFILE,FIG_W,FIG_H);

%% 描画(画像上)
fig = createFigure([0 0 FIG_W FIG_H]);
t = tiledlayout(fig,1,1,"TileSpacing","tight","Padding","tight");

% showImgは使わず、axesを指定できるimagescで描く
ax = nexttile(t);
imagesc(ax,imgData.img);
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,allsIdxBtm(:,1),allsIdxBtm(:,2),MARKER_SIZE,"red","filled","o");
scatter(ax,alleIdxBtm(:,1),alleIdxBtm(:,2),MARKER_SIZE,"yellow","filled","o");
hold(ax,"off");

% 原稿ではキャプションを付けるので図中のタイトルは出さない
set(ax,"YDir","reverse","TickDir","out");
set(ax,"XAxisLocation","top");
xlabel(ax,"$x$"); ylabel(ax,"$y$");
xticks(ax,[25 50]); yticks(ax,[25 50]);

% lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
% lgd.Layout.Tile = "north";
% lgd.FontSize = FONT_TICK;
% lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
% legend(ax,"boxoff");

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;


%% 保存
savePaperFigure(fig,saveDir,FIG_NAME_IMAGE,FIG_W,FIG_H);
