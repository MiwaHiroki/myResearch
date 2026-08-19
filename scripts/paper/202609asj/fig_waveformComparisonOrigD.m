% fig_waveformComparisonOrigD
% fig5_spectrogramComparison.mと% fig_waveformUpsampling.mをもとに作成
% origD(高解像度化なし)から局所的最大値法・重心法で作成した音声の波形を
% tiledlayoutで横に並べて1つのfigureにする
% 軸ラベルは2枚で共通にする
% タイトル不要
% 音声はsaveCycleResultで保存した1周分の結果.matから読み込む


setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_waveformComparisonOrigD";

%% パラメータ
% 読み込む結果.mat（experiments/<日付>/cycleResult_<条件>_<日付>.mat）
DATE = "0731";
UPSAMPLING = "origD";

Y_VIEW = [-1 1]; % 表示するAmplitudeの範囲
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]

% 図のサイズ[cm]とフォントサイズ[pt]（原稿は10pt二段組、1段幅=79mm）
FIG_W = 8; FIG_H = 3;
FONT_TICK = 8; FONT_LABEL = 9;


%% 音声データを読み込む
matPath = cycleResultPath(proj.RootFolder,UPSAMPLING,DATE);
result = loadCycleResult(matPath);

for methodName = ["localMax","centroid"]
    if ~isfield(result,methodName) || isempty(result.(methodName).audio)
        error("fig5:noAudio", ...
            "%s に %s の音声が入っていません。", matPath, methodName);
    end
end

% 左が局所的最大値法、右が重心法
audioCell = {result.localMax.audio, result.centroid.audio};

%% 描画
% カラーバーはTightInsetに含まれないので、tiledlayoutのPadding="tight"に
% 余白を任せる（カラーバーをレイアウトのタイルに置くと、そのぶんの余白が確保される）
fig = createFigure([0 0 FIG_W FIG_H]);

t = tiledlayout(fig,1,numel(audioCell),"TileSpacing","tight","Padding","compact");

axList = gobjects(1,numel(audioCell));

for k = 1:numel(audioCell)
    ax = nexttile(t); % plotSpectrogramはgcaに描くのでnexttileを先に呼ぶ

    audioCell{k}.plotWaveform();

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

% 2枚共通の軸ラベル
% tiledlayoutのラベルはsetDefaultIntrprの既定が効かないのでInterpreterを明示する
t.XLabel.String = "Time [s]";
t.YLabel.String = "Amplitude";
t.XLabel.Interpreter = "latex";
t.YLabel.Interpreter = "latex";
t.XLabel.FontSize = FONT_LABEL;
t.YLabel.FontSize = FONT_LABEL;


%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);



