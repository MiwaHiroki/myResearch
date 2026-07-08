% "Ncycle_omitMask.m"からのコピー
% 複数のピークを検出し、
% 平行四辺形内にある点の平均を使ってpolyfitを行う（fitGroove_multiPeaks()内で）
% pks_corからy_rawを取り出すときも、複数のy座標の平均を取る

filenameC = cell(8,1);
for j=1:8
    filenameC{j} = "DSC0" + num2str(j+112) + "_8x";
    % filenameC{j} = "DSC1111-0000" + num2str(j) + "-8x";
end

laps = 5; % 何周分を音データにするか

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


% 計8枚の写真をそれぞれl分割した画像から得たx,y座標を格納
% 各列にlap周目の座標データが入る
xcoords = cell(8*l,laps);
ycoords_raw = cell(8*l,laps);

minp = 0.2; % MinPeakProminence
th_prd = 50; % threshold of the product 
% product = peakWidth * peakProminence


p2 = zeros(2,1);

th_mask = 20; 
% maskを取り除くための閾値。0付近に設定する。
% 8倍高解像度化をしたことによってmaskの画素値が必ずしも0ではなく、
% 0付近（おおよそ10以下？）になっている。


th_hist = 1000; % threshold of the peak height in the histogram

newWidthMat = zeros(8*l,laps);

%%
for i=2:2
    % img = imread("./pictures/1111/" + filenameC{9-i} + ".png");
    img = imread("./pictures/old/8x/" + filenameC{9-i} + ".png");

    img_gray = rgb2gray(img);

    for j=1:1 % imgWidth(pixel)ごとの画像でピークを見つけ、半自動で点群をグループ化
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small,th_mask);

        z = double(img_omitMask) * (-2/255) + 1; % -1から1に正規化
        pksCell = cell(newWidth,1);

        for k=1:newWidth % 各x座標についてピークを見つけ、pksCellに格納
            [tmpPks,tmpLocs,w,p] = myFindpeaks(z(:,k),minp);

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
            newWidthMat((i-1)*l+j,lap)=newWidth;

            if lap==1  % 1周目のみ
                fig = figure;
                imshow(img_omitMask)
                hold on
                scatter(pks(:,1),pks(:,2),1,'filled');
                title("DSC0"+num2str(9-i)+" peak "+num2str(j))

                w = imgWidth; % 平行四辺形の高さ
                h = 60; % 平行四辺形の底辺
                [p1,p2,pks_cor] = fitGroove_multiPeaks(i,j,fig,p2,w,h,pks);

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

            [x_raw,~,idx_u]= unique(coords_sorted(:,1));
            % x_raw(idx_u) = coords_sorted(:,1)
            % idx_uは要素に重複を含む([1,2,2,3,...]'のような感じ)

            y_raw = accumarray(idx_u,coords_sorted(:,2),[],@mean);
            % coords_sorted(:,2)をidx_uで分類，グループごとに平均を取る
            % 例えばidx_u=[1,2,2,3,...]', coords_sorted(:,2) = [40,55,45,50,...]であれば
            % y_raw = [40,(55+45)/2,50,...]
            % y_rawのサイズはx_rawのサイズに一致

            % interp1()を使わない場合
            % p_yraw = polyfit(x_raw,y_raw,3); % y_rawに対する多項式近似。適当に3次にしてみた
            % y_fit = y_raw - polyval(p_yraw,x_raw);
            % % i枚目の画像をl分割したうちのj番目の画像のlap周目のデータをxcoords,ycoordsに格納
            % xcoords{(i-1)*l+j,lap} = x_raw;
            % ycoords_raw{(i-1)*l+j,lap} = y_fit;
            

            % interp1()を用いて欠如した点を埋める
            x_q = (1:newWidth)';
            y_q = interp1(x_raw,y_raw,x_q,'linear','extrap');

            xcoords{(i-1)*l+j,lap} = x_q;
            ycoords_raw{(i-1)*l+j,lap} = y_q;

            p_yq = polyfit(x_q,y_q,3);
            yq_fit = y_q - polyval(p_yq,x_q);

            xcoords{(i-1)*l+j,lap} = x_q;
            ycoords_raw{(i-1)*l+j,lap} = yq_fit;
            
           
        end
    end
end


%%
% 音声を作る下準備

date = "1223";
dir = "./data/"+date+"/"+num2str(laps)+"cycles_";
audioname = "./audio files/"+date+"_"+num2str(laps)+"cycles_";
% audioname = "./audio files/"+date+"_"+num2str(laps)+"cycles_interp1_";

%%
% ycoords_rawの解析
% ycoords_raw: 何の処理もしていない座標データ

x_comb = vertcat(xcoords{:,:});
y_comb_raw = vertcat(ycoords_raw{:,:});

num_samples = length(y_comb_raw);
fs = round(num_samples /(60/78 * laps));

figure;plot(y_comb_raw);
title("y comb(raw)");xlabel("x");ylabel("y");axis tight

y_comb_raw = y_comb_raw - mean(y_comb_raw);
y_raw_max = max(abs(y_comb_raw));

amplitude_raw = y_comb_raw / y_raw_max;

%%
soundCheck(amplitude_raw,fs,"original sound",dir+"raw");

audiowrite(audioname+"raw.wav",amplitude_raw,fs);

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

stepStr = "filled (step="+num2str(step)+")";
% soundCheck_noSave(amplitude_fill,fs,"sound "+stepStr);
soundCheck(amplitude_fill,fs,"sound "+stepStr,dir+stepStr);

audiowrite(audioname+stepStr+".wav",amplitude_fill,fs);

%%
% データの保存
%{
dir = "./data/";
datanames = ["y_comb" "amplitude" "amplitude2"];

for i=1:3
    save(dir + datanames(i) +"_" + num2str(laps) + "cycles.mat", datanames(i))
end
%}


%%
