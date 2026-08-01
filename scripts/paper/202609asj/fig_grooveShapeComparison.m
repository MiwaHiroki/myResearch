% fig_grooveShapeComparison.m
% 音響学会2026年9月 原稿用のFigure（1段幅=79mm）
% 1枚のimg_small（I_IMG枚目の写真をNUM_SEGMENTS等分したI_SEGMENT番目）から
% origD(高解像度化なし), rsmplD(1次元リサンプル), intpD(2次元補間)を作り、
% それぞれ重心法で溝1本ぶんの形状を抽出して重ねてプロットする
%
% 溝1本の選び方は1周分のパイプライン（pkCentroidAndLocalMax_resample_1cycle.m）と
% 変えてある。パイプラインはfitGrooveのginputで溝中心をクリックさせるが、
% ここでは表示するxの範囲が100px程度で溝の傾きが無視できるので、
% 溝中心のy座標をY_GROOVEで直接与え、±TOL_DISTANCE内の候補点を採る

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_grooveShapeComparison";

%% パラメータ
% 画像の指定
NUM_IMAGES = 8;    % レコードを8回に分けて撮影している
NUM_SEGMENTS = 10; % 細長い画像を10等分する
I_IMG = 1;         % 何枚目の写真か
I_SEGMENT = 1;     % その写真を10等分したうちの何番目か

% 1周分のパイプラインから引き継ぐ定数
L_MASK = 20;       % omitMaskで端の黒いマスクを落とすluminanceの閾値
TOL_DISTANCE = 4;  % 溝中心からこの距離[px]以内の候補点を同じ溝とみなす

% 他の202609asjスクリプトと同じ溝底検出の定数
D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

% 高解像度化の条件（fig4_darkness3dComparison.mと同じ）
P_RSMPL = 8; Q_RSMPL = 1; % 1次元リサンプルの倍率
STEP = 0.125;              % 2次元補間の刻み
INTERP_METHOD = "spline"; % 2次元補間の方法

% 追いかける溝の中心のy座標[px]。この画像では溝が約27px間隔で並ぶので、
% 別の溝にしたいときは±27ずつずらす（端に寄りすぎない溝を選ぶこと）
Y_GROOVE = 205;

% X_VIEW = [1 100]; % 表示するxの範囲[px]
X_VIEW = [1,50];

% 図のサイズ[cm]とフォントサイズ[pt]
% fig_grooveShapeMethodComparisonと横に並べて1段=79mmに収めるので、正方形で38mm
FIG_W = 3.92; FIG_H = 3.95;
FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込んでimg_smallを切り出す
% 1周分のパイプラインと同じく、I_IMG=1が最後のファイルに対応する
filenames = "DSC1111-0000" + string((1:NUM_IMAGES)') + "-ori";
img_gray = rgb2gray(imread(filenames(NUM_IMAGES+1-I_IMG) + ".png"));

imgWidth = size(img_gray,2);
divImgWidth = round(imgWidth / NUM_SEGMENTS);
xarray = [1:divImgWidth:imgWidth imgWidth+1]';
img_small = img_gray(:, xarray(I_SEGMENT):xarray(I_SEGMENT+1)-1);

img_omitMask = omitMask(img_small,L_MASK);
imgData = ImageData(img_omitMask,[I_IMG;I_SEGMENT]);

%% 3条件のDarknessValueを作る
% 高解像度化はimg_small全体に対して行う（表示範囲で切ってから補間すると
% 端に補間の誤差が出るため）
origD = DarknessValue(imgData);
rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
intpD = dInterp(origD,STEP,INTERP_METHOD);

dCell = {origD, rsmplD, intpD};
% 38mm幅では"interpolation (spline)"は凡例からはみ出すので補間方法は書かない
lgdNames = ["no upsampling","resample","interpolation"];

%% 溝1本の形状を抽出する
grvX = cell(numel(dCell),1);
grvY = cell(numel(dCell),1);

for k = 1:numel(dCell)
    d = setDiffTF(dCell{k},D_TH);

    % dMatの列インデックスを元画像のx座標に直す。rsmplDは列を増やさないので
    % scaleFactor.colは1、intpDは1/STEPになる
    xCoord = 1 + (0:d.nCols-1)/d.scaleFactor.col;
    colIdx = find(xCoord >= X_VIEW(1) & xCoord <= X_VIEW(2));

    y = NaN(numel(colIdx),1);

    for i = 1:numel(colIdx)
        x = colIdx(i);
        [startIdx,endIdx] = getStartEndIdx(d,x);
        [d,~,~,pksNum] = getGrooveBtmIdx(d,x,startIdx,endIdx,W_TH);
        if pksNum == 0
            continue % この列では溝底が見つからなかった
        end

        % extractGrv_cntは元画像のy座標を返すのでそのまま比較できる
        cand = d.extractGrv_cnt(x);
        [dist,iNear] = min(abs(cand - Y_GROOVE));
        if dist <= TOL_DISTANCE
            y(i) = cand(iNear);
        end
    end

    % 抽出に失敗した列を埋める（パイプラインと同じ扱い）
    nMissing = sum(isnan(y));
    if nMissing > 0
        fprintf("%s: %d/%d 列で溝底が採れなかったので線形補間しました\n", ...
            lgdNames(k), nMissing, numel(y));
    end
    y = fillmissing(y,"linear");

    grvX{k} = xCoord(colIdx)';
    grvY{k} = y;
end

%% 描画
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);
hold(ax,"on");
for k = 1:numel(dCell)
    plot(ax,grvX{k},grvY{k},"-"); % 線種は実線、色は既定の順番
    % plot(ax,grvX{k},grvY{k},"-","Marker","."); % 線種は実線、色は既定の順番
end
hold(ax,"off");

% 原稿ではキャプションを付けるので図中のタイトルは出さない
xlim(ax,X_VIEW);
% ylim(ax, [203 207]);% ylimは自動?
xlabel(ax,"$x$"); ylabel(ax,"$y$");
% boxがoffだと右と上に軸線が無く、exportgraphicsがデータや凡例の右端で
% 切るため出力幅が安定しない。枠を付けて切り取り位置を確定させる
box(ax,"on");

% 凡例はTightInsetに含まれないのでaxesの内側に置く
lgd = legend(ax,lgdNames,Location="best");
lgd.FontSize = FONT_TICK;
lgd.ItemTokenSize = [10 10]; % 凡例の線の部分を詰める
legend(ax,"boxoff");

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
