function vocab = figureVocabulary()
% figureVocabulary  図のファイル名に使う語の一覧を返す。
%
% docs/rules/figures.md の「語彙表」と同じ内容を、checkFigureName が使える形で
% 持つ。語彙表を変えたら、この関数も同じコミットで変える。FigureNameTest が、
% figures.md の表とこの関数の一覧が一致しているかを確かめる。
%
% 戻り値 vocab のフィールド（すべて string の列ベクトル）。"<N>" は1桁以上の数字を表す。
%   types         種類の語
%   conditions    条件の語。表の上からの順が、ファイル名に並べる順
%   conditionCats conditions と同じ長さの分類（画像・溝底の判定・抽出法・溝の選び方・音源・周数）
%   parts         部分の語。並べる順
%   displays      表示の語
%   forbidden     使わない語
%
% 関連: checkFigureName

    vocab.types = [
        "waveform"
        "spectrum"
        "spectrogram"
        "grooveShape"
        "grooveShapeDiff"
        "grooveOnImage"
        "grooveOnDarkness3d"
        "grooveHistogram"
        "pointCloud"
        "darknessProfile"
        "darkness3d"
        "image"
        ];

    conditionTable = [
        "画像",       "origD"
        "画像",       "rsmplD"
        "画像",       "rsmplD<N>x"
        "画像",       "intpD"
        "画像",       "intpD<N>x"
        "画像",       "photoshop8x"
        "画像",       "bilateralK<N>"
        "溝底の判定", "exclBound"
        "溝底の判定", "inclBound"
        "抽出法",     "centroid"
        "抽出法",     "localMax"
        "溝の選び方", "manual"
        "溝の選び方", "track"
        "溝の選び方", "hist"
        "音源",       "stylus"
        "周数",       "<N>cyc"
        ];
    vocab.conditionCats = conditionTable(:,1);
    vocab.conditions    = conditionTable(:,2);

    vocab.parts = [
        "img<N>"
        "seg<N>"
        "groove<N>"
        ];

    vocab.displays = [
        "noColorbar"
        ];

    vocab.forbidden = [
        "new"
        "old"
        "final"
        "test"
        "tmp"
        "mini"
        "zoom"
        "compare"
        ];
end
