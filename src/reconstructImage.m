function imgs = reconstructImage(conditions, iImg, opts)
% reconstructImage  cycleResultのconditionsと1つのiImgから、
% 元の撮影画像を読み直してそのiImgに属する全segment分のImageData配列を
% 再構成する。
%
% 各 _1cycle スクリプトの画像読み込み〜ImageData構築と同じ処理
% （imread → rgb2gray → セグメント分割 → omitMask）を、指定したiImgの
% 1枚分だけ再現する。撮影画像1枚のimread/rgb2grayは重いため、
% jSegmentごとではなくiImg単位でまとめて行う。conditions.filenames が必要
% （cycleConditions の Filenames 引数）。元の撮影画像ファイル（.png）が
% PhotoDir（既定はカレントフォルダ）に存在している必要がある。
%
% allImg全体をまとめて再構成すると再びメモリを圧迫するため、必要な
% iImgだけをその都度この関数で再構成すること。
%
% 使い方:
%   result = loadCycleResult(matPath);
%   imgs = reconstructImage(result.conditions, 3);   % iImg=3の全segment
%   imgData = imgs(jSegment);                        % 特定のsegmentだけ使う
%
% 関連: saveCycleResult, loadCycleResult, ImageData, omitMask

    arguments
        conditions (1,1) struct
        iImg (1,1) double {mustBeInteger,mustBePositive}
        opts.PhotoDir (1,1) string = ""
    end

    if ~isfield(conditions,"filenames") || isempty(conditions.filenames)
        error("reconstructImage:noFilenames", ...
            "conditions.filenames が空です。撮影画像ファイル名が保存されていないconditionsからは再構成できません。");
    end

    numImages   = conditions.numImages;
    numSegments = conditions.numSegments;
    lMask       = conditions.lMask;
    filenames   = conditions.filenames;

    if iImg > numImages
        error("reconstructImage:iImgOutOfRange", ...
            "iImg=%d が conditions.numImages(%d)の範囲外です。", iImg, numImages);
    end

    fileIdx = numImages + 1 - iImg;   % 元スクリプトの "9-iImg" と同じ反転
    imgPath = filenames(fileIdx) + ".png";
    if opts.PhotoDir ~= ""
        imgPath = fullfile(opts.PhotoDir, imgPath);
    end
    img_new  = imread(imgPath);
    img_gray = rgb2gray(img_new);

    width = size(img_gray,2);
    divWidth = round(width/numSegments);
    xarray = [1:divWidth:width width+1]';

    imgs(numSegments,1) = ImageData();
    for jSegment = 1:numSegments
        img_small = img_gray(:, xarray(jSegment):xarray(jSegment+1)-1);
        img_omitMask = omitMask(img_small, lMask);
        imgs(jSegment) = ImageData(img_omitMask, [iImg;jSegment]);
    end
end
