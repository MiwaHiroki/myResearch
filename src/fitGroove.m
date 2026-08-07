% 手動で作成した平行四辺形内にある点群を直線近似したあと
% その傾きを使ってpksCellの各要素の傾きを直したpksCorCellを出力する
%
% pksCellは複数の溝底候補点データセット（例: 局所的最大値法と重心法の両方）を
% cellで渡せる。全データセットに対して同じ平行四辺形（1回の選択）で補正する。
%
% opts.P1/opts.P2に既知の点を渡すと、その点についてはginputで選択せず
% 渡された値をそのまま使う（音声復元の実験で保存したp1,p2を使って
% 自動で溝を選択し直す場合に使う）。両方渡せばginputは一切呼ばれないうえ、
% figureの作成・描画も一切行わない（figに何を渡しても使われないので[]でよい）。
%
% 使い方:
%   % 手動選択（従来通り）
%   [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w,h,{pks_max,pks_cnt});
%   pks_max_cor = pksCorCell{1}; pks_cnt_cor = pksCorCell{2};
%
%   % 以前保存したp1,p2を使って自動選択（ginput・figureともに不要）
%   [p1,p2,pksCorCell] = fitGroove(jSegment,[],p2,w,h,{pks_max,pks_cnt}, ...
%       P1=prevP1,P2=prevP2);

function [p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w,h,pksCell,opts)
    arguments
        jSegment (1,1) double
        fig
        p2 double % [x,y]。呼び出し側によって行/列ベクトルどちらもありうるので形状は問わない
        w (1,1) double
        h (1,1) double
        pksCell (1,:) cell
        opts.P1 double = []
        opts.P2 double = []
    end

    if numel(p2) ~= 2
        error("fitGroove:invalidP2Arg", "p2 は要素数2のベクトルで指定してください。");
    end
    if ~isempty(opts.P1) && numel(opts.P1) ~= 2
        error("fitGroove:invalidP1", "opts.P1 は要素数2のベクトルで指定してください。");
    end
    if ~isempty(opts.P2) && numel(opts.P2) ~= 2
        error("fitGroove:invalidP2", "opts.P2 は要素数2のベクトルで指定してください。");
    end

    % P1,P2が両方渡されているときはginput不要 = 対話的な選択が要らないので、
    % figureの作成・描画も一切行わない（80セグメント分のループで無駄な
    % figureの生成/破棄を繰り返さないため）
    autoMode = ~isempty(opts.P1) && ~isempty(opts.P2);

    if ~autoMode
        figure(fig);
    end

    % 平行四辺形をつくる
    vertices = zeros(4,2); % 頂点

    if ~isempty(opts.P1)
        p1 = opts.P1; % 保存済みの点を使う（ginputしない）
    elseif jSegment==1 % l枚のうちの左端の画像だったら
        p1 = ginput(1); % 左端の溝の中心を選ぶ
    else
        p1 = p2; % 引数のp2
    end

    % 左側
    vertices(1,:) = [1,p1(2) + h/2]';
    vertices(2,:) = [1,p1(2) - h/2]';
    if ~autoMode
        line(vertices(1:2,1),vertices(1:2,2),'LineWidth',3)
    end

    % 右側
    if ~isempty(opts.P2)
        p2 = opts.P2; % 保存済みの点を使う（ginputしない）
    else
        p2 = ginput(1); % 新しくp2を選ぶ
    end
    vertices(3,:) = [w,p2(2) - h/2]';
    vertices(4,:) = [w,p2(2) + h/2]';

    if ~autoMode
        line(vertices(3:4,1),vertices(3:4,2),'LineWidth',3)

        pgon = polyshape(vertices);
        plot(pgon);

        hold off;
        close(gcf);
    end

    % 平行四辺形の内部または辺上にある点を選び、各データセットを直線近似で補正する
    numDatasets = numel(pksCell);
    pksCorCell = cell(1,numDatasets);
    n = 1; % polyfitの次数

    for k = 1:numDatasets
        pks = pksCell{k};

        [in, on] = inpolygon(pks(:,1), pks(:,2), ...
            vertices(:,1), vertices(:,2));
        selectedPoints = pks(in | on, :);

        if isempty(selectedPoints)
            error("fitGroove:emptySelection", ...
                "fitGroove(): pksCell{%d} に平行四辺形内の点がありません", k);
        end

        p = polyfit(selectedPoints(:,1),selectedPoints(:,2),n);

        x_ = pks(:,1);
        y_fit = polyval(p,x_);

        pksCor = pks;
        pksCor(:,2) = pksCor(:,2) - y_fit + p(1,end);
        % ヒストグラムを作るために切片だけはそのままにしておく

        pksCorCell{k} = pksCor;
    end
end
