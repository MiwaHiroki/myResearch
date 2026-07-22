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

        function showImg(imgData)
            imshow(uint8(imgData.img));
            % imshow(imgData.img, "InitialMaginification","fit");
            axis on;ax=gca;
            set(ax,'YDir','reverse','TickDir','out')
            set(ax,"XAxisLocation","top")
            xlabel("$x$");ylabel("$y$")
        end
    end
end

