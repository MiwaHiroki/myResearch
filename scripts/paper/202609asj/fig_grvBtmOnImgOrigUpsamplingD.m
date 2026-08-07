% fig_GrooveBtmOnImageUpsamplingD.mからコピー
% 音響学会2026年9月 原稿用のFigure 3?（1段幅=79mm）
% 1x2のtiledlayoutに，3通りの溝底点を表示する
% 表示する溝底点: オリジナルの暗度(max, cnt)とリサンプルした暗度(cnt)
% 左のタイルはPIXLES=30, 右のタイルはPIXELS=10



setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_grvBtmOnImgUpsamplingD_1x2";

%% パラメータ
IMG_FILE = "DSC1111-00008-ori.png";

% 左右のタイルの設定
PIXELS   = [30,  10];    % 切り出す画像の一辺
Y_OFFSET = [136, 146];  % 切り出し開始位置（行=y）
X_OFFSET = [111, 111]; % 切り出し開始位置（列=x）


D_TH = 0.61; % 暗度の閾値
% W_TH = 8;   % 溝底とみなす区間幅の上限[px] なぜかこっちだとうまくいかない
W_TH = 5;   % 溝底とみなす区間幅の上限[px]

MARKER_SIZE = 5;

P_RSMPL = 8; Q_RSMPL = 1;

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
% FIG_W = 8.01; FIG_H = 8.96; % 正方形の画像1枚のときの設定
% FIG_W = 8.01; FIG_H = 6; % めいっぱい一段使うときの設定
FIG_W = 6; FIG_H = 4.5;
FONT_TICK = 8; FONT_LABEL = 9;


%% それぞれのタイルのための画像を読み込み、3つの方法で溝底点を検出する

% それぞれのタイルに表示するデータ
imgCell = cell(1,2);
origDCell = cell(1,2);
rsmplDCell = cell(1,2);
ptsMaxOrigCell = cell(1,2);
ptsCntOrigCell = cell(1,2);
ptsCntRsmplCell = cell(1,2);
clopX = cell(1,2);
clopY = cell(1,2);

img_gray = rgb2gray(imread(IMG_FILE));

for i=1:2
    clopX{i} = (X_OFFSET(i) : X_OFFSET(i)+PIXELS(i)-1);
    clopY{i} = (Y_OFFSET(i) : Y_OFFSET(i)+PIXELS(i)-1);

    img_small = img_gray(clopY{i}, clopX{i});

    imgData = ImageData(img_small,[1;1]);
    imgCell{i} = imgData;

    origD = DarknessMap(imgData);
    origD = origD.setDiffTF(D_TH);
    origDCell{i} = origD;

    rsmplD = dResample(origD, P_RSMPL, Q_RSMPL);
    rsmplD = rsmplD.setDiffTF(D_TH);
    rsmplDCell{i} = rsmplD;

    pts_max_orig = GroovePointCloud(origD); % 局所的最大値法

    % 重心法
    pts_cnt_orig = GroovePointCloud(origD);
    pts_cnt_rsmpl = GroovePointCloud(rsmplD);

    origExtractor = GrooveExtractor(origD);
    rsmplExtractor = GrooveExtractor(rsmplD);
    for x = 1:imgData.width
        [firstIdx,lastIdx] = origExtractor.findThresholdIntervals(origD,x);
        [origExtractor,~,~,numPeaks] = origExtractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,W_TH);
        pts_max_orig.pksCell{x} = [x*ones(numPeaks,1), origExtractor.extractByLocalMax(origD,x)];
        pts_cnt_orig.pksCell{x} = [x*ones(numPeaks,1), origExtractor.extractByCentroid(origD,x)];

        [firstIdx,lastIdx] = rsmplExtractor.findThresholdIntervals(rsmplD,x);
        [rsmplExtractor,~,~,numPeaks] = rsmplExtractor.findGrooveBottomIntervals(rsmplD,x,firstIdx,lastIdx,W_TH);
        pts_cnt_rsmpl.pksCell{x} = [x*ones(numPeaks,1), rsmplExtractor.extractByCentroid(rsmplD,x)];
    end

    ptsMaxOrigCell{i}  = pts_max_orig;
    ptsCntOrigCell{i}  = pts_cnt_orig;
    ptsCntRsmplCell{i} = pts_cnt_rsmpl;
end

%% 描画
% 凡例はTightInsetに含まれないので、tiledlayoutのPadding="tight"に余白を任せる
% （凡例をレイアウトのタイルに置くと、レイアウトが凡例のぶんの余白を確保する）
fig = createFigure([0 0 FIG_W FIG_H]);
t = tiledlayout(fig,1,2,"TileSpacing","tight","Padding","tight");

for i=1:2 % それぞれのタイルについて
    % showImgは使わず、axesを指定できるimagescで描く
    ax = nexttile(t);

    tmpImg = imgCell{i}.img;
    imagesc(ax,tmpImg);
    colormap(ax,gray); clim(ax,[0 255]);
    axis(ax,"image");
    hold(ax,"on");

    tmpPksCell = ptsMaxOrigCell{i}.pksCell;
    pkDots_max_orig = vertcat(tmpPksCell{:});
    
    tmpPksCell = ptsCntOrigCell{i}.pksCell;
    pkDots_cnt_orig = vertcat(tmpPksCell{:});
    
    tmpPksCell = ptsCntRsmplCell{i}.pksCell;
    pkDots_cnt_rsmpl = vertcat(tmpPksCell{:});
    
    % % orig(max), orig(cnt), rsmpl(cnt)を表示
    % scatter(pkDots_max_orig(:,1),pkDots_max_orig(:,2),MARKER_SIZE,"magenta",Marker="*")
    % scatter(pkDots_cnt_orig(:,1),pkDots_cnt_orig(:,2),MARKER_SIZE,"yellow",Marker="*");
    % % scatter(pkDots_max_rsmpl(:,1),pkDots_max_rsmpl(:,2),MARKER_SIZE,"green",Marker="*");
    % scatter(pkDots_cnt_rsmpl(:,1),pkDots_cnt_rsmpl(:,2),MARKER_SIZE,"cyan",Marker="*");

    colors = [255, 75,  0;...% 赤
              255,241,  0;...% 黄
               77,196,255]/255; % 空色
    scatter(pkDots_max_orig(:,1),pkDots_max_orig(:,2),MARKER_SIZE,colors(1,:),Marker="*")
    scatter(pkDots_cnt_orig(:,1),pkDots_cnt_orig(:,2),MARKER_SIZE,colors(2,:),Marker="*");
    % scatter(pkDots_max_rsmpl(:,1),pkDots_max_rsmpl(:,2),MARKER_SIZE,"green",Marker="*");
    scatter(pkDots_cnt_rsmpl(:,1),pkDots_cnt_rsmpl(:,2),MARKER_SIZE,colors(3,:),Marker="*");


    if i==1 % 左のタイルだけは
        xs = X_OFFSET(2)-X_OFFSET(1)+1;
        ys = Y_OFFSET(2)-Y_OFFSET(1);
        w = PIXELS(2); h = PIXELS(2);
        pgon = polyshape([xs,xs,xs+w-1,xs+w-1],[ys,ys+h-1,ys+h-1,ys]);

        plot(pgon,"FaceColor","none","EdgeColor","r");
    end

    % パターン2: orig(cnt), rsmpl(cnt)
    % pts_cnt_orig.showPoints("magenta",MARKER_SIZE);
    % pts_cnt_rsmpl.showPoints("cyan",MARKER_SIZE);

    
    hold(ax,"off");

    
    % 原稿ではキャプションを付けるので図中のタイトルは出さない
    set(ax,"YDir","reverse","TickDir","out");
    set(ax,"XAxisLocation","top");
    xlabel(ax,"$x$"); ylabel(ax,"$y$");

    if i==2 % 右のタイルだけは
        % lgd = legend(ax,["local maximum","centroid"],Orientation="horizontal");
        % lgd = legend(ax,["original","resampled","interpolated"]);
        lgd = legend(ax,["original (local max)","original (centroid)","resampled (centroid)"]); % パターン1
        % lgd = legend(ax,["original","resampled"]); % パターン2

        lgd.Layout.Tile = "south";
        lgd.FontSize = FONT_TICK;
        lgd.ItemTokenSize = [10 10]; % 凡例のマーカー部分を詰める
        % legend(ax,"boxoff");
    end

    % フォントサイズ（原稿に等倍で貼る前提）
    ax.FontSize = FONT_TICK;
    ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;

    xlim(ax,[1 PIXELS(i)]); ylim(ax,[1 PIXELS(i)])
end



%% 保存
savePaperFigure(fig,saveDir,figName+"_W6",FIG_W,FIG_H);
% savePaperFigure(fig,saveDir,figName+"_30x30",FIG_W,FIG_H);
% savePaperFigure(fig,saveDir,figName+"_2_30x30",FIG_W,FIG_H);
