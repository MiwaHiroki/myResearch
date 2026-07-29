function savePaperFigure(fig,saveDir,name,w,h,opts)
% 原稿に等倍で貼る前提で、figのキャンバスをw x h[cm]にそろえてsaveDirに保存する
% pdf(既定はベクタ), png(600dpi), figの3つを書き出す
% スペクトログラムのようにベクタでは重くなる図はContentType="image"を指定する
% tightenAxes(またはtiledlayoutのPadding="tight")で余白を消してあれば、
% 出力の物理サイズはw x hとほぼ一致する
% 実際の出力サイズをコマンドウィンドウに表示するので、目標寸法とずれていないか
% 確認し、ずれていればw,hを調整する
arguments
    fig
    saveDir (1,1) string
    name (1,1) string
    w (1,1) double
    h (1,1) double
    opts.ContentType (1,1) string = "vector"
end

RESOLUTION = 600; % png解像度[dpi]

fig.Units = "centimeters";
fig.Position(3:4) = [w h];
fig.PaperUnits = "centimeters";
fig.PaperSize = [w h];
fig.PaperPosition = [0 0 w h];
fig.PaperPositionMode = "manual";

pngFile = fullfile(saveDir,name+".png");

exportgraphics(fig,fullfile(saveDir,name+".pdf"), ...
    ContentType=opts.ContentType,Resolution=RESOLUTION);
exportgraphics(fig,pngFile,Resolution=RESOLUTION);
savefig(fig,fullfile(saveDir,name+".fig"));

info = imfinfo(pngFile);
fprintf("%s: %.2f x %.2f cm (canvas %.2f x %.2f cm)\n", ...
    name, info.Width/RESOLUTION*2.54, info.Height/RESOLUTION*2.54, w, h);

end
