function cond = cycleConditions(opts)
% cycleConditions  1周分の音声を作成したときの実験条件をstructにまとめる。
%
% saveCycleResult に渡す conditions を作る。必須の定数が欠けていれば
% その場でエラーになるので、実験条件の記録漏れを防げる。
%
% 使い方（すべて name-value 引数）:
%   cond = cycleConditions( ...
%       Upsampling="intpD", Date=date, SaveDir=dir, ...
%       LMask=L_MASK, ThHist=TH_HIST, DThresh=D_THRESH, WTh=W_TH, ...
%       Tol=tol, BinWidth=binWidth, HPrl=h_prl, ...
%       QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, ...
%       Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");
%
% Upsampling:
%   "origD"  高解像度化なし（DarknessValue をそのまま使う）
%   "rsmplD" dResample による高解像度化。PRsmpl, QRsmpl が必須
%   "intpD"  dInterp による内挿。QueryStep, InterpMethod が必須
%
% 必須の引数:
%   Upsampling, Date, SaveDir, LMask, ThHist, DThresh, WTh, Tol, BinWidth, HPrl
%
% 省略可能な引数（既定値）:
%   NumImages (8), NumSegments (10), PolyDegree (3), Rpm (78),
%   Filenames (空), SegmentXRanges (空), ScriptName (""), Note ("")
%
% 出力 cond のフィールド:
%   upsampling  .kind と高解像度化のパラメータ、.scaleFactor（縦方向の拡大率）
%   date, saveDir, numImages, numSegments, totalSegments
%   lMask, thHist, dThresh, wTh, tol, binWidth, hPrl, polyDegree, rpm
%   filenames, segmentXRanges, scriptName, note
%
% 関連: saveCycleResult, cycleMethodResult, loadCycleResult

    arguments
        opts.Upsampling (1,1) string {mustBeMember(opts.Upsampling,["origD","rsmplD","intpD"])}
        opts.Date (1,1) string
        opts.SaveDir (1,1) string
        opts.LMask (1,1) double
        opts.ThHist (1,1) double
        opts.DThresh (1,1) double
        opts.WTh (1,1) double
        opts.Tol (1,1) double
        opts.BinWidth (1,1) double
        opts.HPrl (1,1) double
        opts.NumImages (1,1) double {mustBeInteger,mustBePositive} = 8
        opts.NumSegments (1,1) double {mustBeInteger,mustBePositive} = 10
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 3
        opts.Rpm (1,1) double {mustBePositive} = 78
        opts.PRsmpl (1,1) double {mustBePositive}
        opts.QRsmpl (1,1) double {mustBePositive}
        opts.QueryStep (1,1) double {mustBePositive}
        opts.InterpMethod (1,1) string
        opts.Filenames (:,1) string = strings(0,1)
        opts.SegmentXRanges (:,:) double = []
        opts.ScriptName (1,1) string = ""
        opts.Note (1,1) string = ""
    end

    REQUIRED = ["Upsampling","Date","SaveDir", ...
        "LMask","ThHist","DThresh","WTh","Tol","BinWidth","HPrl"];
    checkGiven(opts, REQUIRED, "実験条件");

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
    end

    cond = struct();
    cond.upsampling     = upsampling;
    cond.date           = opts.Date;
    cond.saveDir        = opts.SaveDir;
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
