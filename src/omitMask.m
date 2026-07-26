function [img_omitMask,newWidth]= omitMask(img_src,th)
% img_srcはuint8型行列

[~,width] = size(img_src);

maskL=1; maskR=width;
while any(img_src(:,maskL)<=th)
    % 「img_grayのj1列のすべての行がthより大きい」の否定
    % = img_grayのj1列の少なくとも一つ以上がth以下だったら
    maskL = maskL + 1;
end

while any(img_src(:,maskR)<=th)
    maskR = maskR - 1;
end

img_omitMask = img_src(:,maskL:maskR);

newWidth = size(img_omitMask,2);

end