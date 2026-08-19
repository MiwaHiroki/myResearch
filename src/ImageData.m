% ImageData class
% 盤面画像（グレースケール行列）と幅・高さ・IDを保持する値クラス
%
% AudioDataなど他のデータクラスからは派生させない。
% 共通の抽象基底クラスだったMediaDataも誰にも継承されず孤立していたため
% src/archive/へ退避した（rename-proposal.mdのP3、2026/08/07）。
% src/のデータクラスはいずれも継承関係を持たない独立した値クラスとする。

classdef ImageData
    properties
        imgID (2,1) double
        img (:,:) double
        width (1,1) double
        height (1,1) double
    end

    methods
        function imgData = ImageData(img,id)
            if nargin>0
                imgData.imgID = id;
                imgData.height = size(img,1);
                imgData.width = size(img,2);
                imgData.img = img;
            end
        end

        function showImage(varargin)
            if nargin==1
                obj = varargin{1};
                imshow(uint8(obj.img));
            elseif nargin==2
                if varargin{2}=="fit"
                    obj = varargin{1};
                    imshow(uint8(obj.img), "InitialMagnification","fit");
                else
                    error("invalid arguments")
                end
            end
            ax=gca;
            set(ax,'YDir','reverse','TickDir','out')
            set(ax,"XAxisLocation","top")
            xlabel("$x$");ylabel("$y$")
        end
    end
end

