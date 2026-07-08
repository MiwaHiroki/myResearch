% "Ncycle.m"からのコピー
% 黒いマスクが完全になくなるようにする

filenameC = cell(8,1);
for j=1:8
    % filenameC{j} = "DSC0" + num2str(j+112) + "_8x";
    filenameC{j} = "DSC1111-0000" + num2str(j) + "-8x";
end

laps = 1; % 何周分を音データにするか

% 画像8枚分のデータを縦に1周分ずつ格納するCell
% Cはcell配列であることを意味する
amplitudeC = cell(8,laps);
x_combC = cell(8,laps);
y_combC = cell(8,laps);

imgWidth = 3000; % 1回でimgWidth(pixel)分のx座標を処理
xarray = [1:imgWidth:30000 30001];
% 切り出す画像(img_small)の左端のx座標
% 便宜的に（画像の横のサイズ+1）を加えておく
l = length(xarray)-1;

minh = 0.0;maxh = 0.5; % Min & MaxPeakHeight
mind = 50; % MinPeakDistance
minp = 0.2; % MinPeakProminence

% 計8枚の写真をそれぞれl分割した画像から得たx,y座標を格納
% 各列にlap周目の座標データが入る
xcoords = cell(8*l,laps);
ycoords_raw = cell(8*l,laps);

p2 = zeros(2,1);

th_mask = 20; 
% maskを取り除くための閾値。0付近に設定する。
% 8倍高解像度化をしたことによってmaskの画素値が必ずしも0ではなく、
% 0付近（おおよそ10以下？）になっている。


th_hist = 1000; % threshold of the peak height in the histogram

th_prd = 20; % threshold of the product 
% product = peakWidth * peakProminence

date = "0403";
dir = "./data/"+date+"/";

%%
for i=1:8
    % img = imread("./pictures/8x/" + filenameC{9-i} + ".png");
    img = imread("./pictures/1111/" + filenameC{9-i} + ".png");
    
    img_gray = rgb2gray(img);

    for j=1:l % imgWidth(pixel)ごとの画像でピークを見つけ、半自動で点群をグループ化
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small,th_mask);

        z = double(img_omitMask) * (-2/255) + 1; % -1から1に正規化
        pksCell = cell(newWidth,1);

        for k=1:newWidth % 各x座標についてピークを見つけ、pksCellに格納
            % [tmpPks,tmpLocs,w,p] = findpeaks(z(:,k),...
            %     'MinPeakDistance',mind,...
            %     'MinPeakProminence',minp);

            [tmpPks,tmpLocs,w,p] = findpeaks(z(:,k),...
                'MinPeakHeight',minh,...
                'MinPeakDistance',mind,...
                'MinPeakWidth',10);
            % idx=find(tmpPks<maxh);

            product = w.*p;
            idx = find(product < th_prd);

            num = length(idx);

            tmpPksX = k * ones(num,1);
            tmpPksY = zeros(num,1);
            tmpPksY(:,1) = tmpLocs(idx);

            pksCell{k,1} = [tmpPksX tmpPksY];

        end

        pks = vertcat(pksCell{:,:}); % pksCellを結合して行列に

        for lap = 1:laps % laps周目までのデータを格納
            if lap==1  % 1周目のみ
                fig = figure;
                imshow(img_omitMask)
                % set(gca,'YDir','normal')
                hold on;axis on;ax=gca;
                set(ax,'YDir','reverse','TickDir','out');
                set(ax,"XAxisLocation","top");
                scatter(pks(:,1),pks(:,2),1,'c','filled');
                title("DSC0"+num2str(9-i)+" peak "+num2str(j));
                xlabel("$x$");ylabel("$y$");

                saveas(fig,dir+"localMaximumMethod/pkDots_0403_localMax/"+...
                    date+"_findpks_pkDots_i"+num2str(i)+"_j"+num2str(j)+".fig");

                w = imgWidth; % 平行四辺形の高さ
                h = 60; % 平行四辺形の底辺
               [p1,p2,pks_cor] = fitGroove(j,fig,p2,w,h,pks);

                width = 5; % BinWidth

                [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',width);
                centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

                % figure;barh(centers,counts);

                [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);
                [~,idx] = min(abs(p1(2) - centers(histPkLocs))); % p1のy座標に最も近いhistPkLocsを探す

                grooveCenters = zeros(laps,1); % 溝の中心のy座標
                
                % 外側の溝の方がy座標が小さいことに注意
                % histPkLocs(idx)を1本目の溝の中心として、
                % y座標が小さくなる方にlaps個のピークを選び、溝の中心とする
                grooveCenters(:,1) = flip(centers(histPkLocs(idx-laps+1:idx)));
            end

            tol = 25;

            % 溝の中心からtol(pixel)以内にあるy座標
            y_min = grooveCenters(lap,1) - tol;
            y_max = grooveCenters(lap,1) + tol;

            idxs = (pks_cor(:,2)>=y_min) & (pks_cor(:,2)<=y_max);
            points = pks_cor(idxs,:);

            coords_sorted = sortrows(points);
            x_raw = coords_sorted(:,1);
            y_raw = coords_sorted(:,2);

            p = polyfit(x_raw,y_raw,3);
            y_fit = y_raw - polyval(p,x_raw);
            y_fit = y_fit - mean(y_fit);
            
            % i枚目の画像をl分割したうちのj番目の画像のlap周目のデータをxcoords,ycoordsに格納
            xcoords{(i-1)*l+j,lap} = x_raw;
            % ycoords_raw{(i-1)*l+j,lap} = y_raw - mean(y_raw);
            ycoords_raw{(i-1)*l+j,lap} = y_fit;

        end
    end
end

%%
% 音声を作る下準備

% date = "0106-oldData";
% dir = "./data/"+date+"/"+num2str(laps)+"cycles_";
% audioname = "./audio files/"+date+"_"+num2str(laps)+"cycles_";

%%
% ycoords_rawの解析
% ycoords_raw: 何の処理もしていない座標データ

x_comb = vertcat(xcoords{:,:});
y_comb_raw = vertcat(ycoords_raw{:,:});

num_samples = length(y_comb_raw);
fs = round(num_samples /(60/78 * laps));

figure;plot(y_comb_raw);axis tight
title("$y$ coordinates (local maximum method)");xlabel("Sample");ylabel("$y$");
% mySaveForPapers(fig,ax,[0 0 8 6],"$y$ (combined)","$y$","$y$","y (combined)");

y_comb_raw = y_comb_raw - mean(y_comb_raw);
% y_raw_max = max(abs(y_comb_raw));
% amplitude_raw = y_comb_raw / y_raw_max;

tidx = (1:length(y_comb_raw))'/fs;

amplitude_raw = y_comb_raw / (tol/2);
figure;plot(tidx,amplitude_raw);
title("amplitude (local maximum method)");xlabel("Time [s]");ylabel("$y$");
axis tight;ylim([-1 1]);


%%
soundCheck(amplitude_raw,fs,"Produced Sound (Local Maximum Method)",dir,"LocalMax")

audiowrite(dir+"localMaximumMethod/"+date+"_1cycle_raw.wav",amplitude_raw,fs);

%%
% おおよそstep枚の写真ごとにycoordsを接続
% -> filloutliers()を適用して外れ値除去

step = 4; % 8*lはstepで割り切れる必要がある

n = numel(ycoords_raw)/step; % 何セット作れるか
ycoords_eachStepMat = reshape(ycoords_raw,[step,n]); % step行n列のセル配列

% ycoords_eachStepのそれぞれの列について縦に連結した1行n列のセル配列
ycoords_eachStep = cell(1,n); 
for i=1:n
    ycoords_eachStep{1,i} = vertcat(ycoords_eachStepMat{:,i});
end

% 各セルに格納された列ベクトルについてfilloutliers()を適用
ycoords_eachStep_fill = cell(1,n);

for i=1:n
    ycoords_eachStep_fill{i} = filloutliers(ycoords_eachStep{i},"linear");
end

y_fill = vertcat(ycoords_eachStep_fill{:,:});
amplitude_fill = y_fill / y_raw_max;

stepStr = "Filled (step="+num2str(step)+")";
% soundCheck(amplitude_fill,fs,"Sound "+stepStr,dir+stepStr);

% soundCheck_noSave(amplitude_fill,fs,"sound "+stepStr);

% soundCheck(amplitude_fill,fs,"the Corrected Sound",dir+stepStr)

% audiowrite(audioname+stepStr+".wav",amplitude_fill,fs);

%%
[y,fs_stylus] = audioread("./audio files/Audio 1_01_01.wav");
[y2,~] = audioread("./audio files/Audio 1_01_tri(20260113).wav");

% 2026ASJ原稿のためのデータの保存
% 2026合同発表会にも使用
% spectrogram x 3


% pos = [0 0 20 10]; % 原稿用
% pos = [0 0 15 10]; % ポスター用
pos = [0 0 15 8]; % POMA用

fig = createFigure(pos);

t=tiledlayout(1,3,"Padding","tight","TileSpacing","compact");
xlabel(t,"Time [s]","Interpreter","latex");
ylabel(t, "Frequency [Hz]", "Interpreter","latex");


windowSizes = [2048,8192,8192];
y_cell = cell(1,3);
y_cell{1} = y2(round(0.3*fs_stylus):round((0.3+3.85)*fs_stylus));
y_cell{2} = amplitude_raw;
y_cell{3} = amplitude_fill;

fss = [fs_stylus,fs,fs];

for i=1:1
    nexttile;
    axis on;
    ax = gca;
    
    [s,fidx,tidx] = stft(y_cell{i},fss(i),"Window",hann(windowSizes(i)),...
        "OverlapLength",windowSizes(i)/2,...
        'FrequencyRange','onesided');
    s = s * 2 / size(s,1);
    
    mesh(tidx,fidx,20*log10(abs(s)));
    xlim([0 max(tidx)]);ylim([0 5e3]);clim([-120 0]);
    view(0,90);
    % xlabel("Time [s]","Interpreter","latex");
    % ylabel("Frequency [Hz]","Interpreter","latex")
    
    xticks(0:1:max(tidx));
    yticks(0:1000:5000);
    ax.YAxis.Exponent = 3;

    set(ax,"TickLabelInterpreter","latex")

    colormap jet;
    
    if i==3
        c = colorbar;
        c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
        c.Label.Interpreter = "latex";
        c.Label.FontSize = 10;
    end

end

% saveDir = "../../2026合同発表会/原稿資料/";
saveDir = "../../2025JM/原稿資料/";
% exportgraphics(fig,saveDir+"Spectrogramsx3.pdf",'ContentType','image','Resolution',600)
% exportgraphics(fig,saveDir+"Spectrogramsx3_3.png",'Resolution',600)

%%
% 2026asj要旨のためのデータ
% spectrogram x 2
fig=figure;
pos = [0 0 18 8]; % 原稿用

set(fig,'Units','centimeters')
set(fig,"OuterPosition",pos)
set(fig,"PaperPosition",pos)
fig.PaperSize = [pos(3), pos(4)];

t=tiledlayout(1,2,"Padding","tight","TileSpacing","compact");
% title(t, "Fig.1: Spectrograms of Sound from Stylus (left)","and of the Produced Sound (right)",...
    % "FontSize",18,"Position","bottom")
xlabel(t,"Time [s]","FontSize",16);
ylabel(t,"Frequency [Hz]","FontSize",16)

windowSizes = [2048,8192];
y_cell = cell(1,2);
y_cell{1} = y;
y_cell{2} = amplitude_fill;

fss = [fs_stylus,fs];

for i=1:2
    ax = nexttile;
    axis on;
    
    [s,fidx,tidx] = stft(y_cell{i},fss(i),"Window",hann(windowSizes(i)),...
        "OverlapLength",windowSizes(i)/2,...
        'FrequencyRange','onesided');
    s = s * 2 / size(s,1);
    
    mesh(tidx,fidx,20*log10(abs(s)));
    xlim([0 max(tidx)]);ylim([0 5e3]);clim([-120 0]);
    view(0,90);
    
    xticks(0:1:max(tidx));
    yticks(0:1000:5000);
    ax.YAxis.Exponent = 3;

    % set(ax,"TickLabelInterpreter","latex","FontSize",10)
    set(ax,"TickLabelInterpreter","none","FontSize",14)

    colormap jet;
    if i==2
    c = colorbar;
    c.TickLabelInterpreter = "none"; c.Label.String = "Magintude [dB]";
    c.Label.FontSize = 16;
    c.Label.Interpreter = "none";
    end
end

saveDir = "../../2026asj/原稿資料/";
% saveas(fig,saveDir+"spectrogramx2.png")



%%
% 2026合同発表会のためのデータ
% FFTしてみる
% 針で再生した音声+amplitude_raw
% 1~1.1秒

[y2,fs_stylus] = audioread("./audio files/Audio 1_01_tri(20260113).wav");

fig=figure;
t = tiledlayout(2,1,"TileSpacing","loose","Padding","tight");
pos = [0 0 10 8];

set(fig,'Units','centimeters')
set(fig,"OuterPosition",pos)
set(fig,"PaperPosition",pos)
fig.PaperSize = [pos(3), pos(4)];

xlabel(t,"Frequency [Hz]","Interpreter","latex","FontSize",9.25);
ylabel(t, "Power Spectrum [dB]", "Interpreter","latex","FontSize",9.25);

y_cell2 = cell(1,2);
y_cell2{1} = y_cell{1}(1*fs_stylus:round(1.1*fs_stylus));
y_cell2{2} = amplitude_raw(1*fs:round(1.1*fs));

fss = [fs_stylus,fs];
titleNames = ["Sound from Stylus" "the Produced Sound"];

for i=1:2
    nexttile;
    len = length(y_cell2{i});
    fidx = (1:len) / len * fss(i);
    Y = fft(y_cell2{i});
    Y = Y / len * 2;
    plot(fidx,20*log10(abs(Y)));
    xlim([0 3e3]);ylim([-100 0]);
    yticks(-100:20:0);
    % title(titleNames(i))
end

saveDir = "../../2026合同発表会/原稿資料/";
exportgraphics(fig,saveDir+"FFT_noTitle.pdf",'ContentType','image','Resolution',600)
% exportgraphics(fig,saveDir+"FFT.pdf",'ContentType','vector')
exportgraphics(fig,saveDir+"FFT_noTitle.png",'Resolution',600)

%%
% 2026合同発表会のためのデータ
% amplitudex2

fig=figure;
t = tiledlayout(1,2,"TileSpacing","compact","Padding","tight");
pos = [0 0 12 6];

set(fig,'Units','centimeters')
set(fig,"OuterPosition",pos)
set(fig,"PaperPosition",pos)
fig.PaperSize = [pos(3), pos(4)];

xlabel(t,"Time [s]","Interpreter","latex","FontSize",9.25);
ylabel(t, "Amplitude", "Interpreter","latex","FontSize",9.25);

titleNames = ["Sound from Stylus" "the Produced Sound"];

tidx = (1:length(amplitude_raw))/fs;

nexttile;
plot(tidx,amplitude_raw);axis tight
ylim([-1 1])
% title(titleNames(1))
nexttile;
plot(tidx,amplitude_fill);axis tight
ylim([-1 1])
% title(titleNames(2))

saveDir = "../../2026合同発表会/原稿資料/";
% exportgraphics(fig,saveDir+"Ampx2_noTitle.pdf",'ContentType','vector')
% exportgraphics(fig,saveDir+"Ampx2.pdf",'ContentType','vector')
exportgraphics(fig,saveDir+"Amp1x2_noTitle.png", "Resolution",600)


%%
% 2025JMの原稿作成用
% amplitude, FFT, spectrogramをそれぞれ別のfigureに作ってエクスポートする

% 2026卒論作成用

[y2,~] = audioread("./audio files/Audio 1_01_tri(20260113).wav");

pos_amp = [0 0 6 6];
pos_fft = [0 0 6 6];



y_highPass = highpass(y2(round(0.3*fs_stylus):round((0.3+3.85)*fs_stylus))...
    ,100,fs_stylus); % 針で再生した音声の100Hz以下をカット + 該当範囲を指定


tidx_stylus = (1:length(y_highPass))/fs_stylus;
tidx_raw = (1:length(amplitude_raw))/fs;

saveDir = "../../2026卒論/原稿資料/";

% amplitude
fig = createFigure(pos_amp);
plot(tidx_stylus,y_highPass);axis tight
ylim([-1 1])
xlabel("Time [s]");ylabel("Amplitude")
exportgraphics(fig,saveDir+"Amp_stylus.pdf","ContentType","vector")

fig = createFigure(pos_amp);
plot(tidx_raw,amplitude_raw);axis tight
ylim([-1 1])
xlabel("Time [s]");ylabel("Amplitude")
exportgraphics(fig,saveDir+"Amp_raw.pdf","ContentType","vector")

fig = createFigure(pos_amp);
plot(tidx_raw,amplitude_fill);axis tight
ylim([-1 1])
xlabel("Time [s]");ylabel("Amplitude")
exportgraphics(fig,saveDir+"Amp_fill.pdf","ContentType","vector")

% FFT
y_highPass_short = y_highPass(1*fs_stylus:round(1.1*fs_stylus));
amplitude_raw_short = amplitude_raw(1*fs:round(1.1*fs));

fig = createFigure(pos_fft);
len = length(y_highPass_short);
fidx = (1:len) / len * fs_stylus;
Y = fft(y_highPass_short);
Y = Y / len * 2;
plot(fidx,20*log10(abs(Y)));
xlim([0 3e3]);ylim([-100 0]);
yticks(-100:20:0);
xlabel("Frequency [Hz]");ylabel("Amplitude [dB]")
exportgraphics(fig,saveDir+"FFT_stylus.pdf","ContentType","vector")

fig = createFigure(pos_fft);
len = length(amplitude_raw_short);
fidx = (1:len) / len * fs;
Y = fft(amplitude_raw_short);
Y = Y / len * 2;
plot(fidx,20*log10(abs(Y)));
xlim([0 3e3]);ylim([-100 0]);
yticks(-100:20:0);
xlabel("Frequency [Hz]");ylabel("Amplitude [dB]")
exportgraphics(fig,saveDir+"FFT_raw.pdf","ContentType","vector")

%%
% 卒論説明書用に4つのスペクトログラムを表示
% spectrogram
windowSizes = [2048,8192,8192,8192];
y_cell = cell(1,4);
y_cell{1} = y_highPass;
y_cell{2} = amplitude_raw;
y_cell{3} = amplitude_fill;
y_cell{4} = amplitude_fill; % 本来は再撮影写真から作成した音声amplitude_retake

fss = [fs_stylus,fs,fs,fs];

fig = createFigure([0 0 10 10]);
t = tiledlayout(2,2,"Padding","none","TileSpacing","compact");
xlabel(t,"Time [s]","Interpreter","latex","FontSize",9.25);ylabel(t,"Frequency [Hz]","Interpreter","latex","FontSize",9.25)
pos_stft = zeros(1,4,4);
pos_stft(1,:,1) = [0 0 5 4];
pos_stft(1,:,2) = [0 0 5 4];
pos_stft(1,:,3) = [0 0 5 4];
pos_stft(1,:,4) = [0 0 7 4];

for i=1:4
    % fig=createFigure(pos_stft(1,:,i));
    % axis on; ax = gca;
    ax = nexttile;

    [s,fidx,tidx] = stft(y_cell{i},fss(i),"Window",hann(windowSizes(i)),...
        "OverlapLength",windowSizes(i)/2,...
        'FrequencyRange','onesided');
    s = s * 2 / size(s,1);
    
    mesh(tidx,fidx,20*log10(abs(s)));
    xlim([0 max(tidx)]);ylim([0 5e3]);clim([-120 0]);
    view(0,90);

    % xlabel("Time [s]","Interpreter","latex");
    % ylabel("Frequency [Hz]","Interpreter","latex")

    xticks(0:1:max(tidx));
    yticks(0:1000:5000);
    ax.YAxis.Exponent = 3;

    set(ax,"TickLabelInterpreter","latex")
    colormap jet;

    if i==2 || i==4        
        c = colorbar;
        c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
        c.Label.Interpreter = "latex";
    end
    % exportgraphics(fig,saveDir+"Spectrogram_"+num2str(i)+".pdf",'ContentType','image','Resolution',600)
end
exportgraphics(fig,saveDir+"Spectrogram2x2.pdf","ContentType","image","Resolution",600);

%%

