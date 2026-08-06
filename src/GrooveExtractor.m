% GrooveExtractor class
% DarknessMap の dMat/diffTF から溝底候補点を抽出する。
% メモリの大きい dMat を複製しないよう、各メソッドは DarknessMap インスタンスを
% 引数として都度受け取る（自身は startIdxCells/endIdxCells のみ保持する）。
% constructor: obj = GrooveExtractor(map)

classdef GrooveExtractor
    properties (SetAccess=protected)
        startIdxCells (1,:) cell
        endIdxCells (1,:) cell
    end

    methods
        function obj = GrooveExtractor(map)
            if nargin>0
                obj.startIdxCells = cell(1,map.nCols);
                obj.endIdxCells = cell(1,map.nCols);
            end
        end

        function [firstIdx,lastIdx] = findThresholdIntervals(obj,map,x) %#ok<INUSL> objはメソッド呼び出し構文の成立に必要
            firstIdx = find(map.diffTF(:,x)==1)+1;
            lastIdx = find(map.diffTF(:,x)==-1);

            if lastIdx(1)<firstIdx(1)
                lastIdx = lastIdx(2:length(lastIdx));
            end
            if lastIdx(end)<firstIdx(end)
                firstIdx = firstIdx(1:length(firstIdx)-1);
            end
        end

        function [obj,btmFirstIdx,btmLastIdx,numPeaks] = findGrooveBottomIntervals(obj,map,x,firstIdx,lastIdx,WIDTH_THRESH)
            btmIntervalIdx = find((lastIdx-firstIdx) < WIDTH_THRESH*map.scaleFactor.row); % 溝底に対応するfirstIdxのIdxを調べる
            btmFirstIdx = firstIdx(btmIntervalIdx);
            btmLastIdx = lastIdx(btmIntervalIdx);

            numPeaks = length(btmIntervalIdx);

            obj.startIdxCells{1,x} = [x*ones(numPeaks,1), btmFirstIdx];
            obj.endIdxCells{1,x} = [x*ones(numPeaks,1), btmLastIdx];
        end

        function centroidY = extractByCentroid(obj,map,x)
            % centroid法によって音溝画像のx=xにおける溝候補点のy座標を返す
            btmFirstIdx = obj.startIdxCells{1,x}(:,2);
            btmLastIdx = obj.endIdxCells{1,x}(:,2);
            numPeaks = length(btmFirstIdx);
            centroidY = zeros(numPeaks,1);
            D_x = map.dMat(:,x);

            for k=1:numPeaks % それぞれのピークの座標を求める
                peakRowIdxs = (btmFirstIdx(k):btmLastIdx(k))'; % 計算範囲のy

                darknessSum = sum(D_x(peakRowIdxs));
                weightedPosSum = sum(peakRowIdxs .* D_x(peakRowIdxs));
                centroidY(k) = weightedPosSum/darknessSum;
            end

            centroidY = (centroidY - 1) / map.scaleFactor.row + 1;
        end

        function maxY = extractByLocalMax(obj,map,x)
            % localMaximumMethodによって音溝画像のx=xにおける溝候補点のy座標を返す
            btmFirstIdx = obj.startIdxCells{1,x}(:,2);
            btmLastIdx = obj.endIdxCells{1,x}(:,2);
            numPeaks = length(btmFirstIdx);
            maxY = zeros(numPeaks,1);
            D_x = map.dMat(:,x);

            for k=1:numPeaks % それぞれのピークの座標を求める
                peakRowIdxs = (btmFirstIdx(k):btmLastIdx(k))'; % 計算範囲のy
                if isscalar(peakRowIdxs)
                    maxY(k) = peakRowIdxs;
                else
                    [~,maxY(k)] = max(D_x(peakRowIdxs));
                    maxY(k) = maxY(k) + btmFirstIdx(k) -1 ;
                end
            end

            maxY = (maxY - 1) / map.scaleFactor.row + 1;
        end

    end
end
