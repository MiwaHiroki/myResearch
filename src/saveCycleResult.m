function [matPath, dValuePath] = saveCycleResult(conditions, allImg, methodResults, opts)
% saveCycleResult  1周分の音声を作成した実験結果を experiments/<日付>/ の.matに保存する。
%
% origD / rsmplD / intpD のそれぞれについて別ファイルに保存する。
% 1ファイルには重心法・局所的最大値法の両方の結果を入れられる（allImg を
% 手法ごとに二重保存しないため）。保存される変数は result（struct）1つだけ。
%
% 使い方:
%   % 重心法だけ（pkCentroid_interp2_1cycle.m など）
%   matPath = saveCycleResult(cond, allImg, res_cnt);
%
%   % 重心法と局所的最大値法の両方
%   matPath = saveCycleResult(cond, allImg, [res_cnt res_max]);
%
%   % DarknessMap（dMat）も残す場合
%   [matPath, dPath] = saveCycleResult(cond, allImg, res_cnt, ...
%       DarknessValues=allIntpD, SaveDarknessValues=true);
%
%   % fitGroove で選んだ p1,p2 を保存し、次回以降 ginput なしで再現する場合
%   matPath = saveCycleResult(cond, allImg, res_cnt, ...
%       GrooveSelection=struct('p1',allP1,'p2',allP2));
%
% 入力:
%   conditions    - cycleConditions で作成した実験条件のstruct
%   allImg        - (TOTAL_SEGMENTS x 1) ImageData
%   methodResults - cycleMethodResult で作成したstruct。
%                   複数手法は [res_cnt res_max] のように並べて渡す。
%
% name-value 引数:
%   DarknessValues     - (TOTAL_SEGMENTS x 1) DarknessMap（既定: 空）
%   SaveDarknessValues - true のとき DarknessMap 配列を
%                        "<結果ファイル名>_dValue.mat" に分けて保存する（既定: false）。
%                        dMat は origD で約140MB、rsmplD(8x) で約1GB、
%                        intpD(step 0.25) で約2GB になるため既定では保存しない。
%                        1セグメント分の dMat は ginput 無しで作り直せる。
%   GrooveSelection    - fitGroove で選んだ点の記録。.p1, .p2 とも (TOTAL_SEGMENTS x 2)
%                        の double（既定: 空）。fitGroove に P1=.../P2=... として渡せば
%                        ginput なしで同じ溝を自動選択できる（result.grooveSelection
%                        から読み込む）。検証するのは p1/p2 だけで、それ以外の
%                        フィールド（溝の自動追跡の method・seeds・tracking など）も
%                        そのまま保存される。
%   SaveDir            - 保存先フォルダ。既定は conditions.experimentDir
%                        （experiments/<日付>/）。conditions に
%                        ExperimentDir を渡していない場合は conditions.saveDir
%                        （results/<日付>/）に保存する
%   FileName           - ファイル名（既定: cycleResultFileName による自動生成）
%   Overwrite          - true なら既存ファイルを上書きする。false（既定）なら
%                        "..._2.mat" のように連番を付けて別名で保存する。
%                        1周分の解析は fitGroove の手動操作を80回伴うので、
%                        既定では既存ファイルを消さない側に倒している。
%
% 出力:
%   matPath    - 保存した.matのフルパス
%   dValuePath - DarknessMap を保存した.matのフルパス（保存しない場合は ""）
%
% 保存される result の構成:
%   result.conditions  実験条件（cycleConditions の出力）
%   result.meta        実行日時・スクリプト名・MATLAB版・gitコミットなど
%   result.allImg      (N x 1) ImageData（.imgは保存しない。imgIDは残るので
%                      必要ならreconstructImageで元の撮影画像から作り直せる）
%   result.centroid    重心法の結果。.pts (N x 1 GroovePointCloud),
%                      .xcoords, .ycoords (N x 1 cell), .y_comb, .audio (1x1 AudioData)
%   result.localMax    局所的最大値法の結果（渡した場合のみ）。音声を作っていない
%                      手法では .xcoords/.ycoords/.y_comb/.audio は空になる
%   result.dValueFile  DarknessMap を保存した.matのファイル名（未保存なら ""）
%   result.grooveSelection  fitGroove で選んだ点。.p1, .p2 (TOTAL_SEGMENTS x 2)
%                      （渡さなかった場合は空の (0 x 2)）
%
% 読み込みは loadCycleResult を使う。
%
% 関連: cycleConditions, cycleMethodResult, cycleResultFileName, loadCycleResult,
%       reconstructImage

    arguments
        conditions (1,1) struct
        allImg (:,1) ImageData
        methodResults (1,:) struct
        opts.DarknessValues (:,1) DarknessMap = DarknessMap.empty(0,1)
        opts.SaveDarknessValues (1,1) logical = false
        opts.GrooveSelection (1,1) struct = struct('p1', zeros(0,2), 'p2', zeros(0,2))
        opts.SaveDir (1,1) string = ""
        opts.FileName (1,1) string = ""
        opts.Overwrite (1,1) logical = false
    end

    % --- 引数の検証（保存前にまとめて行う。ここで失敗してもデータは消えない） ---
    COND_FIELDS = ["upsampling","date","saveDir","totalSegments","scriptName"];
    missingFields = COND_FIELDS(~isfield(conditions, COND_FIELDS));
    if ~isempty(missingFields)
        error("saveCycleResult:invalidConditions", ...
            "conditions に必要なフィールドがありません: %s\n" + ...
            "cycleConditions で作成したstructを渡してください。", ...
            strjoin(missingFields, ", "));
    end

    if ~isfield(methodResults, "method")
        error("saveCycleResult:invalidMethodResults", ...
            "methodResults に method フィールドがありません。" + ...
            "cycleMethodResult で作成したstructを渡してください。");
    end

    methodNames = string({methodResults.method});
    if numel(unique(methodNames)) ~= numel(methodNames)
        error("saveCycleResult:duplicateMethod", ...
            "同じ手法の結果が複数渡されています: %s", strjoin(methodNames, ", "));
    end

    nSeg = numel(allImg);
    if nSeg ~= conditions.totalSegments
        warning("saveCycleResult:segmentCount", ...
            "allImg の要素数(%d)が conditions.totalSegments(%d)と異なります。", ...
            nSeg, conditions.totalSegments);
    end
    for k = 1:numel(methodResults)
        if numel(methodResults(k).pts) ~= nSeg
            error("saveCycleResult:sizeMismatch", ...
                "%s の pts(%d)と allImg(%d)の要素数が一致しません。", ...
                methodNames(k), numel(methodResults(k).pts), nSeg);
        end
    end

    if opts.SaveDarknessValues && isempty(opts.DarknessValues)
        error("saveCycleResult:noDarknessValues", ...
            "SaveDarknessValues=true ですが DarknessValues が空です。");
    end
    if ~opts.SaveDarknessValues && ~isempty(opts.DarknessValues)
        warning("saveCycleResult:darknessValuesIgnored", ...
            "DarknessValues が渡されましたが SaveDarknessValues=false のため保存しません。");
    end

    GS_FIELDS = ["p1","p2"];
    missingGSFields = GS_FIELDS(~isfield(opts.GrooveSelection, GS_FIELDS));
    if ~isempty(missingGSFields)
        error("saveCycleResult:invalidGrooveSelection", ...
            "GrooveSelection に必要なフィールドがありません: %s", ...
            strjoin(missingGSFields, ", "));
    end
    if ~isempty(opts.GrooveSelection.p1) || ~isempty(opts.GrooveSelection.p2)
        if size(opts.GrooveSelection.p1,2) ~= 2 || size(opts.GrooveSelection.p2,2) ~= 2
            error("saveCycleResult:invalidGrooveSelection", ...
                "GrooveSelection.p1/p2 は (N x 2) の形式で指定してください。");
        end
        if size(opts.GrooveSelection.p1,1) ~= nSeg || size(opts.GrooveSelection.p2,1) ~= nSeg
            error("saveCycleResult:grooveSelectionSizeMismatch", ...
                "GrooveSelection.p1(%d行)/p2(%d行) の行数が allImg(%d)と一致しません。", ...
                size(opts.GrooveSelection.p1,1), size(opts.GrooveSelection.p2,1), nSeg);
        end
    end

    % --- 保存先の決定 ---
    % 実験結果.matは図・音声とは寿命が違うので experiments/<日付>/ に置く。
    % ExperimentDir を持たない古い conditions は従来どおり saveDir に保存する。
    if opts.SaveDir ~= ""
        saveDir = opts.SaveDir;
    elseif isfield(conditions, "experimentDir") && conditions.experimentDir ~= ""
        saveDir = conditions.experimentDir;
    else
        saveDir = conditions.saveDir;
    end
    if ~isfolder(saveDir)
        mkdir(saveDir);
    end

    [defaultName, ~] = cycleResultFileName(conditions.upsampling.kind, conditions.date);
    if opts.FileName == ""
        fileName = defaultName;
    else
        fileName = opts.FileName;
        if ~endsWith(fileName, ".mat")
            fileName = fileName + ".mat";
        end
    end

    [matPath, base] = uniquePath(saveDir, fileName, opts.Overwrite);

    % --- result の組み立て ---
    % allImg(k).img は保存しない（数百MBになるため。issue#17）。
    % imgID/width/heightは残すので、必要ならreconstructImage(conditions,iImg)で
    % 元の撮影画像から作り直せる。
    allImgToSave = allImg;
    for k = 1:numel(allImgToSave)
        allImgToSave(k) = allImgToSave(k).clearImage();
    end

    result = struct();
    result.conditions = conditions;
    result.meta       = collectMeta(conditions.scriptName);
    result.allImg     = allImgToSave;
    for k = 1:numel(methodResults)
        result.(char(methodNames(k))) = rmfield(methodResults(k), "method");
    end
    result.grooveSelection = opts.GrooveSelection;

    if opts.SaveDarknessValues
        dValueName = base + "_dValue.mat";
        dValuePath = fullfile(saveDir, dValueName);
        result.dValueFile = dValueName;
    else
        dValuePath = "";
        result.dValueFile = "";
    end

    % --- 保存 ---
    % allImgのimgは既に落としているが、GroovePointCloud等でも数百MBになり得るため
    % -v7.3（HDF5, 圧縮）で書く
    resultInfo = whos("result");
    fprintf("result を保存します（メモリ上で約 %s）: %s\n", ...
        formatBytes(resultInfo.bytes), matPath);
    save(matPath, "result", "-v7.3");
    fprintf("  保存完了（ファイル %s）\n", formatBytes(fileBytes(matPath)));

    if opts.SaveDarknessValues
        allD = opts.DarknessValues;
        dInfo = whos("allD");
        fprintf("DarknessMap を保存します（メモリ上で約 %s）: %s\n", ...
            formatBytes(dInfo.bytes), dValuePath);
        if dInfo.bytes > 2*1024^3
            fprintf("  2GBを超えるため保存に時間がかかります。\n");
        end
        % どの結果ファイルに対応する dMat かを記録しておく
        parentFile = string(fileName);
        conditionsOfParent = conditions;
        save(dValuePath, "allD", "parentFile", "conditionsOfParent", "-v7.3");
        fprintf("  保存完了（ファイル %s）\n", formatBytes(fileBytes(dValuePath)));
    end
end


function [fullPath, base] = uniquePath(saveDir, fileName, overwrite)
% 既存ファイルを消さずに保存できるパスを返す。
% overwrite=true のときは fileName をそのまま使う。

    [~, base, ext] = fileparts(fileName);
    base = string(base);
    ext  = string(ext);

    fullPath = fullfile(saveDir, base + ext);
    if overwrite || ~isfile(fullPath)
        return
    end

    k = 2;
    while isfile(fullfile(saveDir, base + "_" + k + ext))
        k = k + 1;
    end
    newBase = base + "_" + k;
    warning("saveCycleResult:fileExists", ...
        "%s は既に存在するため %s%s として保存します。" + ...
        "上書きするには Overwrite=true を指定してください。", ...
        base + ext, newBase, ext);
    base = newBase;
    fullPath = fullfile(saveDir, base + ext);
end


function meta = collectMeta(scriptName)
% 実行環境のメタ情報を集める。どのコードで作った結果かを後から特定するため。

    meta = struct();
    meta.savedAt        = datetime("now");
    meta.scriptName     = scriptName;
    meta.matlabRelease  = string(version("-release"));
    meta.matlabVersion  = string(version);
    meta.computerName   = string(getenv("COMPUTERNAME"));

    try
        rootFolder = string(currentProject().RootFolder);
    catch
        rootFolder = string(pwd);
    end
    meta.rootFolder = rootFolder;

    [meta.gitCommit, meta.gitDirty] = gitState(rootFolder);
end


function [commit, isDirty] = gitState(rootFolder)
% gitのコミットハッシュと作業ツリーが変更済みかを返す。
% gitが無い環境でも保存自体は成功させたいので、失敗しても空文字を返す。

    commit  = "";
    isDirty = false;
    try
        [status, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', rootFolder));
        if status == 0
            commit = string(strtrim(out));
        end
        [status, out] = system(sprintf('git -C "%s" status --porcelain', rootFolder));
        if status == 0
            isDirty = ~isempty(strtrim(out));
        end
    catch
        % gitの情報は無くても構わない
    end
end


function bytes = fileBytes(filePath)
    info = dir(filePath);
    if isempty(info)
        bytes = 0;
    else
        bytes = info.bytes;
    end
end


function str = formatBytes(bytes)
    if bytes >= 1024^3
        str = sprintf("%.2f GB", bytes/1024^3);
    else
        str = sprintf("%.1f MB", bytes/1024^2);
    end
end
