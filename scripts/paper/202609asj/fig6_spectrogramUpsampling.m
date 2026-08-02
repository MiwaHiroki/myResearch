% fig6_spectrogramUpsampling.m
% 音響学会2026年9月 原稿用のFigure 6（1段幅=79mm）
% 従来法と、rsmplD(1次元リサンプル)・intpD(2次元補間)から重心法で作成した音声の
% スペクトログラムを、tiledlayoutで横に3枚並べて1つのfigureにする
% 左から 従来法 / rsmplD / intpD
% 様式はfig5_spectrogramComparison.mに合わせてある
% 軸ラベルとカラーバーは3枚で共通にする（カラーバーはfigureの右端）
%
% 従来法 = 既製の画像編集ソフトで高解像度化した画像から、局所的最大値法で
% 溝形状を抽出して作成した音声
%
% rsmplD/intpDの音声はsaveCycleResultで保存した1周分の結果.matから読み込む
% fig5はorigDの1ファイルから2手法を読むが、こちらは条件ごとに別ファイルなので
% 2つの.matを読む
% 従来法は1周分の結果.matが無くAudioDataだけなので、別の.matから読み込む

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig6_spectrogramUpsampling";

%% パラメータ
% 読み込む結果.mat（experiments/<日付>/cycleResult_<条件>_<日付>.mat）
DATE = "0731";
UPSAMPLINGS = ["rsmplD","intpD"]; % 中央がrsmplD、右がintpD
METHOD = "centroid";              % 溝底抽出の手法は固定して高解像度化だけを比べる

CONV_DATE = "0802";
% 従来法の音声。AudioDataを1つ入れた.matを想定している
% 実際の保存先・変数名に合わせて書き換える
CONV_MAT = fullfile(proj.RootFolder,"experiments",CONV_DATE, ...
    "cycleResult_origD_"+CONV_DATE+".mat");
CONV_VAR = "localmax.audio"; % .mat内のAudioDataの変数名
CONV_NAME = "conventional"; % 表示・ログ用の名前

% intpDはx方向も補間するのでfsがrsmplDの8倍になる。窓長をサンプル数で揃えると
% 窓が覆う時間と周波数分解能がずれるので、fsに比例させて時間長を揃える
WIN_SIZE_REF = 1024; % 一番左の図のfsに対する窓長[サンプル]

F_VIEW = [0 5e3];  % 表示する周波数の範囲[Hz]
C_VIEW = [-120 0]; % 表示するレベルの範囲[dB]
C_STEP = 30;       % カラーバーの目盛り間隔[dB]
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
FIG_W = 7.9; FIG_H = 5;
FONT_TICK = 8; FONT_LABEL = 9;

%% 音声データを読み込む
% 一番左が従来法、その右がUPSAMPLINGSの順
audioCell = cell(1,1+numel(UPSAMPLINGS));
audioNames = [CONV_NAME, UPSAMPLINGS + " / " + METHOD];

% 従来法
if ~isfile(CONV_MAT)
    error("fig6:noConventionalFile", ...
        "従来法の音声が見つかりません: %s\n" + ...
        "既製ソフトで高解像度化した画像から局所的最大値法で作成した音声を、" + ...
        "変数名 %s のAudioDataとしてこのパスに保存してください。", ...
        CONV_MAT, CONV_VAR);
end

S = load(CONV_MAT);
if ~isfield(S.result.(CONV_VAR))
    error("fig6:noConventionalVar", ...
        "%s に変数 %s がありません。", CONV_MAT, CONV_VAR);
end
if ~isa(S.(CONV_VAR),"AudioData")
    error("fig6:notAudioData", ...
        "%s の %s はAudioDataではありません（%s）。", ...
        CONV_MAT, CONV_VAR, class(S.(CONV_VAR)));
end
audioCell{1} = S.(CONV_VAR);

% rsmplD, intpD
for k = 1:numel(UPSAMPLINGS)
    matPath = cycleResultPath(proj.RootFolder,UPSAMPLINGS(k),DATE);
    result = loadCycleResult(matPath);

    if ~isfield(result,METHOD) || isempty(result.(METHOD).audio)
        error("fig6:noAudio", ...
            "%s に %s の音声が入っていません。", matPath, METHOD);
    end
    audioCell{1+k} = result.(METHOD).audio;
end

% どの音声を読んだかを残す（保存時に手法を取り違えていないかの確認用）
for k = 1:numel(audioCell)
    fprintf("%s: name=""%s"", fs=%d Hz\n", ...
        audioNames(k), audioCell{k}.name, audioCell{k}.fs);
end

% 窓長をfsに比例させる。2のべきに丸めてOverlapLength=winSize/2が整数になるようにする
fsRef = audioCell{2}.fs;
winSizes = zeros(1,numel(audioCell));
for k = 1:numel(audioCell)
    winSizes(k) = 2^round(log2(WIN_SIZE_REF * audioCell{k}.fs / fsRef));
    fprintf("  窓長 %d サンプル (%.1f ms, 周波数分解能 %.1f Hz)\n", ...
        winSizes(k), winSizes(k)/audioCell{k}.fs*1e3, audioCell{k}.fs/winSizes(k));
end

%% 描画
% カラーバーはTightInsetに含まれないので、tiledlayoutのPadding="tight"に
% 余白を任せる（カラーバーをレイアウトのタイルに置くと、そのぶんの余白が確保される）
fig = createFigure([0 0 FIG_W FIG_H]);
% TileSpacingを"tight"にすると隣どうしが密着して見にくいので"compact"にする
t = tiledlayout(fig,1,numel(audioCell),"TileSpacing","compact","Padding","tight");

axList = gobjects(1,numel(audioCell));

for k = 1:numel(audioCell)
    ax = nexttile(t); % spectrogramPlotはgcaに描くのでnexttileを先に呼ぶ

    % 原稿ではキャプションを付けるので図中のタイトルは出さない
    % カラーバーは3枚共通のものを後からレイアウトに付ける
    audioCell{k}.spectrogramPlot(winSizes(k),ShowTitle=false,ShowColorbar=false);

    % 右端はデータのあるところまでに詰める。左端は0のままにしないと
    % xticksの0が範囲外になって表示されない
    tData = findobj(ax,"Type","surface").XData;
    xlim(ax,[0 max(tData(:))]);
    ylim(ax,F_VIEW); clim(ax,C_VIEW);

    % yticklabelsを明示すると"x10^3"が出なくなるので、目盛りの位置だけ指定して
    % ラベルはExponent=3による自動整形に任せる
    ax.YAxis.Exponent = 3;
    yticks(ax,F_VIEW(1):1e3:F_VIEW(2));
    xticks(ax,0:T_STEP:max(xlim(ax)));
    ax.TickLabelInterpreter = "latex";
    box(ax,"on"); % 隣どうしの境目が分かるように枠を付ける

    % 軸ラベルはtiledlayoutで3枚共通にするので、個別のものは消す
    xlabel(ax,""); ylabel(ax,"");

    ax.FontSize = FONT_TICK;
    axList(k) = ax;
end

% 3枚共通の軸ラベル
% tiledlayoutのラベルはsetDefaultIntrprの既定が効かないのでInterpreterを明示する
t.XLabel.String = "Time [s]";
t.YLabel.String = "Frequency [Hz]";
t.XLabel.Interpreter = "latex";
t.YLabel.Interpreter = "latex";
t.XLabel.FontSize = FONT_LABEL;
t.YLabel.FontSize = FONT_LABEL;

% 3枚共通のカラーバー。figureの右端に置く
c = colorbar(axList(end));
c.Layout.Tile = "east";
c.Ticks = C_VIEW(1):C_STEP:C_VIEW(2);
c.FontSize = FONT_TICK;
c.TickLabelInterpreter = "latex";

c.Label.String = "Magnitude [dB]";
c.Label.Interpreter = "latex";
c.Label.FontSize = FONT_LABEL;

%% 保存
% スペクトログラムはベクタにすると重いのでpdfもラスタで書き出す
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H,ContentType="image");
