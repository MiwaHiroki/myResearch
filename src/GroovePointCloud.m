% 2026/06/11作成
% 2026/08/07改名: GrooveCandidates → GroovePointCloud
% （rename-proposal.md P2。「候補」ではなく溝底の点そのものを保持している
% ことを主張する名前にした。将来的に点群のクラスタリング処理を追加する予定）
%
% 「ピーク点」「溝底の点」を求め、その点群を格納するクラス

classdef GroovePointCloud
    properties
        imgID (2,1) double
        width (1,1) double
        height (1,1) double
        rsmplTF (1,1) logical
        scaleFactor (1,1) struct
        pksCell (1,:) cell
    end

    methods
        function obj = GroovePointCloud(dValue)
            if nargin>0
                obj.imgID = dValue.imgID;
                obj.width = dValue.width;
                obj.height = dValue.height;
                obj.rsmplTF = dValue.rsmplTF;
                obj.scaleFactor = dValue.scaleFactor;
                obj.pksCell = cell(1,obj.width);
            end
        end

        % function obj = GroovePointCloud(dValue,pksNums,sIdxCell,eIdxCell,method)
        %     obj.imgID = dValue.imgID;
        %     obj.width = dValue.width;
        %     obj.height = dValue.height;
        %     obj.rsmplTF = dValue.rsmplTF;
        %     obj.rRatio = dValue.rRatio;
        %     if method=="localMax"
        %         obj.pksCell = localMaxMethod(obj,dValue,pksNums,sIdxCell,eIdxCell);
        %     % elseif method=="centroid"
        %     %     pksCell = centroidMethod();
        %     else
        %         disp("invalid method name");
        %     end
        % end

        % function pksCell = localMaxMethod(obj,dValue,pksNums,sIdxCell,eIdxCell)
        %     pksCell = cell(1, obj.width);
        % 
        %     for i=1:obj.width
        %         pksCell{i} = zeros(pksNums(i),2);
        %         % x=iにおける溝候補点（ピーク点）のx,y座標。
        % 
        %         for k=1:pksNums(i)
        %             idxs = (sIdxCell{i}(k,2):eIdxCell{i}(k,2))';
        %             if isscalar(idxs)
        %                 pksCell{i}(k,:) = [i,idxs];
        %             else
        %                 [~,tmpMax] = max(dValue.dMat(idxs,i));
        %                 pksCell{i}(k,:) = [i, tmpMax+eIdxCell{i}(k,2)-1];
        %             end
        %         end
        %         % pksCell{i} = [i*ones(pksNums(i),1), pk_i];
        %     end
        % end
        
        function showPoints(obj,color,sz)
            pks = vertcat(obj.pksCell{:});
            if nargin==1
                scatter(pks(:,1),pks(:,2),5,"cyan","filled","o");
            elseif nargin==2
                scatter(pks(:,1),pks(:,2),5,color,"o","filled");
            else
                scatter(pks(:,1),pks(:,2),sz,color,"o","filled");
            end
        end

    end
end


