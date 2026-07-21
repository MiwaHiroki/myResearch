filenameC = cell(8,1);
for j=1:8
    filenameC{j} = "DSC0" + num2str(j+112) + "_8x";
end

laps = 5; % 何周分を音データにするか

% 画像8枚分のデータを縦に1周分ずつ格納するCell
% Cはcell配列であることを意味する
amplitudeC = cell(8,laps);
x_combC = cell(8,laps);
y_combC = cell(8,laps);

% 1周分ごとのx,y
x_eachCycle = cell(laps,1);
y_eachCycle = cell(laps,1);

imgWidth = 3000; % 1回でimgWidth(pixel)分のx座標を処理
xarray = [1:imgWidth:30000 30001];
% 切り出す画像(img_small)の左端のx座標
% 便宜的に（画像の横のサイズ+1）を加えておく
l = length(xarray)-1;

thresh1 = 0.0;thresh2 = 0.5; % 溝の底を抽出するには二つの閾値が必要
d = 50; % MinPeakDistance

% DSC0113-0120(計8枚)をそれぞれl分割した画像から得たx,y座標を格納
% 各列にlap周目の座標データが入る
xcoords = cell(8*l,laps);
ycoords = cell(8*l,laps);

p2 = zeros(2,1);

%%
for i=1:8
    % DSC0120からDSC0113
    img = imread("./pictures/8x/" + filenameC{9-i} + ".png");
    img_gray = rgb2gray(img);

    for j=1:l % imgWidth(pixel)ごとの画像でピークを見つけ、半自動で点群をグループ化
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);
        
        z = double(img_small) * (-2/255) + 1; % -1から1に正規化
        pksCell = cell(imgWidth,1);

        for k=1:imgWidth % 各x座標についてピークを見つけ、pksCellに格納
            [tmpPks,tmpLocs] = findpeaks(z(:,k),'MinPeakHeight',thresh1,...
                'MinPeakDistance',d);

            num = nnz(tmpPks < thresh2);

            tmpPksX = k * ones(num,1);
            tmpPksY = zeros(num,1);
            tmpPksY(:,1) = tmpLocs(tmpPks < thresh2);

            pksCell{k,1} = [tmpPksX tmpPksY];

        end

        pks = vertcat(pksCell{:,:}); % pksCellを結合して行列に

        for lap = 1:laps % laps周目までのデータを格納
            if lap==1  % 1周目のみ
                fig = figure;
                imshow(img_small)
                % set(gca,'YDir','normal')
                hold on
                scatter(pks(:,1),pks(:,2),1,'filled');
                title("DSC0"+num2str(121-i)+" peak "+num2str(j))
                
                % name = filenameC{9-i}+" peak "+num2str(j)+".png";
                % saveas(fig,"./figures/peaks on pictures/"+name);

                w = imgWidth; % 平行四辺形の高さ
                h = 60; % 平行四辺形の底辺

                [p1,p2,pks_cor] = fitGroove(j,fig,p2,w,h,pks);

                width = 5; % BinWidth

                [counts,edges] = histcounts(pks_cor,'BinWidth',width);
                centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

                [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',1000);
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

            % i枚目の画像をl分割したうちのj番目の画像のlap周目のデータをxcoords,ycoordsに格納    
            low = (i-1)*l+j; % 座標を格納すべきセルの行
            xcoords{low,lap} = points(:,1);
                   
            if low==1 % 最初の画像(i=j=1のとき、lapは問わない)
                ycoords{low,lap} = points(:,2) - grooveCenters(lap,1);

            else % 前の画像の終わりとy座標をそろえる
                ycoords{low,lap} = points(:,2)...
                    - points(1,2) + ycoords{low-1,lap}(end);
            end

        end
    end
end
%%
for lap=1:laps 
    x_eachCycle{lap,1} = vertcat(xcoords{:,lap});
    y_eachCycle{lap,1} = vertcat(ycoords{:,lap});
    if lap>1 % 周の先頭を前の周の終わりに結合
        y_eachCycle{lap,1} = y_eachCycle{lap,1}...
            - y_eachCycle{lap,1}(1) + y_eachCycle{lap-1,1}(end);
    end
end

%%
% i(=1~8)番目のlap周目の座標データ（画像1枚ごとに音をつくるなら必要）
%{
for i=1:8
    for lap=1:laps
        x_combC{i,lap} = vertcat(xcoords{(i-1)*l+1:(i-1)*l+j});
        y_combC{i,lap} = vertcat(ycoords{(i-1)*l+1:(i-1)*l+j});
        amplitude = (y_combC{i,lap} - min(y_combC{i,lap})) / (max(y_combC{i,lap}) - min(y_combC{i,lap}));
        amplitudeC{i,lap} = amplitude;
    end
end

% 各列に1周分の座標データ
amplitude_tmp = vertcat(amplitudeC{:,:});
x_tmp = vertcat(x_combC{:,:});
y_tmp = vertcat(y_combC{:,:});

amplitude_comb = vertcat(amplitude_tmp(1,:));
x_comb = vertcat(x_tmp(1,:));
y_comb = vertcat(y_tmp(1,:));
%}

%%
x_comb = vertcat(x_eachCycle{:,:});
y_comb = vertcat(y_eachCycle{:,:});
figure;plot(y_comb);title("y comb")


%%
amplitude = (y_comb - min(y_comb)) / (max(y_comb) - min(y_comb)) * 2 - 1;
num_samples = length(y_comb);
fs = round(num_samples /(60/78 * laps));

soundCheck(amplitude,fs,"amplitude");

%%
% 直流成分除去
seg = 0.01;
amplitude2 = zeros(num_samples,1);
xVec = ([1:round(seg*fs):num_samples num_samples])';
for i=1:length(xVec)-1
    tmpXrange = xVec(i):xVec(i+1);
    tmpAmp = amplitude(tmpXrange);
    amplitude2(tmpXrange) = tmpAmp - mean(tmpAmp);
end

amplitude2(abs(amplitude2)>1)=1;
% amplitude2 = (amplitude2 - min(amplitude2)) / (max(amplitude2) - min(amplitude2)) * 2 - 1;

soundCheck(amplitude2,fs,"amplitude2");

%%
date = 0805;
audioname = "./audio files/DSC0113-0120_5cycles_connect"+num2str(date);
% audiowrite(audioname+".wav",amplitude,fs);
% audiowrite(audioname+"_2.wav",amplitude2,fs);

