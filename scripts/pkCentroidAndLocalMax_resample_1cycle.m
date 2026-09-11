% 2026/06/02作成
% pkCentroid_resample_1cycle.mをもとに作成
% 重心法と局所的最大値法で1周分の音声を作成し、結果を比較する

%%
% 発表資料作成用
% set(0,'defaultTextInterpreter','latex');
% set(0,'defaultAxesTickLabelInterpreter','latex');
% set(0,'defaultLegendInterpreter','latex');
% set(0,'defaultColorbarTickLabelInterpreter','latex');

setDefaultIntrpr();

%%
NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚

filenames_new = strings(NUM_IMAGES,1);
filenames_old = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames_old(i) = "DSC0" + num2str(i+112) + "_8x";
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end


L_MASK = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
TH_HIST = 150; % threshold of the peak height in the histogram

D_THRESH = 0.6;

proj = currentProject();

% 保存用
date = "0615";
dir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";

%%
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * 8; % 全部で80枚の画像

% centroid methodによる点群のx座標、y座標
% n番目のセルには、n番目のimg_smallから得た溝1本分の点群データが入る。
xcoords_cnt = cell(TOTAL_SEGMENTS,1);
ycoords_cnt = cell(TOTAL_SEGMENTS,1);

xcoords_max = cell(TOTAL_SEGMENTS,1);
ycoords_max = cell(TOTAL_SEGMENTS,1);

p2 = zeros(1,2);

W_TH = 5; % 「山」の幅の最大値（リサンプルする前の画素数）

% 画像8*l枚分のImageData, DarknessMap, GroovePointCloudクラスオブジェクト
imgData_full(TOTAL_SEGMENTS,1) = ImageData();
dValue_full(TOTAL_SEGMENTS,1) = DarknessMap();
pts_centroid_full(TOTAL_SEGMENTS,1) = GroovePointCloud();
pts_localMax_full(TOTAL_SEGMENTS,1) = GroovePointCloud();


% リサンプルしていないデータの解析
% centroid method, local maximum method両方処理する
for iImg=1:NUM_IMAGES
    % img_old = imread("./pictures/old/8x/" + filenameC_old(9-i) + ".png");
    % img_gray = rgb2gray(img_old);
    img_new = imread("./pictures/1111/original/" + filenames_new(9-iImg) + ".png");
    img_gray = rgb2gray(img_new);
    
    imgWidth = size(img_gray,2); % 1回でimgWidth(pixel)分のx座標を処理
    divImgWidth = round(imgWidth / NUM_SEGMENTS);
    xarray = [1:divImgWidth:imgWidth imgWidth+1]';

    for jSegment=1:NUM_SEGMENTS
        n = (iImg-1)*NUM_SEGMENTS+jSegment; % imgDataなどの設定時に使用

        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

        [img_omitMask,~] = omitMask(img_small, L_MASK);
        imgData = ImageData(img_omitMask, [iImg;jSegment]);

        dValue = DarknessMap(imgData);
        dValue = setDiffTF(dValue, D_THRESH);
        diffTF = dValue.diffTF;

        % startIdx, endIdxのプロット用
        sIdxC = cell(1, imgData.width);
        eIdxC = cell(1, imgData.width);

        pts_centroid = GroovePointCloud(dValue);
        pts_localMax = GroovePointCloud(dValue);

        for x=1:imgData.width
            [startIdx, endIdx] = dValue.startEndIdx(x);
            [dValue,startIdx_btm,endIdx_btm,pksNum] = ...
                dValue.grooveBtmIdx(x,startIdx,endIdx,W_TH);
            % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

            cnt_x = dValue.extractGrv_cnt(x);
            max_x = dValue.extractGrv_max(x);

            pts_centroid.peakCells{x} = [x*ones(pksNum,1), cnt_x];
            pts_localMax.peakCells{x} = [x*ones(pksNum,1), max_x];
        end

        sIdxs = vertcat(sIdxC{:});
        eIdxs = vertcat(eIdxC{:});
        pks_cnt = vertcat(pts_centroid.peakCells{:});
        pks_max = vertcat(pts_localMax.peakCells{:});

        W_PRL = imgData.width; % 平行四辺形の高さ
        H_PRL = 8; % 平行四辺形の底辺

        fig = figure;
        % fig = createFigure([0 0 6 6]);
        % imshow(img_small,"InitialMagnification","fit");
        imgData.showImage();
        hold on;
        scatter(pks_cnt(:,1),pks_cnt(:,2),3,'c','filled');
        title("Peak Dots (centroid & local maximum method)");
        % 1回の選択でpks_cnt,pks_maxの両方の傾きを補正したpksCorCellを得る
        [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,W_PRL,H_PRL,{pks_cnt,pks_max});
        pks_cnt_cor = pksCorCell{1};
        pks_max_cor = pksCorCell{2};

        BIN_WIDTH = 2; % BinWidth
        TOL_DISTANCE = 4;

        points_fit = extractGrooveWaveform(pks_cnt_cor, p1(2), (1:dValue.nCols)', ...
            BinWidth=BIN_WIDTH, MinPeakHeight=TH_HIST, Tolerance=TOL_DISTANCE);

        xcoords_cnt{n,1} = points_fit(:,1);
        ycoords_cnt{n,1} = points_fit(:,2);

        points_fit = extractGrooveWaveform(pks_max_cor, p1(2), (1:dValue.nCols)', ...
            BinWidth=BIN_WIDTH, MinPeakHeight=TH_HIST, Tolerance=TOL_DISTANCE);

        xcoords_max{n,1} = points_fit(:,1);
        ycoords_max{n,1} = points_fit(:,2);

        % save data to "~~~_full" class objects
        imgData_full(n) = imgData;
        dValue_full(n) = dValue;
        pts_centroid_full(n) = pts_centroid;
        pts_localMax_full(n) = pts_localMax;
    end
end



%%
y_cnt_raw = vertcat(ycoords_cnt{:});
y_max_raw = vertcat(ycoords_max{:});

% figure;plot(y_cnt_raw);axis tight;
% title("$y$ coordinates (centroid method)");xlabel("Sample");ylabel("$y$");
% 
% figure;plot(y_max_raw);axis tight;
% title("$y$ coordinates (local maximum method)");xlabel("Sample");ylabel("$y$");

fig = createFigure([0 0 10 6]);hold on;axis tight;
plot(y_cnt_raw);
plot(y_max_raw);
title("y coordinates from centroid method and local maximum method (not resampled)");
xlabel("samples");ylabel("$y$")

legend(["centroid method";"local maximum method"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;


saveas(fig,dir+"y_coords_of_centroid_and_localMax_methods(not_resampled)","fig");
saveas(fig,dir+"y_coords_of_centroid_and_localMax_methods(not_resampled)","png");
saveas(fig,dir+"y_coords_of_centroid_and_localMax_methods(not_resampled)","html");


%%
% produce, check, and save the audio

num_samples = length(y_cnt_raw);
fs = round(num_samples /(60/78));
y_cnt_raw = y_cnt_raw - mean(y_cnt_raw);
amp_cnt_raw = y_cnt_raw / TOL_DISTANCE;

audio_cnt = AudioData("audio from centroid method",amp_cnt_raw,fs);

fig = createFigure([0 0 6 4]);
audio_cnt.plotWaveform();
saveas(fig,dir+audio_cnt.filename+"_amp","fig");saveas(fig,dir+audio_cnt.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
audio_cnt.plotFFT();
saveas(fig,dir+audio_cnt.filename+"_fft","fig");saveas(fig,dir+audio_cnt.filename+"_fft","png");close;

fig1 = createFigure([0 0 6 6]);
audio_cnt.plotSpectrogram();title(audio_cnt.name);
saveas(fig1,dir+audio_cnt.filename+"_stft","fig");saveas(fig1,dir+audio_cnt.filename+"_stft","png");

audio_cnt.saveAudio(dir);


num_samples = length(y_max_raw);
fs = round(num_samples /(60/78));
y_max_raw = y_max_raw - mean(y_max_raw);
amp_max_raw = y_max_raw / TOL_DISTANCE;

audio_max = AudioData("audio from local maximum method",amp_max_raw,fs);

fig = createFigure([0 0 6 4]);
audio_max.plotWaveform();
saveas(fig,dir+audio_max.filename+"_amp","fig");saveas(fig,dir+audio_max.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
audio_max.plotFFT();
saveas(fig,dir+audio_max.filename+"_fft","fig");saveas(fig,dir+audio_max.filename+"_fft","png");close;

fig2 = createFigure([0 0 6 6]);
audio_max.plotSpectrogram();title(audio_max.name);
saveas(fig2,dir+audio_max.filename+"_stft","fig");saveas(fig2,dir+audio_max.filename+"_stft","png");

audio_max.saveAudio(dir);

%%
% compare the two audio
tidx = (1:length(audio_cnt.signal))'/fs;
fig = createFigure([0 0 10 6]);
hold on;axis tight;
plot(tidx,audio_cnt.signal);
plot(tidx,audio_max.signal);
title("amplitude of the produced audio (not resampled)");xlabel("time [s]");ylabel("$y$")

legend(["centroid method";"local maximum method"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;

saveas(fig,dir+"amplitude_of_centroid_and_localMax_methods(not_resampled)","fig");
saveas(fig,dir+"amplitude_of_centroid_and_localMax_methods(not_resampled)","png");


%%

xcoords_r_cnt = cell(TOTAL_SEGMENTS,1);
ycoords_r_cnt = cell(TOTAL_SEGMENTS,1);

xcoords_r_max = cell(TOTAL_SEGMENTS,1);
ycoords_r_max = cell(TOTAL_SEGMENTS,1);

p2 = zeros(1,2);

p_rsmpl = 8;
q_rsmpl = 1;

% 画像8*l枚分のImageData, DarknessMap, GroovePointCloud
dValue_r_full(TOTAL_SEGMENTS,1) = DarknessMap();
pts_r_centroid_full(TOTAL_SEGMENTS,1) = GroovePointCloud();
pts_r_localMax_full(TOTAL_SEGMENTS,1) = GroovePointCloud();

% リサンプルしたデータについて解析
for iImg=1:8
    for jSegment=1:NUM_SEGMENTS
        n = (iImg-1)*NUM_SEGMENTS+jSegment; % imgDataなどの設定時に使用
        imgData = imgData_full(n);

        dValue = dValue_full(n);
        dValue_r = dResample(dValue,p_rsmpl,q_rsmpl);
        dValue_r = setDiffTF(dValue_r,D_THRESH);

        % startIdx, endIdxのプロット用
        sIdxC = cell(1,imgData.width);
        eIdxC = cell(1,imgData.width);

        pts_centroid = GroovePointCloud(dValue_r);
        pts_localMax = GroovePointCloud(dValue_r);

        for x=1:imgData.width
            startIdx = find(dValue_r.diffTF(:,x)==1)+1;
            endIdx = find(dValue_r.diffTF(:,x)==-1);

            if endIdx(1)<startIdx(1)
                endIdx = endIdx(2:length(endIdx));
            end
            if endIdx(end)<startIdx(end)
                startIdx = startIdx(1:length(startIdx)-1);
            end

            btmIdx = find((endIdx-startIdx) < W_TH*dValue_r.scaleFactor.row...
                & (endIdx-startIdx) > 10); % 溝底に対応するstartIdxのIdxを調べる
            startIdx_btm = startIdx(btmIdx);
            endIdx_btm = endIdx(btmIdx);

            pksNum = length(btmIdx);
            max_x = zeros(pksNum,1); % x=iにおけるピーク
            cnt_x = zeros(pksNum,1); % x=iにおける重心

            sIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
            eIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];

            for k=1:pksNum % それぞれのピークの座標を求める
                D_x = dValue_r.dMat(:,x);

                idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

                if isscalar(idxs)
                    max_x(k) = idxs;
                else
                    [~,max_x(k)] = max(D_x(idxs));
                    max_x(k) = max_x(k) + startIdx_btm(k) -1 ;
                    max_x(k) = 1 + (max_x(k)-1)/dValue_r.scaleFactor.row;
                end

                sigma_D = sum(D_x(idxs));
                sigma_jxD = sum(idxs .* D_x(idxs));
                cnt_x(k) = sigma_jxD/sigma_D;
                cnt_x(k) = 1 + (cnt_x(k)-1)/dValue_r.scaleFactor.row;
            end
            pts_centroid.peakCells{x} = [x*ones(pksNum,1), cnt_x];
            pts_localMax.peakCells{x} = [x*ones(pksNum,1), max_x];
        end

        sIdxs = vertcat(sIdxC{:});
        eIdxs = vertcat(eIdxC{:});
        pks_cnt = vertcat(pts_centroid.peakCells{:});
        pks_max = vertcat(pts_localMax.peakCells{:});

        W_PRL = imgData.width; % 平行四辺形の高さ
        H_PRL = 8; % 平行四辺形の底辺

        fig = figure;
        % fig = createFigure([0 0 6 6]);
        % imshow(img_small,"InitialMagnification","fit");
        imgData.showImage();
        hold on;
        scatter(pks_cnt(:,1),pks_cnt(:,2),3,'c','filled');
        title("Peak Dots (centroid & local maximum method)");xlabel("$x$");ylabel("$y$");
        % 1回の選択でpks_cnt,pks_maxの両方の傾きを補正したpksCorCellを得る
        [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,W_PRL,H_PRL,{pks_cnt,pks_max});
        pks_cnt_cor = pksCorCell{1};
        pks_max_cor = pksCorCell{2};

        BIN_WIDTH = 2; % BinWidth
        TOL_DISTANCE = 4;

        points_fit = extractGrooveWaveform(pks_cnt_cor, p1(2), (1:dValue_r.nCols)', ...
            BinWidth=BIN_WIDTH, MinPeakHeight=TH_HIST, Tolerance=TOL_DISTANCE);

        xcoords_r_cnt{n,1} = points_fit(:,1);
        ycoords_r_cnt{n,1} = points_fit(:,2);

        % 以前はここだけdValue.width（リサンプル前）を使うコピペミスがあったが、
        % dResampleは列数を変えないため数値的には同じ結果だった。
        % 自己文書化のためdValue_r.nColsに統一する（挙動は変わらない）。
        points_fit = extractGrooveWaveform(pks_max_cor, p1(2), (1:dValue_r.nCols)', ...
            BinWidth=BIN_WIDTH, MinPeakHeight=TH_HIST, Tolerance=TOL_DISTANCE);

        xcoords_r_max{n,1} = points_fit(:,1);
        ycoords_r_max{n,1} = points_fit(:,2);

        % save data to "~_full" class objects
        dValue_r_full(n) = dValue;
        pts_r_centroid_full(n) = pts_centroid;
        pts_r_localMax_full(n,1) = pts_localMax;
    end
end
%%
y_r_cnt_raw = vertcat(ycoords_r_cnt{:});
y_r_max_raw = vertcat(ycoords_r_max{:});

fig=figure;plot(y_r_cnt_raw);axis tight;hold on;
plot(y_r_max_raw);

title("y coordinates from centroid method and local maximum method (resampled)");
xlabel("samples");ylabel("$y$")

legend(["centroid method";"local maximum method"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;

saveas(fig,dir+"y_coords_of_centroid_and_localMax_methods(resampled)","fig");
saveas(fig,dir+"y_coords_of_centroid_and_localMax_methods(resampled)","png");


%%
num_samples = length(y_r_cnt_raw);
fs = round(num_samples /(60/78));
y_r_cnt_raw = y_r_cnt_raw - mean(y_r_cnt_raw);
amp_cnt_raw = y_r_cnt_raw / TOL_DISTANCE;


audio_r_cnt = AudioData("audio from centroid method (resampled)",amp_cnt_raw,fs);

fig = createFigure([0 0 6 4]);
audio_r_cnt.plotWaveform();
saveas(fig,dir+audio_r_cnt.filename+"_amp","fig");saveas(fig,dir+audio_r_cnt.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
audio_r_cnt.plotFFT();
saveas(fig,dir+audio_r_cnt.filename+"_fft","fig");saveas(fig,dir+audio_r_cnt.filename+"_fft","png");close;

fig1 = createFigure([0 0 6 6]);
audio_r_cnt.plotSpectrogram();
saveas(fig1,dir+audio_r_cnt.filename+"_stft","fig");saveas(fig1,dir+audio_r_cnt.filename+"_stft","png");

audio_r_cnt.saveAudio(dir);


num_samples = length(y_r_max_raw);
fs = round(num_samples /(60/78));
y_r_max_raw = y_r_max_raw - mean(y_r_max_raw);
amp_max_raw = y_r_max_raw / TOL_DISTANCE;

audio_r_max = AudioData("audio from local maximum method (resampled)",amp_max_raw,fs);

fig = createFigure([0 0 6 4]);
audio_r_max.plotWaveform();
saveas(fig,dir+audio_r_max.filename+"_amp","fig");saveas(fig,dir+audio_r_max.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
audio_r_max.plotFFT();
saveas(fig,dir+audio_r_max.filename+"_fft","fig");saveas(fig,dir+audio_r_max.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
audio_r_max.plotSpectrogram();
saveas(fig,dir+audio_r_max.filename+"_stft","fig");saveas(fig,dir+audio_r_max.filename+"_stft","png");

audio_r_max.saveAudio(dir);


%%
% compare the four audio
tidx = (1:length(audio_cnt.signal))'/audio_cnt.fs;
% fig = createFigure([0 0 10 6]);
figure;
hold on;axis tight;
plot(tidx,audio_cnt.signal);
plot(tidx,audio_max.signal);
plot(tidx,audio_r_cnt.signal);
plot(tidx,audio_r_max.signal);
title("amplitude of the produced audio");xlabel("time [s]");ylabel("$y$")

legend(["centroid method (not resampled)";"local maximum method (not resampled)";...
    "centroid method (resampled)";"local maximum method (resampled)"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;

saveas(fig,dir+"amplitude_of_centroid_and_localMax_methods(BOTH)","fig");
saveas(fig,dir+"amplitude_of_centroid_and_localMax_methods(BOTH)","png");


%% 
% compare the "peak dots" of the four

for iImg=1:NUM_IMAGES
% for i=1:1
    for jSegment=1:NUM_SEGMENTS
        n = (iImg-1)*NUM_SEGMENTS+jSegment;
        imgData = imgData_full(n);
        pts_cnt = pts_centroid_full(n);
        pts_max = pts_localMax_full(n);
        pts_r_cnt = pts_r_centroid_full(n);
        pts_r_max = pts_r_localMax_full(n);

        fig = createFigure([0 0 8 10]);
        imshow(uint8(imgData.img),"InitialMagnification","fit");
        hold on;axis on;
        pts_max.showPoints();
        pts_cnt.showPoints();
        pts_r_max.showPoints();
        pts_r_cnt.showPoints();
        title("Groove Candidates (4 patterns)");xlabel("$x$");ylabel("$y$");
        
        legend(["local max (not resampled)","centroid (not resampled)",...
            "local max (resampled)","centroid (resampled)"]);
        lgd = legend;
        lgd.ItemHitFcn = @togglevisibility;

        filename = "GrvCandidatesOnImg(4patterns)_"+num2str(iImg)+"_"+num2str(jSegment);
        saveas(fig,dir+"GrvCandidates/"+filename+".fig");
        saveas(fig,dir+"GrvCandidates/"+filename+".png");
        close(fig)
    end
end

%%
% 平滑化

% リサンプルしたデータ、centroidメソッド
% amp = audio_r_cnt.signal;
% fs = audio_r_cnt.fs;

% load audio (optional)
[amp,fs] = audioread(proj.RootFolder+"\results\0615\audio_from_centroid_method_(resampled).wav");

tidx = (0:length(amp)-1)'/fs;



w_s = 5; % small window
amp_mvMean_s = movmean(amp,w_s);

w_m = 10; % medium window
amp_mvMean_m = movmean(amp,w_m);

w_l = 20;
amp_mvMean_l = movmean(amp,w_l);

figure;hold on;
plot(tidx,amp);
plot(tidx,amp_mvMean_s);
plot(tidx,amp_mvMean_m);
plot(tidx,amp_mvMean_l);
hold off;
title("Amplitude of the audio (movmean)");xlabel("t [s]");ylabel("amplitude");
legend(["original (0615)";"$w=$"+num2str(w_s);"$w=$"+num2str(w_m);"$w=$"+num2str(w_l)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

%%
mvMean_s = AudioData("audio mvMean (s)",amp_mvMean_s,fs);
mvMean_m = AudioData("audio mvMean (m)",amp_mvMean_m,fs);
mvMean_l = AudioData("audio mvMean (l)",amp_mvMean_l,fs);

date = "0710";
dir = mkdirFromDate(proj.RootFolder,date);

fig = createFigure([0 0 6 4]);
mvMean_s.plotWaveform();
saveas(fig,dir+mvMean_s.filename+"_amp","fig");saveas(fig,dir+mvMean_s.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMean_s.plotFFT();
saveas(fig,dir+mvMean_s.filename+"_fft","fig");saveas(fig,dir+mvMean_s.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMean_s.plotSpectrogram();
saveas(fig,dir+mvMean_s.filename+"_stft","fig");saveas(fig,dir+mvMean_s.filename+"_stft","png");

mvMean_s.saveAudio(dir);


fig = createFigure([0 0 6 4]);
mvMean_m.plotWaveform();
saveas(fig,dir+mvMean_m.filename+"_amp","fig");saveas(fig,dir+mvMean_m.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMean_m.plotFFT();
saveas(fig,dir+mvMean_m.filename+"_fft","fig");saveas(fig,dir+mvMean_m.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMean_m.plotSpectrogram();
saveas(fig,dir+mvMean_m.filename+"_stft","fig");saveas(fig,dir+mvMean_m.filename+"_stft","png");

mvMean_m.saveAudio(dir);


fig = createFigure([0 0 6 4]);
mvMean_l.plotWaveform();
saveas(fig,dir+mvMean_l.filename+"_amp","fig");saveas(fig,dir+mvMean_l.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMean_l.plotFFT();
saveas(fig,dir+mvMean_l.filename+"_fft","fig");saveas(fig,dir+mvMean_l.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMean_l.plotSpectrogram();
saveas(fig,dir+mvMean_l.filename+"_stft","fig");saveas(fig,dir+mvMean_l.filename+"_stft","png");

mvMean_l.saveAudio(dir);

%%
amp_mvMedian_s = movmedian(amp,w_s);
amp_mvMedian_m = movmedian(amp,w_m);
amp_mvMedian_l = movmedian(amp,w_l);

figure;hold on;
plot(tidx,amp);
plot(tidx,amp_mvMedian_s);
plot(tidx,amp_mvMedian_m);
plot(tidx,amp_mvMedian_l);
hold off;
title("Amplitude of the audio (movmedian)");xlabel("t [s]");ylabel("amplitude");
legend(["original (0615)";"$w=$"+num2str(w_s);"$w=$"+num2str(w_m);"$w=$"+num2str(w_l)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

%%
mvMedian_s = AudioData("audio mvMedian (s)",amp_mvMedian_s,fs);
mvMedian_m = AudioData("audio mvMedian (m)",amp_mvMedian_m,fs);
mvMedian_l = AudioData("audio mvMedian (l)",amp_mvMedian_l,fs);

date = "0710";
dir = mkdirFromDate(proj.RootFolder,date);

fig = createFigure([0 0 6 4]);
mvMedian_s.plotWaveform();
saveas(fig,dir+mvMedian_s.filename+"_amp","fig");saveas(fig,dir+mvMedian_s.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMedian_s.plotFFT();
saveas(fig,dir+mvMedian_s.filename+"_fft","fig");saveas(fig,dir+mvMedian_s.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMedian_s.plotSpectrogram();
saveas(fig,dir+mvMedian_s.filename+"_stft","fig");saveas(fig,dir+mvMedian_s.filename+"_stft","png");

mvMedian_s.saveAudio(dir);


fig = createFigure([0 0 6 4]);
mvMedian_m.plotWaveform();
saveas(fig,dir+mvMedian_m.filename+"_amp","fig");saveas(fig,dir+mvMedian_m.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMedian_m.plotFFT();
saveas(fig,dir+mvMedian_m.filename+"_fft","fig");saveas(fig,dir+mvMedian_m.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMedian_m.plotSpectrogram();
saveas(fig,dir+mvMedian_m.filename+"_stft","fig");saveas(fig,dir+mvMedian_m.filename+"_stft","png");

mvMedian_m.saveAudio(dir);


fig = createFigure([0 0 6 4]);
mvMedian_l.plotWaveform();
saveas(fig,dir+mvMedian_l.filename+"_amp","fig");saveas(fig,dir+mvMedian_l.filename+"_amp","png");close;

fig = createFigure([0 0 6 4]);
mvMedian_l.plotFFT();
saveas(fig,dir+mvMedian_l.filename+"_fft","fig");saveas(fig,dir+mvMedian_l.filename+"_fft","png");close;

fig = createFigure([0 0 6 6 ]);
mvMedian_l.plotSpectrogram();
saveas(fig,dir+mvMedian_l.filename+"_stft","fig");saveas(fig,dir+mvMedian_l.filename+"_stft","png");

mvMedian_l.saveAudio(dir);



%%
% compare the waveforms of stylus playback and the produced audio
% forgot to save the AudioData objects in the previous section
% so read the audio from .wav file and analyze them

dir = "data/stylus playback/";
[amp_stylus,fs_stylus] = audioread(dir+"StylusPlayback(wa)(highpass).wav");
tidx_stylus = (0:length(amp_stylus)-1)'/fs_stylus;

audio_stylus = AudioData("stylus playback(wa)",amp_stylus,fs_stylus);

% compare the results from mvmean() and mvmedian()
figure;hold on;
plot(tidx,amp);axis tight;
plot(tidx,amp_mvMean_s);
plot(tidx,amp_mvMedian_s);
hold off;
title("Amplitude of the audio");xlabel("t [s]");ylabel("amplitude");
legend(["original (0615)";"mvmean $w=$"+num2str(w_s);"mvmedian $w=$"+num2str(w_s)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

figure;hold on;
plot(tidx,amp);axis tight;
plot(tidx,amp_mvMean_m);
plot(tidx,amp_mvMedian_m);
hold off;
title("Amplitude of the audio");xlabel("t [s]");ylabel("amplitude");
legend(["original (0615)";"mvmean $w=$"+num2str(w_m);"mvmedian $w=$"+num2str(w_m)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;


figure;hold on;
plot(tidx,amp);axis tight;
plot(tidx,amp_mvMean_l);
plot(tidx,amp_mvMedian_l);
hold off;
title("Amplitude of the audio");xlabel("t [s]");ylabel("amplitude");
legend(["original (0615)";"mvmean $w=$"+num2str(w_l);"mvmedian $w=$"+num2str(w_l)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

%%
figure;hold on;
plot(tidx_stylus,amp_stylus);
plot(tidx,amp);
plot(tidx,amp_mvMean_l);
plot(tidx,amp_mvMedian_l);
hold off;
title("Amplitude of the audio");xlabel("t [s]");ylabel("amplitude");
legend(["stylus playback";"original (0615)";"mvmean $w=$"+num2str(w_l);"mvmedian $w=$"+num2str(w_m)]);
lgd = legend; lgd.ItemHitFcn = @togglevisibility;

