% DarknessValue class
% properties: imgID, width, height, D_THRESH, rRatio, dMat
% methods: constructor,isResampled(obj),dResample(obj,p,q),plotD_x(obj,x),setDiffTF(obj,D_THRESH)
% methods that should be moved to another class:
% getStartEndIdx(obj,x),getGrooveBtmIdx(obj,x,startIdx,endIdx),extractGrv()
% constructor: obj = DarknessValue(imgData,D_THRESH)

% the methods which give groove bottom idxs should be moved to another class

classdef DarknessValue < handle
    properties (SetAccess=private)
        imgID (2,1) double
        imgWidth (1,1) double
        imgHeight (1,1) double
        matRows (1,1) double
        matCols (1,1) double
        D_THRESH (1,1) double
        rRatio struct
        dMat (:,:) double
        diffTF (:,:) int8
    end

    methods
        function obj = DarknessValue(imgData,D_THRESH)
            if nargin>0
                obj.imgID = imgData.imgID;
                obj.imgWidth = imgData.width;
                obj.imgHeight = imgData.height;
                obj.matRows = obj.imgHeight;
                obj.matCols = obj.imgWidth;
                obj.rRatio = 1;
                obj.dMat = 1 - imgData.img/255;
                obj.D_THRESH = D_THRESH;
                obj = obj.setDiffTF(D_THRESH);
            end
        end

        function TF = isResampled(obj)
            if (obj.rRatio == 1)
                TF=true;
            else
                TF=false;
            end
        end


        function newObj = dResample(obj,p,q)
            newObj = obj;
            newObj.dMat = resample(obj.dMat,p,q);
            
            newObj.rRatio = p/q;
            newObj = newObj.setDiffTF(newObj.D_THRESH);
        end

        function newObj = dInterp(obj,method,step)
            % the distance between query points, rRatio will be 1/step

            [xx,yy] = meshgrid(1:obj.imgWidth, 1:obj.imgHeight);

            [x_q,y_q] = meshgrid(1:step:obj.imgWidth, 1:step:obj.imgHeight);

            newObj = obj;
            newObj.dMat = interp2(xx,yy,obj.dMat,x_q,y_q,method);
            newObj.rRatio = [1/step, 1/step];
            newObj.setDiffTF(newObj.D_THRESH)
        end

        function obj = change_r_Ratio(obj,new_r_Ratio)
            
        end

        function plotD_x(obj,x)
            D_x = obj.dMat(:,x);
            idx = 1+(0:length(D_x)-1)'/obj.rRatio;
            plot(idx,D_x);
            axis tight;
            titleName = "$D$ on $x$="+num2str(x);
            if isResampled(obj)
                titleName = titleName+"("+num2str(obj.rRatio)+ "x resampled)";
            end
            title(titleName);xlabel("$y$");ylabel("$D$");
            ylim([0 1]);
            colormap(flip(gray));colorbar("eastoutside");clim([0 1]);
        end

        function obj = setDiffTF(obj,D_THRESH)
            TF = (obj.dMat > D_THRESH);
            obj.diffTF = diff(TF);
        end

        % function [startIdx,endIdx] = getStartEndIdx(obj,x)
        %     startIdx = find(obj.diffTF(:,x)==1)+1;
        %     endIdx = find(obj.diffTF(:,x)==-1);
        % 
        %     if endIdx(1)<startIdx(1)
        %         endIdx = endIdx(2:length(endIdx));
        %     end
        %     if endIdx(end)<startIdx(end)
        %         startIdx = startIdx(1:length(startIdx)-1);
        %     end
        % end
        % 
        % function [obj,startIdx_btm,endIdx_btm,pksNum] = getGrooveBtmIdx(obj,x,startIdx,endIdx,W_TH)
        %     W_TH = W_TH * obj.rRatio;
        %     btmIdx = find((endIdx-startIdx)<W_TH); % 溝底に対応するstartIdxのIdxを調べる
        %     startIdx_btm = startIdx(btmIdx);
        %     endIdx_btm = endIdx(btmIdx);
        % 
        %     pksNum = length(btmIdx);
        % 
        %     obj.sIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
        %     obj.eIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];
        % end

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
                cnt_x(k) = 1 + (cnt_x(k)-1)/obj.rRatio;
            end
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
                    max_x(k) = max_x(k) + startIdx_btm(k) - 1;
                    max_x(k) = 1 + (max_x(k)-1)/obj.rRatio;
                end
            end
        end
    end
end