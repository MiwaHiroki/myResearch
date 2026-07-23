% ImageData class
% DO NOT derive from AudioData class

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

        function showImg(varargin)
            if nargin==1
                imshow(uint8(imgData.img));
            elseif narigin==2
                if varargin{2}=="fit"
                    imshow(uint8(imgData.img), "InitialMaginification","fit");
                else
                    disp("invalid arguments")
                end
            end
        end
    end
end

