function cond = cycleConditions(runCond, opts)
% cycleConditions  1周分の音声を作成したときの実験条件をstructにまとめる。
%
% saveCycleResult に渡す conditions を作る。必須の定数が欠けていれば
% その場でエラーになるので、実験条件の記録漏れを防げる。
%
% 呼び方は2つある。どちらでも出力の形と値は同じになる。
%
% (a) runConditions の出力を受け取る（新しい呼び方。スクリプトはこちらを使う）:
%   runCond = runConditions(LMask=L_MASK, Upsampling="intpD", ...
%       QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, DThresh=D_THRESH, ...
%       WidthThresh=W_TH, Selection="manual", ...
%       Manual=struct(thHist=TH_HIST, tol=tol, binWidth=binWidth, hPrl=h_prl));
%   cond = cycleConditions(runCond, Date=date, SaveDir=outDir, ExperimentDir=expDir, ...
%       Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");
%   実験条件は runCond から写し、実行ごとに変わるもの（Date, SaveDir, ExperimentDir,
%   Filenames, SegmentXRanges, ScriptName, Note）だけを name-value で渡す。実験条件の
%   name-value（LMask など）を一緒に渡すと cycleConditions:mixedForms で止める。
%
% (b) すべて name-value 引数で渡す（今までの呼び方。そのまま使える）:
%   cond = cycleConditions( ...
%       Upsampling="intpD", Date=date, SaveDir=outDir, ExperimentDir=expDir, ...
%       LMask=L_MASK, ThHist=TH_HIST, DThresh=D_THRESH, WTh=W_TH, ...
%       Tol=tol, BinWidth=binWidth, HPrl=h_prl, ...
%       QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, ...
%       Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");
%
% Upsampling:
%   "origD"  高解像度化なし（DarknessMap をそのまま使う）
%   "rsmplD" dResample による高解像度化。PRsmpl, QRsmpl が必須
%   "intpD"  dInterp による内挿。QueryStep, InterpMethod が必須
%
% (b) の必須の引数:
%   Upsampling, Date, SaveDir, LMask, ThHist, DThresh, WTh, Tol, BinWidth, HPrl
%
% (b) の省略可能な引数（既定値）:
%   ExperimentDir (""), NumImages (8), NumSegments (10), PolyDegree (3),
%   Rpm (78), Filenames (空), SegmentXRanges (空), ScriptName (""), Note ("")
%
% (a) で runCond から写すもの:
%   upsampling    upsampling.kind（ちょうど1つ）と p・q・queryStep・interpMethod
%   numImages, numSegments  segmentation.numImages・numSegments（無ければ 8・10）
%   lMask         segmentation.lMask（必須）
%   dThresh, wTh  grooveBottom.dThresh・widthThresh（必須）
%   thHist, tol, binWidth, hPrl
%                 grooveSelection.manual があればその4つ。無くて grooveSelection.histogram
%                 があれば tol = bandTol、binWidth = binWidth、ほかは NaN。どちらも
%                 無ければ4つとも NaN（自動追跡など、fitGroove を使わないとき）
%   polyDegree    detrend.polyDegree（無ければ 3）
%   rpm           audio.rpm（無ければ 78）
%
% SaveDir は図・音声の出力先（resultDir の戻り値）、ExperimentDir は実験結果.matの
% 保存先（experiments/<日付>/）。ExperimentDir を渡すと saveCycleResult は
% そちらに保存する。省略した場合は SaveDir に保存する（移行前の動作）。
%
% 出力 cond のフィールド:
%   upsampling  .kind と高解像度化のパラメータ、.scaleFactor（縦方向の拡大率）
%   date, saveDir, experimentDir, numImages, numSegments, totalSegments
%   lMask, thHist, dThresh, wTh, tol, binWidth, hPrl, polyDegree, rpm
%   filenames, segmentXRanges, scriptName, note
%
% エラー:
%   cycleConditions:missingArgument     必須の引数（runCond の必須のキー）が無い
%   cycleConditions:mixedForms          runCond と実験条件の name-value を一緒に渡した
%   cycleConditions:multipleUpsampling  runCond の upsampling.kind が2つ以上
%
% 関連: runConditions, saveCycleResult, cycleMethodResult, loadCycleResult

    arguments
        runCond (1,1) struct = struct()   % runConditions の出力。(b) の呼び方では渡さない
        opts.Upsampling (1,1) string {mustBeMember(opts.Upsampling,["origD","rsmplD","intpD"])}
        opts.Date (1,1) string
        opts.SaveDir (1,1) string
        opts.ExperimentDir (1,1) string = ""
        opts.LMask (1,1) double
        opts.ThHist (1,1) double
        opts.DThresh (1,1) double
        opts.WTh (1,1) double
        opts.Tol (1,1) double
        opts.BinWidth (1,1) double
        opts.HPrl (1,1) double
        % NumImages・NumSegments・PolyDegree・Rpm の既定値（8・10・3・78）は、(a) の呼び方で
        % 渡されたかを判定できるように、ここではなくコードの中で入れる
        opts.NumImages (1,1) double {mustBeInteger,mustBePositive}
        opts.NumSegments (1,1) double {mustBeInteger,mustBePositive}
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative}
        opts.Rpm (1,1) double {mustBePositive}
        opts.PRsmpl (1,1) double {mustBePositive}
        opts.QRsmpl (1,1) double {mustBePositive}
        opts.QueryStep (1,1) double {mustBePositive}
        opts.InterpMethod (1,1) string
        opts.Filenames (:,1) string = strings(0,1)
        opts.SegmentXRanges (:,:) double = []
        opts.ScriptName (1,1) string = ""
        opts.Note (1,1) string = ""
    end

    if ~isempty(fieldnames(runCond))
        % (a) runCond から今の name-value の並びを作り、(b) と同じ組み立てを通す
        % （同じ処理を通すことで、出力が (b) と同じになることを保つ）
        CONDITION_NAMES = ["Upsampling","LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl", ...
            "NumImages","NumSegments","PolyDegree","Rpm","PRsmpl","QRsmpl","QueryStep","InterpMethod"];
        mixed = CONDITION_NAMES(isfield(opts, CONDITION_NAMES));
        if ~isempty(mixed)
            error("cycleConditions:mixedForms", ...
                "runConditions の出力を渡したときは、実験条件の引数（%s）を一緒に渡せません。" + ...
                "実験条件は runConditions に渡してください。", strjoin(mixed, ", "));
        end
        nv = [conditionArgs(runCond), runArgs(opts)];
        cond = cycleConditions(nv{:});
        return
    end

    REQUIRED = ["Upsampling","Date","SaveDir", ...
        "LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl"];
    checkGiven(opts, REQUIRED, "実験条件");

    DEFAULTS = struct("NumImages", 8, "NumSegments", 10, "PolyDegree", 3, "Rpm", 78);
    for name = string(fieldnames(DEFAULTS))'
        if ~isfield(opts, name)
            opts.(name) = DEFAULTS.(name);
        end
    end

    switch opts.Upsampling
        case "origD"
            upsampling = struct( ...
                'kind', "origD", ...
                'scaleFactor', 1);
        case "rsmplD"
            checkGiven(opts, ["PRsmpl","QRsmpl"], "Upsampling=""rsmplD""");
            upsampling = struct( ...
                'kind', "rsmplD", ...
                'p', opts.PRsmpl, ...
                'q', opts.QRsmpl, ...
                'scaleFactor', opts.PRsmpl/opts.QRsmpl);
        case "intpD"
            checkGiven(opts, ["QueryStep","InterpMethod"], "Upsampling=""intpD""");
            upsampling = struct( ...
                'kind', "intpD", ...
                'queryStep', opts.QueryStep, ...
                'interpMethod', opts.InterpMethod, ...
                'scaleFactor', 1/opts.QueryStep);
    end % end of switch opts.Upsampling

    cond = struct();
    cond.upsampling     = upsampling;
    cond.date           = opts.Date;
    cond.saveDir        = opts.SaveDir;
    cond.experimentDir  = opts.ExperimentDir;
    cond.numImages      = opts.NumImages;
    cond.numSegments    = opts.NumSegments;
    cond.totalSegments  = opts.NumImages * opts.NumSegments;
    cond.lMask          = opts.LMask;
    cond.thHist         = opts.ThHist;
    cond.dThresh        = opts.DThresh;
    cond.wTh            = opts.WTh;
    cond.tol            = opts.Tol;
    cond.binWidth       = opts.BinWidth;
    cond.hPrl           = opts.HPrl;
    cond.polyDegree     = opts.PolyDegree;
    cond.rpm            = opts.Rpm;
    cond.filenames      = opts.Filenames;
    cond.segmentXRanges = opts.SegmentXRanges;
    cond.scriptName     = opts.ScriptName;
    cond.note           = opts.Note;
end % end of function


function nv = conditionArgs(rc)
% runConditions の出力を、(b) の呼び方の実験条件の name-value の並びに写す
    if ~isfield(rc, "upsampling") || ~isfield(rc.upsampling, "kind") || isempty(rc.upsampling.kind)
        error("cycleConditions:missingArgument", ...
            "runConditions の出力に upsampling.kind がありません（runConditions に Upsampling を渡してください）。");
    end
    kinds = string(rc.upsampling.kind);
    if numel(kinds) > 1
        error("cycleConditions:multipleUpsampling", ...
            "1周分の結果には高解像度化を1つだけ書けます（runConditions の Upsampling が %s）。", ...
            strjoin(kinds, ", "));
    end
    nv = {"Upsampling", kinds};
    upKeys  = ["p","q","queryStep","interpMethod"];
    upNames = ["PRsmpl","QRsmpl","QueryStep","InterpMethod"];
    for k = 1:numel(upKeys)
        if isfield(rc.upsampling, upKeys(k))
            nv = [nv, {upNames(k), rc.upsampling.(upKeys(k))}]; %#ok<AGROW>
        end
    end

    seg = groupOf(rc, "segmentation");
    nv = [nv, {"NumImages", valueOr(seg, "numImages", 8), ...
               "NumSegments", valueOr(seg, "numSegments", 10), ...
               "LMask", required(seg, "lMask", "segmentation.lMask（runConditions の LMask）")}];

    gb = groupOf(rc, "grooveBottom");
    nv = [nv, {"DThresh", required(gb, "dThresh", "grooveBottom.dThresh（runConditions の DThresh）"), ...
               "WTh", required(gb, "widthThresh", "grooveBottom.widthThresh（runConditions の WidthThresh）")}];

    gs = groupOf(rc, "grooveSelection");
    if isfield(gs, "manual")
        m = gs.manual;
        ctx = "grooveSelection.manual.";
        nv = [nv, {"ThHist", required(m, "thHist", ctx + "thHist"), ...
                   "Tol", required(m, "tol", ctx + "tol"), ...
                   "BinWidth", required(m, "binWidth", ctx + "binWidth"), ...
                   "HPrl", required(m, "hPrl", ctx + "hPrl")}];
    elseif isfield(gs, "histogram")
        % grooveHist_Ncycle.m の今の呼び方と同じ（帯の半分の幅を Tol に、ビンの幅を BinWidth に）
        h = gs.histogram;
        ctx = "grooveSelection.histogram.";
        nv = [nv, {"ThHist", NaN, ...
                   "Tol", required(h, "bandTol", ctx + "bandTol"), ...
                   "BinWidth", required(h, "binWidth", ctx + "binWidth"), ...
                   "HPrl", NaN}];
    else
        % fitGroove を使わない（自動追跡など）
        nv = [nv, {"ThHist", NaN, "Tol", NaN, "BinWidth", NaN, "HPrl", NaN}];
    end

    nv = [nv, {"PolyDegree", valueOr(groupOf(rc, "detrend"), "polyDegree", 3), ...
               "Rpm", valueOr(groupOf(rc, "audio"), "rpm", 78)}];
end


function nv = runArgs(opts)
% 実行ごとに変わる name-value（渡されたものだけ）を並べる
    RUN_NAMES = ["Date","SaveDir","ExperimentDir","Filenames","SegmentXRanges","ScriptName","Note"];
    nv = {};
    for name = RUN_NAMES
        if isfield(opts, name)
            nv = [nv, {name, opts.(name)}]; %#ok<AGROW>
        end
    end
end


function g = groupOf(rc, name)
    if isfield(rc, name)
        g = rc.(name);
    else
        g = struct();
    end
end


function v = valueOr(s, key, default)
    if isfield(s, key)
        v = s.(key);
    else
        v = default;
    end
end


function v = required(s, key, label)
    if ~isfield(s, key)
        error("cycleConditions:missingArgument", ...
            "runConditions の出力に %s がありません。", label);
    end
    v = s.(key);
end


function checkGiven(opts, names, context)
% opts に names のフィールドがそろっているか確認する。
% name-value 引数は既定値を持たないと未指定時にフィールドが作られないので、
% それを利用して「必須だが未指定」を検出する。

    missingNames = names(~isfield(opts, names));
    if ~isempty(missingNames)
        error("cycleConditions:missingArgument", ...
            "%s に必要な引数が指定されていません: %s", ...
            context, strjoin(missingNames, ", "));
    end
end
