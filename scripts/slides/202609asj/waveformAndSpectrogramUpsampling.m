% spectrogramUpsampling.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig6_spectrogramUpsampling.mと同じデータ
% (従来法・rsmplD・intpD、いずれも重心法)を使い、各音声の波形とスペクトログラムを
% 1図1ファイルのpngとして書き出す（計6枚）
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （tiledlayoutでまとめない、タイトル無し、カラーバーは図ごとに必須、pngのみ保存）
%
% 従来法 = 既製の画像編集ソフトで高解像度化した画像から、重心法で
% 溝形状を抽出して作成した音声（原稿版のコメント参照。0802のデータのみ現存）
% rsmplD/intpDの音声はsaveCycleResultで保存した1周分の結果.matから読み込む

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

% intpDはx方向も補間するのでfsがrsmplDの8倍になる。窓長をサンプル数で揃えると
% 窓が覆う時間と周波数分解能がずれるので、fsに比例させて時間長を揃える
WIN_SIZE_REF = 1024; % rsmplDのfsに対する窓長[サンプル]

F_VIEW = [0 5e3];  % 表示する周波数の範囲[Hz]
% F_VIEW = [0 2e4];  % 20kHzまで表示する場合
C_VIEW = [-120 0]; % 表示するレベルの範囲[dB]
C_STEP = 30;       % カラーバーの目盛り間隔[dB]
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]
Y_VIEW = [-1 1];   % 表示するAmplitudeの範囲

% 図のサイズ[cm]とフォントサイズ[pt]（スライド用の標準値）
% 波形表示figure、スペクトログラム表示figureの大きさ
FIG_W = [8.2, 8] ; FIG_H = [6, 10];
FONT_TICK = 14; FONT_LABEL = 16;

%% 音声データを読み込む
% 従来法、rsmplD、intpDの順
audioCell = cell(1,1+numel(UPSAMPLINGS));
% ファイル名はスクリプト名から由来が分かるので接頭辞は付けず、
% 区別に必要なupsampling条件だけを名前にする（手法は全条件でcentroid固定）
audioNames = [CONV_NAME, UPSAMPLINGS];

% 従来法
if ~isfile(CONV_MAT)
    error("fig6:noConventionalFile", ...
        "従来法の音声が見つかりません: %s\n" + ...
        "既製ソフトで高解像度化した画像から重心法で作成した音声を、" + ...
        "変数名 %s のAudioDataとしてこのパスに保存してください。", ...
        CONV_MAT, CONV_VAR);
end

S = load(CONV_MAT);
if ~isfield(S.result.(CONV_METHOD),(CONV_VAR))
    error("fig6:noConventionalVar", ...
        "%s に変数 %s がありません。", CONV_MAT, CONV_VAR);
end
if ~isa(S.result.(CONV_METHOD).(CONV_VAR),"AudioData")
    error("fig6:notAudioData", ...
        "%s の %s はAudioDataではありません（%s）。", ...
        CONV_MAT, CONV_VAR, class(S.result.(CONV_METHOD).(CONV_VAR)));
end
audioCell{1} = S.result.(CONV_METHOD).(CONV_VAR);

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

%% 描画・保存（音声ごとに波形・スペクトログラムを別ファイルにする）
for k = 1:numel(audioCell)
    audio = audioCell{k};
    name = audioNames(k);

    % 波形
    fig = createFigure([0 0 FIG_W(1) FIG_H(1)]);
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
    saveSlideFigure(fig,saveDir,name+"_waveform",FIG_W(1),FIG_H(1));

    % スペクトログラム（カラーバーは図ごとに必須）
    % tiledlayout+Padding="tight"でカラーバー分の余白を確保する。単体axesの
    % 自動レイアウトはfigureを縮めるとカラーバーのラベルが見切れることがある
    fig = createFigure([0 0 FIG_W(2) FIG_H(2)]);
    t = tiledlayout(fig,1,1,"Padding","tight");
    ax = nexttile(t); % plotSpectrogramはgcaに描くのでnexttileを先に呼ぶ
    audio.plotSpectrogram(winSizes(k),ShowTitle=false,ShowColorbar=false);

    tData = findobj(ax,"Type","surface").XData;
    xlim(ax,[0 max(tData(:))]);
    ylim(ax,F_VIEW); clim(ax,C_VIEW);

    ax.YAxis.Exponent = 3;
    yticks(ax,F_VIEW(1):1e3:F_VIEW(2));
    % yticks(ax,F_VIEW(1):5e3:F_VIEW(2)); % F_VIEWが20kHzまでのとき
    xticks(ax,0:T_STEP:max(xlim(ax)));
    ax.TickLabelInterpreter = "latex";
    box(ax,"on");

    xlabel(ax,"Time [s]"); ylabel(ax,"Frequency [Hz]");
    ax.FontSize = FONT_TICK;
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;

    % c = colorbar(ax);
    % c.Layout.Tile = "east";
    % c.Ticks = C_VIEW(1):C_STEP:C_VIEW(2);
    % c.FontSize = FONT_TICK;
    % c.TickLabelInterpreter = "latex";
    % c.Label.String = "Magnitude [dB]";
    % c.Label.Interpreter = "latex";
    % c.Label.FontSize = FONT_LABEL;

    saveSlideFigure(fig,saveDir,name+"_spectrogram_noColorbar_5kHz",FIG_W(2),FIG_H(2));
    % saveSlideFigure(fig,saveDir,name+"_spectrogram_noColorbar_20kHz",FIG_W(2),FIG_H(2));
end
