% 2026/06/11作成
% GrooveCandidateクラス
% 「ピーク点」「溝底候補点」を求め、その情報を格納するクラス

classdef GrooveCandidates
    properties
        imgID (2,1) double
        width (1,1) double
        height (1,1) double
        rsmplTF (1,1) logical
        rRatio (2,1) double
        pksCell (1,:) cell
    end

    methods
        function obj = GrooveCandidates(dValue)
            if nargin>0
                obj.imgID = dValue.imgID;
                obj.width = dValue.imgWidth;
                obj.height = dValue.imgHeight;
                obj.rsmplTF = dValue.rsmplTF;
                obj.rRatio = dValue.rRatio;
                obj.pksCell = cell(1,obj.width);
            end
        end

        % function obj = GrooveCandidates(dValue,pksNums,sIdxCell,eIdxCell,method)
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
        
        function showCandidates(obj)
            pks = vertcat(obj.pksCell{:});
            % scatter(pks(:,1),pks(:,2),5,"c","filled");
            scatter(pks(:,1),pks(:,2),30,"filled");
        end

    end
end


