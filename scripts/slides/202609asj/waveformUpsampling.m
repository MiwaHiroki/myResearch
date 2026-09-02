% waveformUpsampling.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig_waveformUpsampling.mと同じデータ
% (従来法・rsmplD・intpD、いずれも重心法)を使い、各音声の波形を
% 1図1ファイルのpngとして書き出す（計3枚）
% 元スクリプトはtiledlayoutで3枚を1つのfigureにまとめていたが、
% スライド用の図の様式（memory: slide-figure-size / slide-figure-dirs）に
% 合わせて1図1ファイルに分ける（タイトル無し、pngのみ保存）
%
% 従来法 = 既製の画像編集ソフトで高解像度化した画像から、重心法で
% 溝形状を抽出して作成した音声（0802のデータのみ現存）
% rsmplD/intpDの音声はsaveCycleResultで保存した1周分の結果.matから読み込む
%
% 元スクリプトの従来法読み込み部分は「S = load(CONV_MAT);」がコメントアウトされたまま
% 「CONV_VAR_YCOORDS」という未定義変数を参照するバグがあったため、
% fig6_spectrogramUpsampling.mの正しい実装に合わせて修正している

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
% 読み込む結果.mat（experiments/<日付>/cycleResult_<条件>_<日付>.mat）
DATE = "0731";
UPSAMPLINGS = ["rsmplD","intpD"];
METHOD = "centroid"; % 溝底抽出の手法は固定して高解像度化だけを比べる

CONV_DATE = "0802";
CONV_MAT = fullfile(proj.RootFolder,"experiments",CONV_DATE, ...
    "cycleResult_origD_"+CONV_DATE+".mat");
CONV_METHOD = "centroid";
CONV_VAR = "audio"; % .mat内のAudioDataの変数名, ただしS.result.(CONV_METHOD)のフィールド
CONV_NAME = "conventional"; % 表示・ログ用の名前

Y_VIEW = [-1 1]; % 表示するAmplitudeの範囲
T_STEP = 0.2;    % 時間軸の目盛り間隔[s]

% 図のサイズ[cm]とフォントサイズ[pt]
FIG_W = 8; FIG_H = 6;
FONT_TICK = 14; FONT_LABEL = 16;

%% 音声データを読み込む
% 一番目が従来法、その後がUPSAMPLINGSの順
audioCell = cell(1,1+numel(UPSAMPLINGS));
% ファイル名はスクリプト名から由来が分かるので接頭辞は付けず、
% 区別に必要なupsampling条件だけを名前にする（手法は全条件でcentroid固定）
audioNames = [CONV_NAME, UPSAMPLINGS];

% 従来法
if ~isfile(CONV_MAT)
    error("waveformUpsampling:noConventionalFile", ...
        "従来法の音声が見つかりません: %s\n" + ...
        "既製ソフトで高解像度化した画像から重心法で作成した音声を、" + ...
        "変数名 %s のAudioDataとしてこのパスに保存してください。", ...
        CONV_MAT, CONV_VAR);
end

S = load(CONV_MAT);
if ~isfield(S.result.(CONV_METHOD),(CONV_VAR))
    error("waveformUpsampling:noConventionalVar", ...
        "%s に変数 %s がありません。", CONV_MAT, CONV_VAR);
end
if ~isa(S.result.(CONV_METHOD).(CONV_VAR),"AudioData")
    error("waveformUpsampling:notAudioData", ...
        "%s の %s はAudioDataではありません（%s）。", ...
        CONV_MAT, CONV_VAR, class(S.result.(CONV_METHOD).(CONV_VAR)));
end
audioCell{1} = S.result.(CONV_METHOD).(CONV_VAR);

% rsmplD, intpD
for k = 1:numel(UPSAMPLINGS)
    matPath = cycleResultPath(proj.RootFolder,UPSAMPLINGS(k),DATE);
    result = loadCycleResult(matPath);

    if ~isfield(result,METHOD) || isempty(result.(METHOD).audio)
        error("waveformUpsampling:noAudio", ...
            "%s に %s の音声が入っていません。", matPath, METHOD);
    end
    audioCell{1+k} = result.(METHOD).audio;
end

% どの音声を読んだかを残す（保存時に手法を取り違えていないかの確認用）
for k = 1:numel(audioCell)
    fprintf("%s: name=""%s"", fs=%d Hz\n", ...
        audioNames(k), audioCell{k}.name, audioCell{k}.fs);
end

%% 描画・保存（音声ごとに別ファイルにする）
figNames = "waveformUpsampling_" + audioNames;

for k = 1:numel(audioCell)
    audio = audioCell{k};

    fig = createFigure([0 0 FIG_W FIG_H]);
    ax = gca;
    audio.plotWaveform();

    % 右端はデータのあるところまでに詰める。左端は0のままにしないと
    % xticksの0が範囲外になって表示されない
    tData = findobj(ax,"Type","line").XData;
    xlim(ax,[0 max(tData(:))]);
    ylim(ax,Y_VIEW);

    xticks(ax,0:T_STEP:max(xlim(ax)));
    ax.TickLabelInterpreter = "latex";
    box(ax,"on");

    % plotWaveformは強制的にタイトルを付けるのでスライド用に消す
    title(ax,"");
    xlabel(ax,"Time [s]"); ylabel(ax,"Amplitude");

    ax.FontSize = FONT_TICK;
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;

    tightenAxes(ax);
    saveSlideFigure(fig,saveDir,figNames(k),FIG_W,FIG_H);
end
