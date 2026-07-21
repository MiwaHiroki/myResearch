% interp2を使って疑似的な高解像度化を行う
% pkCentroid_interp2_1cycle.mをもとに作成
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
date = "0710";
dir = mkdirFromDate(proj.RootFolder,date);
% dir = "C:\Users\owner\Documents\HirokiMiwa\matlab@Miwa\peak detection\data\"+date+"\";


%%

% iImg=1; % i=1~NUM_IMAGES
% iSegment=1; % j=1~NUM_SEGMENTS

for iImg=1:NUM_IMAGES
    for iSegment=1:NUM_SEGMENTS
        img_new = imread(filenames_new(9-iImg) + ".png");
        img_gray = rgb2gray(img_new);

        [height,width] = size(img_gray);

        divWidth = round(width / NUM_SEGMENTS);
        xarray = [1:divWidth:width width+1]';
        img_small = img_gray(:, xarray(iSegment):xarray(iSegment+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small, L_MASK);
        origImg = ImageData(img_omitMask, [iImg;iSegment]);
        origWidth = origImg.width; origHeight = origImg.height;

        % interpolation
        [xx,yy] = meshgrid(1:origWidth, 1:origHeight);

        QUERY_STEP = 0.25; % the distance between query points, rRatio will be 1/step
        [x_q,y_q] = meshgrid(1:QUERY_STEP:origWidth, 1:QUERY_STEP:origHeight);

        method = "linear"; % method for interpolation
        img_intp2 = interp2(xx,yy,origImg.img,x_q,y_q,method);
        intpImg = ImageData(img_intp2,[iImg,iSegment]);
        intpWidth = intpImg.width; intpHeight = intpImg.height;

        origD = DarknessValue(origImg,D_THRESH);
        origD = setDiffTF(origD, D_THRESH);

        P_RSMPL = 8; Q_RSMPL = 1;
        rsmplD = dResample(origD,P_RSMPL,Q_RSMPL);

        intpD = DarknessValue(intpImg,D_THRESH);
        intpD = setDiffTF(intpD, D_THRESH);


        % objects in which groove candidates are recorded.
        % for original img
        pts_cnt = GrooveCandidates(origD);
        pts_max = GrooveCandidates(origD);
        % for resampled img
        pts_cnt_r = GrooveCandidates(rsmplD);
        pts_max_r = GrooveCandidates(rsmplD);
        % for interpolated img
        pts_cnt_intp = GrooveCandidates(intpD);
        pts_max_intp = GrooveCandidates(intpD);


        W_TH = 8;
        W_TH_INTERP = W_TH / QUERY_STEP;

        for x=1:origWidth
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


        for x=1:intpWidth
            [startIdx, endIdx] = intpD.getStartEndIdx(x);
            [intpD, startIdx_btm, endIdx_btm, pksNum] = ...
                getGrooveBtmIdx(intpD,x,startIdx,endIdx,W_TH_INTERP);

            cnt_x = intpD.extractGrv_cnt(x);
            max_x = intpD.extractGrv_max(x);

            tmpPoints = [x*ones(pksNum,1), cnt_x];
            tmpPoints = 1+(tmpPoints-1)*QUERY_STEP;
            pts_cnt_intp.pksCell{x} = tmpPoints;
            pts_max_intp.pksCell{x} = [x*ones(pksNum,1), max_x];
        end

        pks_cnt_intp = vertcat(pts_cnt_intp.pksCell{:});
        pks_max_intp = vertcat(pts_max_intp.pksCell{:});

    end
end


%%
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
