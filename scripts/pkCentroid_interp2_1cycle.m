% interp2を使って疑似的な高解像度化を行う
% pkCentroid_interp2.mをもとに作成
% 2026/07/10作成

%%
% 発表資料作成用

setDefaultIntrpr();

%%
proj = currentProject();

NUM_IMAGES = 8; % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10; % 細長い画像を10等分する
TOTAL_SEGMENTS = NUM_SEGMENTS * 8; % 全部で80枚の画像


filenames_new = strings(NUM_IMAGES,1);
filenames_old = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames_old(i) = "DSC0" + num2str(i+112) + "_8x";
    filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori";
end


L_MASK = 20; % Maskを取るためのluminanceのthreshold, 0付近に設定する
TH_HIST = 150; % threshold of the peak height in the histogram

D_THRESH = 0.6;

% 保存用
date = "0724";
dir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";


%%

% 画像8*l枚分のImageData, DarknessValue, GrooveCandidatesクラスオブジェクト
% 溝の形状抽出はすべてcentroid methodによる。
allImg(TOTAL_SEGMENTS,1) = ImageData();
allIntpD(TOTAL_SEGMENTS,1) = DarknessValue();
allPts_max_intpD(TOTAL_SEGMENTS,1) = GrooveCandidates();
allPts_cnt_intpD(TOTAL_SEGMENTS,1) = GrooveCandidates();
% 以下はpkCentroid_resample_1cycle.mにゆずる。
% allOrigD(TOTAL_SEGMENTS,1) = DarknessValue();
% allPts_max_origD(TOTAL_SEGMENTS,1) = GrooveCandidates();
% allPts_cnt_origD(TOTAL_SEGMENTS,1) = GrooveCandidates();

% 1周分のデータのx,y座標
xcoords = cell(TOTAL_SEGMENTS,1);
ycoords = cell(TOTAL_SEGMENTS,1);
p2 = zeros(1,2);

for iImg=1:NUM_IMAGES
    for jSegment=1:NUM_SEGMENTS
        kImgSmall = (iImg-1)*NUM_SEGMENTS+jSegment;
        % 何番目のimgSmallか。kImgSmall = 1 ~ TOTAL_SEGMENTS

        img_new = imread(filenames_new(9-iImg) + ".png");
        img_gray = rgb2gray(img_new);

        [height,width] = size(img_gray);

        divWidth = round(width / NUM_SEGMENTS);
        xarray = [1:divWidth:width width+1]';
        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small, L_MASK);
        origImg = ImageData(img_omitMask, [iImg;jSegment]);
        origWidth = origImg.width;
        origHeight = origImg.height;
        

        origD = DarknessValue(origImg);
        origD = origD.setDiffTF(D_THRESH);


        % P_RSMPL = 8; Q_RSMPL = 1;
        % rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);
        % rsmplD = rsmplD.setDiffTF(D_THRESH);

        QUERY_STEP = 0.25;
        INTERP_METHOD = "spline";
        intpD = dInterp(origD,QUERY_STEP,INTERP_METHOD);
        intpD = intpD.setDiffTF(D_THRESH);

        % objects in which groove candidates are recorded.
        % for original img
        % pts_cnt = GrooveCandidates(origD);
        % pts_max = GrooveCandidates(origD);

        % for resampled img
        % pts_cnt_r = GrooveCandidates(rsmplD);
        % pts_max_r = GrooveCandidates(rsmplD);

        % for interpolated img
        pts_cnt_intp = GrooveCandidates(intpD);
        pts_max_intp = GrooveCandidates(intpD);


        W_TH = 8;

        % origD, rsmplDから溝形状を抽出
        %{
        for x=1:origImg.width
            [startIdx, endIdx] = getStartEndIdx(origD, x);
            [origD,~,~,pksNum] = ...
                getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
            % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定

            cnt_x = origD.extractGrv_cnt(x);
            max_x = origD.extractGrv_max(x);

            pts_cnt.pksCell{x} = [x*ones(pksNum,1), cnt_x];
            pts_max.pksCell{x} = [x*ones(pksNum,1), max_x];


            [startIdx, endIdx] = getStartEndIdx(rsmplD, x);
            [rsmplD,startIdx_btm,endIdx_btm,pksNum] = ...
                getGrooveBtmIdx(rsmplD, x, startIdx, endIdx, W_TH);

            cnt_x = rsmplD.extractGrv_cnt(x);
            max_x = rsmplD.extractGrv_max(x);

            pts_cnt_r.pksCell{x} = [x*ones(pksNum,1), cnt_x];
            pts_max_r.pksCell{x} = [x*ones(pksNum,1), max_x];
        end

        pks_cnt = vertcat(pts_cnt.pksCell{:});
        pks_max = vertcat(pts_max.pksCell{:});

        pks_cnt_r = vertcat(pts_cnt_r.pksCell{:});
        pks_max_r = vertcat(pts_max_r.pksCell{:});

        % fitGroove()を使って、溝1本分の形状データを抽出する

        %}

        for x=1:intpD.nCols
            [startIdx, endIdx] = intpD.getStartEndIdx(x);
            [intpD, startIdx_btm, endIdx_btm, pksNum] = ...
                getGrooveBtmIdx(intpD,x,startIdx,endIdx,W_TH);

            cnt_x = intpD.extractGrv_cnt(x);
            max_x = intpD.extractGrv_max(x);

            tmpPoints = [x*ones(pksNum,1), cnt_x];
            tmpPoints(:,1) = 1+(tmpPoints(:,1)-1) * QUERY_STEP;
            pts_cnt_intp.pksCell{x} = tmpPoints;

            tmpPoints = [x*ones(pksNum,1), max_x];
            tmpPoints(:,1) = 1+(tmpPoints(:,1)-1) * QUERY_STEP;
            pts_max_intp.pksCell{x} = tmpPoints;
        end

        pks_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});
        pks_max_intp = vertcat(pts_max_intp.pksCell{:});

        w_prl = origWidth; % 平行四辺形の高さ
        h_prl = 8; % 平行四辺形の底辺

        % fitGroove()を使って、溝1本分の形状データを抽出する
        fig = figure;
        origImg.showImg();
        % fig = createFigure([0 0 6 6]);
        % imshow(img_omitMask,"InitialMagnification","fit");
        hold on;
        pts_cnt_intp.showCandidates();
        % scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),5,'c','filled');
        [p1,p2,pks_cor] = fitGroove(jSegment,fig,p2,w_prl,h_prl,pks_cnt_intp);

        binWidth = 5; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',TH_HIST);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));

        tol = 3;
        % そのピークの中心からtol(pixel)以内にあるy座標
        y_min = groove1Center - tol;
        y_max = groove1Center + tol;

        % なんか配列の長さが合わなそうな初期化
        % dInterp()の中身も同様なので実際は問題ない
        points = [(1:QUERY_STEP:intpD.imgWidth)',NaN(intpD.nCols,1)];

        idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);

        clusterdPoints = pks_cor(idxs,:);
        points_x = clusterdPoints(:,1); %QUERY_STEP刻みのx座標。データの一部が欠損してる可能性
        Lia = ismember(points(:,1),points_x);
        % Lia: logical配列。「第一引数に第二引数の数値が見つかったかどうか」
        points(Lia,2) = clusterdPoints(:,2);

        points(:,2) = fillmissing(points(:,2),"linear");

        points_fit = points;


        p = polyfit(points(:,1),points(:,2),3);
        points_fit(:,2) = points(:,2) - polyval(p,points(:,1));
        points_fit(:,2) = points_fit(:,2) - mean(points_fit(:,2));

        xcoords{kImgSmall,1} = points(:,1);
        ycoords{kImgSmall,1} = points_fit(:,2);



        % データの保存
        allImg(kImgSmall) = origImg;
        allIntpD(kImgSmall) = intpD;
        allPts_max_intpD(kImgSmall) = pts_max_intp;
        allPts_cnt_intpD(kImgSmall) = pts_cnt_intp;
        % allOrigD(kImgSmall) = origD;
        % allPts_max_origD(kImgSmall) = pts_max;
        % allPts_cnt_origD(kImgSmall) = pts_cnt;

    end % for jSegment=1:NUM_SEGMENTS
end % for iImg = 1:NUM_IMAGES


%%
% original, resample, interpの比較
%{
mkSize = 5; % marker size
fig = figure;
% fig = createFigure([0 0 6 6]);
% imshow(img_small,"InitialMagnification","fit");
origImg.showImg();
hold on;
scatter(pks_cnt(:,1),pks_cnt(:,2),mkSize,'filled');
scatter(pks_cnt_r(:,1),pks_cnt_r(:,2),mkSize,'filled');
scatter(pks_cnt_intp(:,1),pks_cnt_intp(:,2),mkSize,'filled');

title("Peak Dots (centroid method)");
legend(["not resampled","resampled","interpolated"]);
lgd = legend; lgd.ItemHitFcn=@togglevisibility;
%}

%%

y_comb = vertcat(ycoords{:});
figure;plot(y_comb);axis tight;
title("$y$ coordinates (Darkness interpolated)");xlabel("Sample");ylabel("$y$");

num_samples = length(y_comb);
fs = round(num_samples /(60/78));
tidx = (1:num_samples)'/fs;

y_mean0 = y_comb - mean(y_comb);

amp_raw = y_mean0 / (tol/2);

intpAudio = AudioData("audio ("+num2str(1/QUERY_STEP)+"x interp)",amp_raw,fs);

fig = figure;intpAudio.audioPlot();
saveas(fig,dir+intpAudio.filename+"_amp","fig");saveas(fig,dir+intpAudio.filename+"_amp","png");close;

fig = figure;intpAudio.FFTPlot();
saveas(fig,dir+intpAudio.filename+"_fft","fig");saveas(fig,dir+intpAudio.filename+"_fft","png");close;

fig = figure;intpAudio.spectrogramPlot(4096);
saveas(fig,dir+intpAudio.filename+"_stft","fig");saveas(fig,dir+intpAudio.filename+"_stft","png");close;

intpAudio.saveAudio(dir);
