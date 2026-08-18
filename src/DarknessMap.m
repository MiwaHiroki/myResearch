% DarknessMap class
% properties: imgID, width, height, D_THRESH, scaleFactor, dMat
% methods: constructor,dResample(obj,p,q),plotD_x(obj,x,opts),setDiffTF(obj,D_THRESH)
% constructor: obj = DarknessMap(imgData)
%
% 溝底候補の抽出(閾値区間探索・重心法/最大値法)は GrooveExtractor が担う。

classdef DarknessMap
    properties (SetAccess=private)
        imgID (2,1) double
        width (1,1) double
        height (1,1) double
        nRows (1,1) double % nRows of dMat
        nCols (1,1) double % nCols of dMat
    end

    properties (SetAccess=protected)
        isResampled (1,1) logical
        scaleFactor (1,1) struct
        % scaleFactor.row: 溝を横切る方向=縦方向の拡大率, scaleFactor.col: 溝に平行な方向=横方向の拡大率
        dMat (:,:) double
        diffTF (:,:) int8
    end

    methods
        function obj = DarknessMap(imgData)
            if nargin>0
                obj.imgID = imgData.imgID;
                obj.width = imgData.width;
                obj.height = imgData.height;
                obj.isResampled = false;
                obj.scaleFactor = struct('row',1,'col',1);
                obj.dMat = 1 - imgData.img/255;
                [obj.nRows, obj.nCols] = size(obj.dMat);
            end
        end


        function newObj = dResample(obj,p,q)
            newObj = obj;
            newObj.dMat = resample(obj.dMat,p,q);
            [newObj.nRows, newObj.nCols] = size(newObj.dMat);
            newObj.isResampled = true;
            newObj.scaleFactor.row = p/q;
        end


        function newObj = dInterp(obj,step,method)
            [xx,yy] = meshgrid(1:obj.width, 1:obj.height);

            [x_q,y_q] = meshgrid(1:step:obj.width, 1:step:obj.height);

            dMat_interp = interp2(xx,yy,obj.dMat,x_q,y_q,method);
            % intpWidth = size(dMat_interp,2);

            newObj = obj;
            newObj.dMat = dMat_interp;
            [newObj.nRows, newObj.nCols] = size(newObj.dMat);
            newObj.scaleFactor = struct('row',1/step,'col',1/step);
        end

        function obj = setDiffTF(obj,D_THRESH)
            aboveThreshold = (obj.dMat >= D_THRESH);
            obj.diffTF = diff(aboveThreshold);
        end

        function p = plotD_x(obj,x,opts)
            % x=xにおけるDをy方向にプロットする
            % ShowTitle,ShowColorbarは原稿用の図で不要なときにfalseにする
            % ShowLineMarkerは，必要なときはtrueにする
            arguments
                obj
                x (1,1) double
                opts.ShowTitle (1,1) logical = true
                opts.ShowColorbar (1,1) logical = true
                opts.ShowLineMarker (1,1) logical = false
            end
            D_x = obj.dMat(:,x);
            idx = 1+(0:length(D_x)-1)'/obj.scaleFactor.row;

            if opts.ShowLineMarker
                p = plot(idx,D_x,"Marker",".","MarkerSize",5);
            else
                p = plot(idx,D_x);
            end

            axis tight;
            if opts.ShowTitle
                titleName = "$D$ on $x$="+num2str(x);
                if obj.isResampled
                    titleName = titleName+"("+num2str(obj.scaleFactor.row)+ "x resampled)";
                end
                title(titleName);
            end
            xlabel("$y$");ylabel("$D$");
            ylim([0 1]);
            if opts.ShowColorbar
                colormap(flip(gray));colorbar("eastoutside");clim([0 1]);
            end
        end

    end
end
