function saveSlideFigure(fig,saveDir,name,w,h)
% スライド1枚に貼る前提で、figのキャンバスをw x h[cm]にそろえてsaveDirにpngのみ保存する
% savePaperFigureと異なりpdf/figは作らない（スライド用の保存規則）
% 実際の出力サイズをコマンドウィンドウに表示するので、目標寸法とずれていないか確認する
arguments
    fig
    saveDir (1,1) string
    name (1,1) string
    w (1,1) double
    h (1,1) double
end

RESOLUTION = 300; % png解像度[dpi]

fig.Units = "centimeters";
fig.Position(3:4) = [w h];
fig.PaperUnits = "centimeters";
fig.PaperSize = [w h];
fig.PaperPosition = [0 0 w h];
fig.PaperPositionMode = "manual";

pngFile = fullfile(saveDir,name+".png");
exportgraphics(fig,pngFile,Resolution=RESOLUTION);

info = imfinfo(pngFile);
fprintf("%s: %.2f x %.2f cm (canvas %.2f x %.2f cm)\n", ...
    name, info.Width/RESOLUTION*2.54, info.Height/RESOLUTION*2.54, w, h);

end
