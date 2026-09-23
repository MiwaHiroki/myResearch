% ImageData class
% 盤面画像（グレースケール行列）と幅・高さ・IDを保持する値クラス
%
% img（画素データ）はcycleResultには保存しない（issue#17）。clearImage()で
% imgだけ破棄した軽量コピーが作れる。保存後にimgが必要な場合は
% reconstructImage(conditions,iImg)で元の撮影画像から作り直す。
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

        function newObj = clearImage(obj)
            % img（画素データ）を破棄した軽量コピーを返す。imgID/width/heightは保持する。
            newObj = obj;
            newObj.img = [];
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

