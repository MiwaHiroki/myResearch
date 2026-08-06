% fig_grooveBtmOnImageOrigRsmplD.m
% 音響学会2026年9月 原稿用のFigure 3?（1段幅=79mm）
% 2つのPIXLES x PIXELS(px)の画像上に溝底点を表示する
% 左のタイルはorigD，右のタイルはrsmplD
% 局所的最大値法と重心法を両方使い，結果を重ねて表示する

% ==================このfigureの見た目に関して==================
% 図が小さすぎて，重心法と局所的最大値法の比較としてはとても見にくい
% さらに，暗度の補間によって形状抽出の精度が上がったのかどうかも分かりにくい
% =============================================================

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_grooveBtmOnImageOrigRsmplD";

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";
PIXELS = 30;    % 切り出す画像の一辺
Y_OFFSET = 136;  % 切り出し開始位置（行=y）
X_OFFSET = 111; % 切り出し開始位置（列=x）

D_TH = 0.6; % 暗度の閾値
% W_TH = 8;   % 溝底とみなす区間幅の上限[px] なぜかこっちだとうまくいかない
W_TH = 5;   % 溝底とみなす区間幅の上限[px]

MARKER_SIZE = 5;

P_RSMPL = 8; Q_RSMPL = 1;
QUERY_STEP = 0.125;
INTERP_METHOD = "spline"; % 二次元内挿の結果は表示しない

UPSAMPLINGS = ["origD","rsmplD","intpD"];
METHODS = ["localMax","centroid"];

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
FIG_W = 8.01; FIG_H = 3.60;
% subfigureを使って2つの図を並べるときは幅38mm
% FIG_W = 3.90; FIG_H = 3.60;
FONT_TICK = 8; FONT_LABEL = 9;


%% 画像を読み込み、溝底点を検出する
img_gray = rgb2gray(imread(IMG_FILE));
img_small = img_gray(Y_OFFSET:Y_OFFSET+PIXELS-1, X_OFFSET:X_OFFSET+PIXELS-1);

imgData = ImageData(img_small,[1;1]);

origD = DarknessMap(imgData);
origD = origD.setDiffTF(D_TH);

rsmplD = dResample(origD, P_RSMPL, Q_RSMPL);
rsmplD = rsmplD.setDiffTF(D_TH);

intpD = dInterp(origD, QUERY_STEP, INTERP_METHOD);
intpD = intpD.setDiffTF(D_TH);

% local maximum method
pts_max_orig = GrooveCandidates(origD);
pts_max_rsmpl = GrooveCandidates(rsmplD);
pts_max_intp = GrooveCandidates(intpD);

% centroid method
pts_cnt_orig = GrooveCandidates(origD);
pts_cnt_rsmpl = GrooveCandidates(rsmplD);
pts_cnt_intp = GrooveCandidates(intpD);

origExtractor = GrooveExtractor(origD);
rsmplExtractor = GrooveExtractor(rsmplD);
intpExtractor = GrooveExtractor(intpD);
for x = 1:imgData.width
    [firstIdx,lastIdx] = origExtractor.findThresholdIntervals(origD,x);
    [origExtractor,~,~,numPeaks] = origExtractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_TH);
    pts_max_orig.pksCell{x} = [x*ones(numPeaks,1), origExtractor.extractByLocalMax(origD,x)];
    pts_cnt_orig.pksCell{x} = [x*ones(numPeaks,1), origExtractor.extractByCentroid(origD,x)];

    [firstIdx,lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD,x);
    [rsmplExtractor,~,~,numPeaks] = rsmplExtractor.findGrooveBottomIntervals(rsmplD,x,firstIdx,lastIdx,W_TH);
    pts_max_rsmpl.pksCell{x} = [x*ones(numPeaks,1), rsmplExtractor.extractByLocalMax(rsmplD,x)];
    pts_cnt_rsmpl.pksCell{x} = [x*ones(numPeaks,1), rsmplExtractor.extractByCentroid(rsmplD,x)];

    [firstIdx,lastIdx] = intpExtractor.findThresholdIntervals(intpD,x);
    [intpExtractor,btmFirstIdx,btmLastIdx,numPeaks] = intpExtractor.findGrooveBottomIntervals(intpD,x,firstIdx,lastIdx,W_TH);
    pts_max_intp.pksCell{x} = [x*ones(numPeaks,1), intpExtractor.extractByLocalMax(intpD,x)];
    pts_cnt_intp.pksCell{x} = [x*ones(numPeaks,1), intpExtractor.extractByCentroid(intpD,x)];
end

pkDots_max_orig = vertcat(pts_max_orig.pksCell{:});
pkDots_max_rsmpl = vertcat(pts_max_rsmpl.pksCell{:});
pkDots_max_intp = vertcat(pts_max_intp.pksCell{:});

pkDots_cnt_orig = vertcat(pts_cnt_orig.pksCell{:});
pkDots_cnt_rsmpl = vertcat(pts_cnt_rsmpl.pksCell{:});
pkDots_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});

%% 描画
% 凡例はTightInsetに含まれないので、tiledlayoutのPadding="tight"に余白を任せる
% （凡例をレイアウトのタイルに置くと、レイアウトが凡例のぶんの余白を確保する）
fig = createFigure([0 0 FIG_W FIG_H]);
nTiles = 2;
t = tiledlayout(fig,1,nTiles,"TileSpacing","compact","Padding","none");

allPts = cell(3,2);
allPts{1,1} = pts_max_orig;  allPts{1,2} = pts_cnt_orig;
allPts{2,1} = pts_max_rsmpl; allPts{2,2} = pts_cnt_rsmpl;
allPts{3,1} = pts_max_intp;  allPts{3,2} = pts_cnt_intp;

% for i=1:numel(UPSAMPLINGS)
for i=1:2
    ax = nexttile(t);
    % showImgは使わず、axesを指定できるimagescで描く
    imagesc(ax,imgData.img);
    colormap(ax,gray); clim(ax,[0 255]);
    axis(ax,"image");
    hold(ax,"on");

    % 原稿ではキャプションを付けるので図中のタイトルは出さない
    set(ax,"YDir","reverse","TickDir","out");
    set(ax,"XAxisLocation","top");
    xlabel(ax,"$x$"); ylabel(ax,"$y$");


    for j=1:numel(METHODS)
        % scatter(pkDots_max(:,1),pkDots_max(:,2),5,"cyan","filled","o","MarkerFaceAlpha",0.5);
        % scatter(pkDots_cnt(:,1),pkDots_cnt(:,2),5,"magenta","filled","o","MarkerFaceAlpha",0.5);
        % pts_cnt_orig.showCandidates("magenta",MARKER_SIZE);
        % pts_cnt_rsmpl.showCandidates("cyan",MARKER_SIZE);
        % pts_cnt_intp.showCandidates("yellow",MARKER_SIZE);

        % switch i % UPSAMPLING
        %     case 1; markerShape = "o";
        %     case 2; markerShape = "*";
        % end

        switch j % METHOD
            case 1
                markerColor = "magenta";
                markerShape = "*";
            case 2
                markerColor = "cyan";
                markerShape = "*";
        end
        tmpPts = allPts{i,j};
        tmpPkDots = vertcat(tmpPts.pksCell{:});
        % scatter(tmpPkDots(:,1),tmpPkDots(:,2),MARKER_SIZE,markerColor,"filled",Marker=markerShape);
        scatter(tmpPkDots(:,1),tmpPkDots(:,2),MARKER_SIZE,markerColor,Marker=markerShape);
        % plot(tmpPkDots(:,1),tmpPkDots(:,2))
        % plot(tmpPkDots(:,1),tmpPkDots(:,2),"Marker","o","MarkerSize",MARKER_SIZE,"MarkerFaceColor","auto");
    end

    % lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
    % lgd = legend(ax,["original","resampled","interpolated"]);
    lgd = legend(ax,["local max","centroid"]);
    % lgd.Layout.Tile = "north";
    lgd.FontSize = FONT_TICK;
    % lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
    % legend(ax,"boxoff");

    % フォントサイズ（原稿に等倍で貼る前提）
    ax.FontSize = FONT_TICK;
    ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;
    hold(ax,"off");
end

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);







