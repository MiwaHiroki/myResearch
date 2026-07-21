% 2026/07/21作成
% 1つのDarknessValueオブジェクトに対して、溝底インデックスを作成する

classdef GrooveRegion
    properties
        matRows (1,1) double % 暗度行列の行数
        matCols (1,1) double % 暗度行列の列数
        startEndIdxs (:,2,:) double

    end
end