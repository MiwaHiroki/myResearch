% DarknessValue class
% properties: imgID, width, height, D_THRESH, rRatio, dMat
% methods: constructor,isResampled(obj),dResample(obj,p,q),plotD_x(obj,x),setDiffTF(obj,D_THRESH)
% methods that should be moved to another class:
% getStartEndIdx(obj,x),getGrooveBtmIdx(obj,x,startIdx,endIdx),extractGrv()
% constructor: obj = DarknessValue(imgData,D_THRESH)

% the methods which give groove bottom idxs should be moved to another class

classdef DarknessValue
    properties (SetAccess=private)
        imgID (2,1) double
        imgWidth (1,1) double
        imgHeight (1,1) double
        nRows (1,1) double % nRows of dMat
        nCols (1,1) double % nCols of dMat
    end

    properties (SetAccess=protected)
        rsmplTF (1,1) logical
        rRatio (2,1) double % rRatio(1): 溝を横切る方向=縦方向, rRatio(2): 溝に平行な方向=横方向
            % rRatio SHOULD BE MORE DESCRIPTIVE
        dMat (:,:) double
        diffTF (:,:) int8
        sIdxC (1,:) cell
        eIdxC (1,:) cell
    end
    
    methods
        function obj = DarknessValue(imgData)
            if nargin>0
                obj.imgID = imgData.imgID;
                obj.imgWidth = imgData.width;
                obj.imgHeight = imgData.height;
                obj.rsmplTF = false;
                obj.rRatio = [1;1];
                obj.dMat = 1 - imgData.img/255;
                [obj.nRows, obj.nCols] = size(obj.dMat);
                obj.sIdxC = cell(1,obj.imgWidth);
                obj.eIdxC = cell(1,obj.imgWidth);
            end
        end


        function newObj = dResample(obj,p,q)
            newObj = obj;
            newObj.dMat = resample(obj.dMat,p,q);
            [newObj.nRows, newObj.nCols] = size(newObj.dMat);
            newObj.rsmplTF = true;
            newObj.rRatio(1) = p/q;
        end


        function newObj = dInterp(obj,step,method)
            [xx,yy] = meshgrid(1:obj.imgWidth, 1:obj.imgHeight);

            [x_q,y_q] = meshgrid(1:step:obj.imgWidth, 1:step:obj.imgHeight);

            dMat_interp = interp2(xx,yy,obj.dMat,x_q,y_q,method);
            % intpWidth = size(dMat_interp,2);

            newObj = obj;
            newObj.dMat = dMat_interp;
            [newObj.nRows, newObj.nCols] = size(newObj.dMat);
            newObj.rRatio = [1/step; 1/step];
            newObj.sIdxC = cell(1,obj.nCols);
            newObj.eIdxC = cell(1,obj.nCols);
        end

        function obj = ddiff(obj,D_th)
            TF = (obj.dMat > D_th);
            obj.diffTF = diff(TF);
        end

        function plotD_x(obj,x)
            D_x = obj.dMat(:,x);
            idx = 1+(0:length(D_x)-1)'/obj.rRatio(1);
            plot(idx,D_x);
            axis tight;
            titleName = "$D$ on $x$="+num2str(x);
            if obj.rsmplTF
                titleName = titleName+"("+num2str(obj.rRatio(1))+ "x resampled)";
            end
            title(titleName);xlabel("$y$");ylabel("$D$");
            ylim([0 1]);
            colormap(flip(gray));colorbar("eastoutside");clim([0 1]);
        end

        function [startIdx,endIdx] = getStartEndIdx(obj,x)
            startIdx = find(obj.diffTF(:,x)==1)+1;
            endIdx = find(obj.diffTF(:,x)==-1);

            if endIdx(1)<startIdx(1)
                endIdx = endIdx(2:length(endIdx));
            end
            if endIdx(end)<startIdx(end)
                startIdx = startIdx(1:length(startIdx)-1);
            end
        end

        function [obj,startIdx_btm,endIdx_btm,pksNum] = getGrooveBtmIdx(obj,x,startIdx,endIdx,W_TH)
            btmIdx = find((endIdx-startIdx) < W_TH*obj.rRatio(1)); % 溝底に対応するstartIdxのIdxを調べる
            startIdx_btm = startIdx(btmIdx);
            endIdx_btm = endIdx(btmIdx);

            pksNum = length(btmIdx);

            obj.sIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
            obj.eIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];
        end

        function cnt_x = extractGrv_cnt(obj,x)
            % centroid法によって音溝画像のx=xにおける溝候補点のy座標を返す
            startIdx_btm = obj.sIdxC{1,x}(:,2);
            endIdx_btm = obj.eIdxC{1,x}(:,2);
            pksNum = length(startIdx_btm);
            cnt_x = zeros(pksNum,1);

            for k=1:pksNum % それぞれのピークの座標を求める
                D_x = obj.dMat(:,x);

                idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy

                sigma_D = sum(D_x(idxs));
                sigma_jxD = sum(idxs .* D_x(idxs));
                cnt_x(k) = sigma_jxD/sigma_D;
            end

            cnt_x = (cnt_x - 1) / obj.rRatio(1) + 1;
        end

        function max_x = extractGrv_max(obj,x)
            % localMaximumMethodによって音溝画像のx=xにおける溝候補点のy座標を返す
            startIdx_btm = obj.sIdxC{1,x}(:,2);
            endIdx_btm = obj.eIdxC{1,x}(:,2);
            pksNum = length(startIdx_btm);
            max_x = zeros(pksNum,1);

            for k=1:pksNum % それぞれのピークの座標を求める
                D_x = obj.dMat(:,x);

                idxs = (startIdx_btm(k):endIdx_btm(k))'; % 計算範囲のy
                if isscalar(idxs)
                    max_x(k) = idxs;
                else
                    [~,max_x(k)] = max(D_x(idxs));
                    max_x(k) = max_x(k) + startIdx_btm(k) -1 ;
                end
            end

            max_x = (max_x - 1) / obj.rRatio(1) + 1;
        end

        % 処理を任せすぎて使いにくいstartEndIdx()メソッド
        % function [pksNums,sIdxs,eIdxs] = startEndIdx(obj,D_th,w_th)
        %     % 引数のw_thはリサンプルする前で成り立つ値を入力する
        %     % 溝底のstartIdx, endIdxを返す
        %     TF = (obj.dMat > D_th);
        %     diff_TF = diff(TF);
        %
        %     w_th_r = w_th * obj.rRatio; % 「山」の幅の最大値
        %
        %     startIdxC = cell(1,obj.width);
        %     endIdxC = cell(1,obj.width);
        %     pksNums = zeros(1,obj.width);
        %
        %     for x=1:obj.width
        %         startIdx = find(diff_TF(:,x)==1)+1;
        %         endIdx = find(diff_TF(:,x)==-1);
        %
        %         if endIdx(1)<startIdx(1)
        %             endIdx = endIdx(2:length(endIdx));
        %         end
        %
        %         if endIdx(end)<startIdx(end)
        %             startIdx = startIdx(1:length(startIdx)-1);
        %         end
        %
        %         btmIdx = find((endIdx-startIdx) < w_th_r); % 溝底に対応するstartIdxのIdxを調べる
        %         startIdx_btm = startIdx(btmIdx);
        %         endIdx_btm = endIdx(btmIdx);
        %
        %         pksNum = length(btmIdx);
        %
        %         startIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
        %         endIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];
        %         pksNums(1,x) = pksNum;
        %     end
        %
        %     sIdxs = vertcat(startIdxC{:});
        %     eIdxs = vertcat(endIdxC{:});
        %
        %     sIdxs(:,2) = 1 + (sIdxs(:,2)-1)/obj.rRatio;
        %     eIdxs(:,2) = 1 + (eIdxs(:,2)-1)/obj.rRatio;
        %
        % end

    end
end
