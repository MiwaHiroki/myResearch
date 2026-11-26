function cond = runConditions(opts)
% runConditions  スクリプトの冒頭の定数を、実験条件の決まった入れ子の struct にまとめる。
%
% 実験条件を作る唯一の入り口。出力は resultDir に渡して runInfo.json の conditions に
% 書き、1周分のスクリプトでは同じ出力を cycleConditions にも渡す（画像の数や
% しきい値などを2回書かないため）。グループとキーの意味・単位は README の
% 「runInfo.json の項目」の表にある。
%
% 使い方（すべて name-value 引数。どれも省略できる）:
%   runCond = runConditions( ...
%       NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, LMask=L_MASK, ...
%       Upsampling="origD", Methods=["centroid","localMax"], ...
%       DThresh=D_THRESH, WidthThresh=WIDTH_THRESH, ...
%       Selection="histogram", ReplayFrom=PREV_RESULT_PATH, ...
%       Tracking=struct(tolerance=TRACK_TOL, fitLength=FIT_LENGTH), ...
%       Histogram=struct(numGrooves=NUM_GROOVES, binWidth=BIN_WIDTH, ...
%                        thHistRatio=TH_HIST_RATIO, bandTol=BAND_TOL), ...
%       PolyDegree=POLY_DEGREE, DetrendScope="photo", Rpm=RPM, AmpDiv=AMP_DIV);
%   outDir = resultDir(proj.RootFolder, EXPERIMENT_NAME, date, runCond, Label=LABEL);
%
% 出力 cond のグループ（この順。渡した引数のグループだけを作る）:
%   region         Region（画像の一部だけを使うとき。キーは自由）
%   segmentation   numImages（既定 8）, numSegments（既定 10）, lMask
%   preprocessing  bilateral（kernelSizes, spatialSigmas, degreeOfSmoothing）
%   upsampling     kind（一覧）, p, q, queryStep, interpMethod
%   grooveBottom   methods（一覧）, dThresh, widthThresh
%   grooveSelection method, replayFrom（"" なら書かない）, tracking, histogram, manual
%   detrend        polyDegree, scope
%   audio          rpm（既定 78）, ampDiv
%   other          Other（ほかに入らないもの。キーは自由）
% グループの中のキーも上の順に並べる（引数を渡した順によらない）。
% 一覧のキー（upsampling.kind, grooveBottom.methods, bilateral.kernelSizes・
% spatialSigmas, tracking.reclickImages）は、要素が1つでも JSON の配列になるよう
% cell の行にする。
%
% エラー:
%   runConditions:missingArgument  Upsampling に "rsmplD" があるのに PRsmpl・QRsmpl が無い、
%                                  "intpD" があるのに QueryStep・InterpMethod が無い
%   runConditions:unknownField     Tracking・Histogram・Manual・Bilateral に表に無いキーがある
%   runConditions:tooDeep          Region・Bilateral・Tracking・Histogram・Manual・Other の
%                                  値に struct がある（入れ子を3段までにするため）
%
% 関連: resultDir, cycleConditions

    arguments
        opts.Region (1,1) struct
        opts.NumImages (1,1) double {mustBeInteger,mustBePositive}     % segmentation を書くときの既定 8
        opts.NumSegments (1,1) double {mustBeInteger,mustBePositive}   % 同じく既定 10
        opts.LMask (1,1) double
        opts.Bilateral (1,1) struct
        opts.Upsampling (1,:) string {mustBeMember(opts.Upsampling,["origD","rsmplD","intpD"])}
        opts.PRsmpl (1,1) double {mustBePositive}
        opts.QRsmpl (1,1) double {mustBePositive}
        opts.QueryStep (1,1) double {mustBePositive}
        opts.InterpMethod (1,1) string
        opts.Methods (1,:) string {mustBeMember(opts.Methods,["centroid","localMax"])}
        opts.DThresh (1,1) double
        opts.WidthThresh (1,1) double
        opts.Selection (1,1) string {mustBeMember(opts.Selection,["manual","tracking","histogram"])}
        opts.ReplayFrom (1,1) string
        opts.Tracking (1,1) struct
        opts.Histogram (1,1) struct
        opts.Manual (1,1) struct
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative}
        opts.DetrendScope (1,1) string {mustBeMember(opts.DetrendScope,["photo","segment"])}
        opts.Rpm (1,1) double {mustBePositive}                          % audio を書くときの既定 78
        opts.AmpDiv (1,1) double {mustBePositive}
        opts.Other (1,1) struct
    end

    % 各グループで許すキー（README の「runInfo.json の項目」の表の順）
    BILATERAL_KEYS = ["kernelSizes","spatialSigmas","degreeOfSmoothing"];
    TRACKING_KEYS  = ["tolerance","fitLength","snapRadius","initLength","maxGapLength", ...
        "minFitPoints","numGrooves","minSeedGap","reclickImages"];
    HISTOGRAM_KEYS = ["numGrooves","binWidth","thHistRatio","bandTol"];
    MANUAL_KEYS    = ["thHist","tol","binWidth","hPrl"];

    % ReplayFrom="" は、選択を再現しない（渡していない）のと同じに扱う
    if isfield(opts, "ReplayFrom") && opts.ReplayFrom == ""
        opts = rmfield(opts, "ReplayFrom");
    end

    % 入れ子の深さと知らないキーを、組み立てる前にまとめて確かめる
    for name = ["Region","Bilateral","Tracking","Histogram","Manual","Other"]
        if isfield(opts, name)
            checkFlat(opts.(name), name);
        end
    end
    if isfield(opts, "Bilateral"), checkKeys(opts.Bilateral, BILATERAL_KEYS, "Bilateral"); end
    if isfield(opts, "Tracking"),  checkKeys(opts.Tracking,  TRACKING_KEYS,  "Tracking");  end
    if isfield(opts, "Histogram"), checkKeys(opts.Histogram, HISTOGRAM_KEYS, "Histogram"); end
    if isfield(opts, "Manual"),    checkKeys(opts.Manual,    MANUAL_KEYS,    "Manual");    end

    cond = struct();

    % --- region ---
    if isfield(opts, "Region")
        cond.region = opts.Region;
    end

    % --- segmentation ---
    if anyGiven(opts, ["NumImages","NumSegments","LMask"])
        seg = struct();
        seg.numImages   = valueOr(opts, "NumImages", 8);
        seg.numSegments = valueOr(opts, "NumSegments", 10);
        if isfield(opts, "LMask")
            seg.lMask = opts.LMask;
        end
        cond.segmentation = seg;
    end

    % --- preprocessing ---
    if isfield(opts, "Bilateral")
        bil = orderKeys(opts.Bilateral, BILATERAL_KEYS);
        for key = ["kernelSizes","spatialSigmas"]
            if isfield(bil, key)
                bil.(key) = asList(bil.(key));
            end
        end
        cond.preprocessing = struct("bilateral", bil);
    end

    % --- upsampling ---
    if anyGiven(opts, ["Upsampling","PRsmpl","QRsmpl","QueryStep","InterpMethod"])
        up = struct();
        if isfield(opts, "Upsampling")
            up.kind = asList(opts.Upsampling);
            if any(opts.Upsampling == "rsmplD")
                requireGiven(opts, ["PRsmpl","QRsmpl"], "Upsampling=""rsmplD""");
            end
            if any(opts.Upsampling == "intpD")
                requireGiven(opts, ["QueryStep","InterpMethod"], "Upsampling=""intpD""");
            end
        end
        % 渡した値は、kind に関係なく記録する（渡したのに記録に残らないことを避けるため）
        names = ["PRsmpl","QRsmpl","QueryStep","InterpMethod"];
        keys  = ["p","q","queryStep","interpMethod"];
        for k = 1:numel(names)
            if isfield(opts, names(k))
                up.(keys(k)) = opts.(names(k));
            end
        end
        cond.upsampling = up;
    end

    % --- grooveBottom ---
    if anyGiven(opts, ["Methods","DThresh","WidthThresh"])
        gb = struct();
        if isfield(opts, "Methods"),     gb.methods     = asList(opts.Methods); end
        if isfield(opts, "DThresh"),     gb.dThresh     = opts.DThresh;         end
        if isfield(opts, "WidthThresh"), gb.widthThresh = opts.WidthThresh;     end
        cond.grooveBottom = gb;
    end

    % --- grooveSelection ---
    if anyGiven(opts, ["Selection","ReplayFrom","Tracking","Histogram","Manual"])
        gs = struct();
        if isfield(opts, "Selection"),  gs.method     = opts.Selection;  end
        if isfield(opts, "ReplayFrom"), gs.replayFrom = opts.ReplayFrom; end
        if isfield(opts, "Tracking")
            tr = orderKeys(opts.Tracking, TRACKING_KEYS);
            if isfield(tr, "reclickImages")
                tr.reclickImages = asList(tr.reclickImages);
            end
            gs.tracking = tr;
        end
        if isfield(opts, "Histogram"), gs.histogram = orderKeys(opts.Histogram, HISTOGRAM_KEYS); end
        if isfield(opts, "Manual"),    gs.manual    = orderKeys(opts.Manual, MANUAL_KEYS);       end
        cond.grooveSelection = gs;
    end

    % --- detrend ---
    if anyGiven(opts, ["PolyDegree","DetrendScope"])
        dt = struct();
        if isfield(opts, "PolyDegree"),   dt.polyDegree = opts.PolyDegree;   end
        if isfield(opts, "DetrendScope"), dt.scope      = opts.DetrendScope; end
        cond.detrend = dt;
    end

    % --- audio ---
    if anyGiven(opts, ["Rpm","AmpDiv"])
        au = struct();
        au.rpm = valueOr(opts, "Rpm", 78);
        if isfield(opts, "AmpDiv")
            au.ampDiv = opts.AmpDiv;
        end
        cond.audio = au;
    end

    % --- other ---
    if isfield(opts, "Other")
        cond.other = opts.Other;
    end
end


function tf = anyGiven(opts, names)
% names の引数を1つでも渡したか。name-value 引数は既定値が無いと、渡さなかったときに
% フィールドが作られないことを使う（cycleConditions の checkGiven と同じ考え方）。
    tf = any(isfield(opts, names));
end


function v = valueOr(opts, name, default)
    if isfield(opts, name)
        v = opts.(name);
    else
        v = default;
    end
end


function requireGiven(opts, names, context)
    missingNames = names(~isfield(opts, names));
    if ~isempty(missingNames)
        error("runConditions:missingArgument", ...
            "%s に必要な引数が指定されていません: %s", context, strjoin(missingNames, ", "));
    end
end


function checkKeys(s, allowed, argName)
% s のキーが allowed のどれかであることを確かめる（綴りの誤りで記録が抜けるのを防ぐため）
    keys = string(fieldnames(s))';
    unknown = keys(~ismember(keys, allowed));
    if ~isempty(unknown)
        error("runConditions:unknownField", ...
            "%s に知らないキーがあります: %s（使えるキー: %s）", ...
            argName, strjoin(unknown, ", "), strjoin(allowed, ", "));
    end
end


function checkFlat(s, argName)
% s の値に struct が無いことを確かめる（runInfo.json の入れ子を3段までにするため）
    keys = string(fieldnames(s))';
    deep = keys(arrayfun(@(k) isstruct(s.(k)), keys));
    if ~isempty(deep)
        error("runConditions:tooDeep", ...
            "%s の値に struct は使えません（入れ子は3段まで）: %s", argName, strjoin(deep, ", "));
    end
end


function out = orderKeys(s, order)
% s のキーを order の順に並べ直す（渡した順によらず、同じ順の JSON にするため）
    out = struct();
    for key = order
        if isfield(s, key)
            out.(key) = s.(key);
        end
    end
end


function c = asList(x)
% 一覧の値を cell の行にする。jsonencode は要素が1つの配列を配列にしないが、
% cell なら要素が1つでも JSON の配列（["..."]・[3]）にするため。
    c = num2cell(x(:)');
end
