% darkness3dComparison.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig4_darkness3dComparison.mと同じデータ・処理を使い、
% origD(元データ), rsmplD(1次元リサンプル), intpD(2次元補間)の暗度Dを
% それぞれwaterfallで3次元表示する。3枚を別々のfigureとして保存する
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （タイトル無し、pngのみ保存。カラーバーは原稿版には無いが今回はスライド用に付ける）

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
IMG_FILE = "DSC1111-00001-ori.png";
PIXELS = 100;    % 切り出す画像の一辺
Y_OFFSET = 101;  % 切り出し開始位置（行=y）
X_OFFSET = 1001; % 切り出し開始位置（列=x）

% この図に限り、点が多く見にくいためrsmplD/intpDのscaleFactor.rowを
% どちらも4に揃える（原稿版: P_RSMPL=8,Q_RSMPL=1→scaleFactor.row=8、
% STEP=0.25→scaleFactor=4）
P_RSMPL = 4; Q_RSMPL = 1;         % 1次元リサンプルの倍率（scaleFactor.row=4）
STEP = 0.25;                      % 2次元補間の刻み（scaleFactor=4）
INTERP_METHOD = "spline";         % 2次元補間の方法

% 表示する範囲。3枚とも元画像の座標で指定する
Y_VIEW = [6 35]; % 溝を横切る方向
X_VIEW = [1 10]; % 溝に平行な方向
Z_VIEW = [0.3 1];
AZ = 30; EL = 30; % 視点

% waterfallはpatchなので、各線の両端にmin(Z(:))まで落ちる「裾」の頂点を足す。
% 表示範囲ちょうどで切ると裾が図の中に現れるので、少し広くデータを渡して
% 裾をxlimの外に出し、axesのクリップで消す
Y_PAD = 2; % Y_VIEWの外側に余分に渡す幅[px]

% orig, rsmpl, intpの順。rsmpl/intpは点が多いためorigより小さくする
MARKER_SIZES = [10, 8, 8];

% 図のサイズ[cm]とフォントサイズ[pt]（スライド用の標準値）
FIG_W = 10; FIG_H = 8;
FONT_TICK = 14; FONT_LABEL = 16;

%% 画像を読み込み、3条件のDarknessMapを作る
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessMap(imgData);
rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
intpD = dInterp(origD,STEP,INTERP_METHOD);

dCell = {origD, rsmplD, intpD};
figNames = ["darkness3dComparison_orig", ...
            "darkness3dComparison_rsmpl", ...
            "darkness3dComparison_intp"];

%% 描画
% waterfall(X,Y,Z)はsize(Z)=[length(Y) length(X)]を要求するのでdMatを転置する
% その結果、図の第1軸がy、第2軸がxになる
for k = 1:numel(dCell)
    d = dCell{k};

    % dMatのインデックスを元画像の座標に直す。これで3枚の軸の意味がそろう
    yCoord = 1 + (0:d.nRows-1)/d.scaleFactor.row; % = y
    xCoord = 1 + (0:d.nCols-1)/d.scaleFactor.col; % = x

    % 表示範囲の外は描かない（アップサンプリング後は点数が多く、
    % 全部描くとpngが重くなるため）
    % ただしy方向はY_PADだけ広げる。waterfallの裾を範囲外に追い出すため
    yIdx = (yCoord >= Y_VIEW(1)-Y_PAD) & (yCoord <= Y_VIEW(2)+Y_PAD);
    xIdx = (xCoord >= X_VIEW(1)) & (xCoord <= X_VIEW(2));

    fig = createFigure([0 0 FIG_W FIG_H]);
    ax = axes(fig);

    p = waterfall(ax,yCoord(yIdx),xCoord(xIdx)',d.dMat(yIdx,xIdx)',"Marker",".");
    p.MarkerSize = MARKER_SIZES(k);

    xlim(ax,Y_VIEW); ylim(ax,X_VIEW); zlim(ax,Z_VIEW); clim(ax,[0 1]);
    colormap(ax,flipud(gray));
    view(ax,AZ,EL);

    % スライド用にタイトルは出さない
    xlabel(ax,"$y$"); ylabel(ax,"$x$"); zlabel(ax,"$D$");

    ax.FontSize = FONT_TICK;
    ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;
    ax.ZLabel.FontSize = FONT_LABEL;

    % 今回はスライド用にカラーバーを付ける（原稿版には無い）
    % c = colorbar(ax);
    % c.FontSize = FONT_TICK;
    % c.TickLabelInterpreter = "latex";

    % tightenAxesはTightInsetにカラーバー分の余白を含まないため、呼ぶとaxesが
    % カラーバーの領域まで広がってカラーバーがキャンバス外にはみ出してしまう。
    % カラーバーがある図ではtightenAxesを使わず、余白はexportgraphicsの
    % タイトクロップに任せる

    % saveSlideFigure(fig,saveDir,figNames(k),FIG_W,FIG_H);
    saveSlideFigure(fig,saveDir,figNames(k)+"_noColorBar",FIG_W,FIG_H);
end
