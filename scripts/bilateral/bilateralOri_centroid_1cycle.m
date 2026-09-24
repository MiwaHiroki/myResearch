% bilateralOri_centroid_1cycle.m
% 高解像度化を行っていない画像(*-ori.png)にバイラテラルフィルタをかけ、
% カーネルサイズごとに1周分(80セグメント)の音声を重心法で作成して比較する。
%
% scripts/bilateral/の4本で1セグメントの溝底点を見た結果、フィルタなしで出る
% 孤立した誤検出点がフィルタで消えることは分かったが、それが1周分の波形・音質に
% どう効くかは分からない。ノイズが減るのか、溝底が鈍って波形がなまるのか、
% カーネルを大きくしたときにどこで破綻するかを、実際の音として確認する。
%
% 高解像度化は行わない(origD)。元画像の輝度は8bitの階調を持つが、サブピクセルで
% 補間した暗度はもう8bit階調ではないため、そこへバイラテラルフィルタをかけるのは
% 筋が悪い。dResample/dInterpとの組み合わせは別途議論する。
%
% 溝の選択(fitGrooveのp1,p2)はPREV_RESULT_PATHの結果から再利用するのでginputは
% 一度も呼ばれない。全条件で同一の溝を見るため、比較として正確になる。
%
% 画像は毎回imreadから読む。PREV_RESULT_PATHのcycleResultにはおそらくallImg
% (img入り)が保存されているためそこから画像を流用することも可能だが、今後は
% allImgが空(imgを保存しない・issue#17)の結果を読み込むことも考えられるので、
% 毎img_grayについて画像の読み込みから行う。結果から取るのはgrooveSelectionだけ。
%
% 実験結果(.mat)は保存しない。今回は動作確認が目的であり、カーネルサイズを
% 構造化して残す枠がcycleConditionsに無い(Upsamplingは3値に限定、自由記述はNoteのみ)
% ため、保存するならsaveCycleResult側を直してcycleResultの中身を変えるほうが筋が良い。
%
% 出力（results/<日付>/bilateral1cycle/）:
%   audio_(centroid)(bilateral_<cond>).wav          条件ごとの音声
%   audio_(centroid)(bilateral_<cond>)_amp/_fft/_stft.fig/.png
%   compare_waveform.fig/.png     4条件の波形の重ね合わせ
%   compare_fft.fig/.png          4条件のFFTの重ね合わせ
%   compare_spectrogram.fig/.png  4条件のスペクトログラム(2x2)

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

NUM_IMAGES = 8;     % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10;  % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * NUM_IMAGES;

filenames_new = strings(NUM_IMAGES,1);
for i = 1:NUM_IMAGES
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end

%% パラメータ（pkCentroid_1cycle.mと同値）
L_MASK = 20;      % Maskを取るためのluminanceのthreshold, 0付近に設定する
TH_HIST = 150;    % threshold of the peak height in the histogram
D_THRESH = 0.6;   % 暗度の閾値
WIDTH_THRESH = 8; % 溝底とみなす区間幅の上限[px]

tol = 3;          % 溝1本に含める点のy方向の許容幅
binWidth = 5;     % findGrooveCenterのヒストグラムのビン幅
h_prl = 8;        % fitGrooveの平行四辺形の高さ

% バイラテラルフィルタ（bilateralOri_centroid.mと同値）
KERNEL_SIZES = [3 5 9];               % NeighborhoodSize（3通り、奇数）
SPATIAL_SIGMAS = (KERNEL_SIZES-1)/4;  % 既定 N=2*ceil(2*sigma)+1 の逆算 -> [0.5 1 2]
DEGREE_OF_SMOOTHING = 0.01*255^2;     % uint8入力に対するimbilatfiltの既定値と同値

% 比較図で波形を拡大表示する区間[s]（全体表示だと4条件が重なって読めないため）
ZOOM_SEC = [0.30 0.32];

% 保存先（図・音声）
date = "0924";
saveDir = fullfile(mkdirFromDate(rootFolder,date),"bilateral1cycle");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
saveDir = saveDir + filesep; % saveas/saveAudioが文字列連結するため末尾に区切りを付ける

%% 溝の選択（p1,p2）を過去の結果から読み込む
% 全条件で同じ溝を見たいので手動選択（ginput）は使わない。
PREV_RESULT_PATH = fullfile(rootFolder,"experiments","0807","cycleResult_rsmplD_0807.mat");
prevResult = loadCycleResult(PREV_RESULT_PATH);
grooveSelection = prevResult.grooveSelection;
if ~isequal(size(grooveSelection.p1),[TOTAL_SEGMENTS 2]) || ...
        ~isequal(size(grooveSelection.p2),[TOTAL_SEGMENTS 2])
    error("bilateralOri_centroid_1cycle:badGrooveSelection", ...
        "%s のgrooveSelectionが %dx2 ではありません。", PREV_RESULT_PATH, TOTAL_SEGMENTS);
end
clear prevResult

%% 条件の定義（フィルタなし＋カーネル3通り）
numConds = numel(KERNEL_SIZES) + 1;
condLabels = strings(numConds,1);
condLabels(1) = "none";
for iCond = 2:numConds
    condLabels(iCond) = "k" + sprintf("%02d",KERNEL_SIZES(iCond-1));
end

xcoords = cell(numConds,1);
ycoords = cell(numConds,1);
for iCond = 1:numConds
    xcoords{iCond} = cell(TOTAL_SEGMENTS,1);
    ycoords{iCond} = cell(TOTAL_SEGMENTS,1);
end

%% 80セグメント × 4条件の溝形状抽出
p2 = zeros(1,2); % fitGrooveの引数。P1/P2を渡すので実際には使われない

for iImg = 1:NUM_IMAGES
    tImg = tic;
    img_gray = rgb2gray(imread(filenames_new(9-iImg) + ".png")); % 9-iImgで外周から順に読む

    imgWidth = size(img_gray,2);
    divImgWidth = round(imgWidth / NUM_SEGMENTS);
    xarray = [1:divImgWidth:imgWidth imgWidth+1]';

    for jSegment = 1:NUM_SEGMENTS
        kImgSmall = (iImg-1)*NUM_SEGMENTS + jSegment;

        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);
        % フィルタはomitMaskの後にかける。マスクの黒（輝度<=L_MASK）を
        % 平滑化に巻き込まないため。
        [img_omitMask,~] = omitMask(img_small, L_MASK);

        for iCond = 1:numConds
            if iCond == 1
                img_cond = img_omitMask; % ベースライン（フィルタなし）
            else
                img_cond = imbilatfilt(img_omitMask, DEGREE_OF_SMOOTHING, ...
                    SPATIAL_SIGMAS(iCond-1), "NeighborhoodSize", KERNEL_SIZES(iCond-1));
            end

            imgData = ImageData(img_cond, [iImg;jSegment]);
            map = DarknessMap(imgData);
            map = map.setDiffTF(D_THRESH);

            pts_cnt = GroovePointCloud(map);
            extractor = GrooveExtractor(map);
            for x = 1:map.nCols
                [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
                [extractor,~,~,numPeaks] = ...
                    extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH);
                pts_cnt.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(map,x)];
            end
            pks_cnt = vertcat(pts_cnt.peakCells{:});

            % 溝の選択は常に自動（figureを作らない）。重心法だけなのでpksCellは1要素
            w_prl = imgData.width;
            [~,~,pksCorCell] = fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_cnt}, ...
                P1=grooveSelection.p1(kImgSmall,:), P2=grooveSelection.p2(kImgSmall,:));

            % フィルタで検出点数が変わるとfindGrooveCenterがヒストグラムのピークを
            % 見つけられずに落ちることがあるので、どの条件・どのセグメントかを添える
            try
                points_fit = extractGrooveWaveform(pksCorCell{1}, ...
                    grooveSelection.p1(kImgSmall,2), (1:map.nCols)', ...
                    BinWidth=binWidth, MinPeakHeight=TH_HIST, Tolerance=tol);
            catch ME
                newME = MException("bilateralOri_centroid_1cycle:extractFailed", ...
                    "条件 %s, セグメント %d (iImg=%d, jSegment=%d) で溝形状の抽出に失敗しました。", ...
                    condLabels(iCond), kImgSmall, iImg, jSegment);
                throw(addCause(newME,ME));
            end

            xcoords{iCond}{kImgSmall} = points_fit(:,1);
            ycoords{iCond}{kImgSmall} = points_fit(:,2);
        end
    end
    fprintf("image %d/%d done (%.1f s)\n", iImg, NUM_IMAGES, toc(tImg));
end

%% 条件ごとに1周分の音声を作る
% AudioDataは引数なしのコンストラクタを持たないので事前確保はせず、
% iCond=1から順に代入して配列を伸ばす
for iCond = 1:numConds
    y_comb = vertcat(ycoords{iCond}{:});

    num_samples = length(y_comb);
    fs = round(num_samples / (60/78)); % 78rpm -> 1周 60/78 秒

    amp = (y_comb - mean(y_comb)) / (tol/2);

    audios(iCond) = AudioData("audio (centroid)(bilateral "+condLabels(iCond)+")", amp, fs);

    fprintf("%-6s : %d samples, fs = %d Hz, max|amp| = %.2f\n", ...
        condLabels(iCond), num_samples, fs, max(abs(amp)));

    fig = figure; audios(iCond).plotWaveform();
    saveas(fig,saveDir+audios(iCond).filename+"_amp","fig");
    saveas(fig,saveDir+audios(iCond).filename+"_amp","png"); close;

    fig = figure; audios(iCond).plotFFT();
    saveas(fig,saveDir+audios(iCond).filename+"_fft","fig");
    saveas(fig,saveDir+audios(iCond).filename+"_fft","png"); close;

    fig = figure; audios(iCond).plotSpectrogram(1024);
    saveas(fig,saveDir+audios(iCond).filename+"_stft","fig");
    saveas(fig,saveDir+audios(iCond).filename+"_stft","png"); close;

    audios(iCond).saveAudio(saveDir);
end

%% 比較図1: 波形の重ね合わせ
fig = figure;
hold on;
for iCond = 1:numConds
    audios(iCond).plotWaveform();
end
hold off;
title("amplitude (centroid, bilateral filter)"); % plotWaveformが付けたtitleを上書きする
legend(condLabels);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;
saveas(fig,saveDir+"compare_waveform","fig");
saveas(fig,saveDir+"compare_waveform","png");

%% 比較図1-2: 波形の重ね合わせ（拡大）
fig = figure;
hold on;
for iCond = 1:numConds
    audios(iCond).plotWaveform();
end
hold off;
title("amplitude (centroid, bilateral filter)");
xlim(ZOOM_SEC); ylim("auto");
legend(condLabels);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;
saveas(fig,saveDir+"compare_waveform_zoom","fig");
saveas(fig,saveDir+"compare_waveform_zoom","png");

%% 比較図2: FFTの重ね合わせ
fig = figure;
hold on;
for iCond = 1:numConds
    audios(iCond).plotFFT();
end
hold off;
title("FFT (centroid, bilateral filter)");
legend(condLabels);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;
saveas(fig,saveDir+"compare_fft","fig");
saveas(fig,saveDir+"compare_fft","png");

%% 比較図3: スペクトログラム（重ねられないので2x2に並べる）
fig = figure;
tl = tiledlayout(fig,2,2,"TileSpacing","compact","Padding","tight");
for iCond = 1:numConds
    nexttile(tl);
    audios(iCond).plotSpectrogram(1024,ShowTitle=false,ShowColorbar=false);
    title(condLabels(iCond));
end
title(tl,"Spectrogram (centroid, bilateral filter)");
saveas(fig,saveDir+"compare_spectrogram","fig");
saveas(fig,saveDir+"compare_spectrogram","png");
