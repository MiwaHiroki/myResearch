function fig=createFigure(pos)

fig=figure;
set(fig,'Units','centimeters')
% set(fig,'OuterPosition',pos)
% set(fig,'PaperPosition',pos)
fig.Position = pos;
fig.PaperSize = [pos(3), pos(4)];

end