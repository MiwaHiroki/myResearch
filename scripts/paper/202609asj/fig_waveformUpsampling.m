% fig_waveformUpsampling.m
% 音響学会202609の原稿に使用，1段幅(79mm)
% fig6_spectrogramUpsampling.mをもとに作成
% 従来法 / rsmplD / intpDから作成した音声の波形を
% tiledlayoutで横に3枚並べて1つのfigureにする
% rsmplD, intpDに関しては重心法を使用。
% 従来法 = 既製の画像編集ソフトで高解像度化した画像から、局所的最大値法で
% 溝形状を抽出して作成した音声
% rsmplD/intpDの音声はsaveCycleResultで保存した1周分の結果.matから読み込む
% 従来法は1周分の結果.matが無くAudioDataだけなので、別の.matから読み込む
% =======================================
% ユーザーによる追記: 従来法の結果は，saveCycleResultによって保存された
% 1x1 structである。
% S = load(CONV_MAT);としたとき，AudioDataはS.result.localMax.audioに記録されている。
% =======================================


setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_waveformUpsampling";

%% パラメータ
% 読み込む結果.mat（experiments/<日付>/cycleResult_<条件>_<日付>.mat）
DATE = "0731";
UPSAMPLINGS = ["rsmplD","intpD"]; % 中央がrsmplD、右がintpD
METHOD = "centroid";              % 溝底抽出の手法は固定して高解像度化だけを比べる

CONV_DATE = "0802";
% 従来法の音声。AudioDataを1つ入れた.matを想定している
% ユーザーによる追記: 従来法の音声についてはスクリプト冒頭を参照のこと
CONV_MAT = fullfile(proj.RootFolder,"experiments",CONV_DATE, ...
    "cycleResult_origD_"+CONV_DATE+".mat");
CONV_VAR = "audio"; % .mat内のAudioDataの変数名, ただしS.result.localMaxのフィールド
CONV_VAR_YCOORDS = "ycoords";
CONV_NAME = "conventional"; % 表示・ログ用の名前

Y_VIEW = [-1 1]; % 表示するAmplitudeの範囲
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
FIG_W = 7.9; FIG_H = 3;
FONT_TICK = 8; FONT_LABEL = 9;

%% 音声データを読み込む
% 一番左が従来法、その右がUPSAMPLINGSの順
audioCell = cell(1,1+numel(UPSAMPLINGS));
audioNames = [CONV_NAME, UPSAMPLINGS + " / " + METHOD];

% 従来法
if ~isfile(CONV_MAT)
    error("fig:noConventionalFile", ...
        "従来法の音声が見つかりません: %s\n" + ...
        "既製ソフトで高解像度化した画像から局所的最大値法で作成した音声を、" + ...
        "変数名 %s のAudioDataとしてこのパスに保存してください。", ...
        CONV_MAT, CONV_VAR);
end

% S = load(CONV_MAT);
if ~isfield(S.result.localMax,(CONV_VAR_YCOORDS))
    error("fig:noConventionalVar", ...
        "%s に変数 %s がありません。", CONV_MAT, CONV_VAR);
end
if ~isa(S.result.localMax.(CONV_VAR),"AudioData")
    error("fig:notAudioData", ...
        "%s の %s はAudioDataではありません（%s）。", ...
        CONV_MAT, CONV_VAR, class(S.(CONV_VAR)));
end
audioCell{1} = S.result.localMax.(CONV_VAR);

% メモリが確保しきれないとき
% clear S;

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

%% 描画
% カラーバーはTightInsetに含まれないので、tiledlayoutのPadding="tight"に
% 余白を任せる（カラーバーをレイアウトのタイルに置くと、そのぶんの余白が確保される）
fig = createFigure([0 0 FIG_W FIG_H]);

t = tiledlayout(fig,1,numel(audioCell),"TileSpacing","tight","Padding","tight");

axList = gobjects(1,numel(audioCell));

for k = 1:numel(audioCell)
    ax = nexttile(t); % spectrogramPlotはgcaに描くのでnexttileを先に呼ぶ

    % 原稿ではキャプションを付けるので図中のタイトルは出さない
    % カラーバーは3枚共通のものを後からレイアウトに付ける
    audioCell{k}.audioPlot();

    % 右端はデータのあるところまでに詰める。左端は0のままにしないと
    % xticksの0が範囲外になって表示されない
    tData = findobj(ax,"Type","line").XData;
    xlim(ax,[0 max(tData(:))]);
    ylim(ax,Y_VIEW);

    xticks(ax,0:T_STEP:max(xlim(ax)));
    ax.TickLabelInterpreter = "latex";
    box(ax,"on"); % 隣どうしの境目が分かるように枠を付ける

    % タイトルは必要ないので消す
    title(ax,"");
    % 軸ラベルはtiledlayoutで3枚共通にするので、個別のものは消す
    xlabel(ax,""); ylabel(ax,"");

    ax.FontSize = FONT_TICK;
    axList(k) = ax;
end

% 3枚共通の軸ラベル
% tiledlayoutのラベルはsetDefaultIntrprの既定が効かないのでInterpreterを明示する
t.XLabel.String = "Time [s]";
t.YLabel.String = "Amplitude";
t.XLabel.Interpreter = "latex";
t.YLabel.Interpreter = "latex";
t.XLabel.FontSize = FONT_LABEL;
t.YLabel.FontSize = FONT_LABEL;


%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
