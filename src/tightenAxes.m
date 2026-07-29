function tightenAxes(ax)
% 目盛りラベルと軸ラベルがちょうど収まる位置までaxesを広げ、figureの余白をなくす
% こうしておくとexportgraphicsのタイトクロップで切り詰められる余白が残らず、
% 出力の物理サイズがキャンバスのサイズと一致する
% TightInsetは凡例・カラーバーを含まないので、それらはaxes内に置くこと
% （tiledlayoutを使う場合はPadding="tight"が同じ働きをする）

ax.Units = "normalized";
ti = ax.TightInset;
ax.Position = [ti(1) ti(2) 1-ti(1)-ti(3) 1-ti(2)-ti(4)];

end
