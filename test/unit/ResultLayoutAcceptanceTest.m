% issue #28（結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す）の受け入れテスト
%
% docs/issues/closed/28-results-by-experiment/plan.md 4.2 のインターフェースと要求仕様を、関数の外側から
% 確かめる（resultDir、runConditions、cycleConditions の新しい呼び方、figureDir、collectMeta・
% gitState、scripts/migration/migrateResults）。内部の手順や途中の変数には依存させない
% （それは実装担当の unit テストの役目）。評価担当が作成した。実装担当は変更しない
% （docs/rules/evaluation.md）。
%
% 実データは読まない。ファイルを作るテストは、TemporaryFolderFixture の一時フォルダを
% プロジェクトのルートに見立てて、その中だけで作る（CI は Linux・R2024b で、data/・experiments/ が無い）。
% migrateResults のテストでは、一時フォルダに古い形の results/・experiments/ を合成して移す。
classdef ResultLayoutAcceptanceTest < matlab.unittest.TestCase

    properties (Constant)
        % runInfo.json の最上位のキーの順（plan.md 4.3）
        TOP_KEYS = ["schemaVersion","experiment","run","script","note","inputs","conditions","meta"]
        % runConditions の出力のグループの順（plan.md 4.2.2）
        GROUP_ORDER = ["region","segmentation","preprocessing","upsampling","grooveBottom", ...
            "grooveSelection","detrend","audio","other"]
        % collectMeta の出力のフィールドの順（今の saveCycleResult のローカル関数と同じ。plan.md 4.2.5）
        META_FIELDS = ["savedAt","scriptName","matlabRelease","matlabVersion","computerName", ...
            "rootFolder","gitCommit","gitDirty"]
        % cycleConditions の出力のフィールドの順（今の呼び方。cycleResult に保存する形）
        CYCLE_FIELDS = ["upsampling","date","saveDir","experimentDir","numImages","numSegments", ...
            "totalSegments","lMask","thHist","dThresh","wTh","tol","binWidth","hPrl","polyDegree", ...
            "rpm","filenames","segmentXRanges","scriptName","note"]

        % migrateResults のテストで合成する、移す前と移した後のファイル（ルートからの相対パス）
        MIGRATION_FILES = [ ...
            "results/0721/PkDots(muteSection)(orig,rsmpl,intp(spline)).fig",          "results/upsampling/2026-0721/PkDots(muteSection)(orig,rsmpl,intp(spline)).fig"
            "results/0721/sub/note.txt",                                               "results/upsampling/2026-0721/sub/note.txt"
            "results/1014/audio_(centroid_method)(original).wav",                      "results/grooveTracking/2026-1014_manual/audio_(centroid_method)(original).wav"
            "results/1014/audio_(centroid_method)(original)_amp.png",                  "results/grooveTracking/2026-1014_manual/audio_(centroid_method)(original)_amp.png"
            "results/1014/audio_(centroid_method)(original)(tracking).wav",            "results/grooveTracking/2026-1014_track/audio_(centroid_method)(original)(tracking).wav"
            "results/1014/audio_(centroid_method)(original)(tracking)_amp.png",        "results/grooveTracking/2026-1014_track/audio_(centroid_method)(original)(tracking)_amp.png"
            "results/1014/grooveTrack_img1.png",                                       "results/grooveTracking/2026-1014_track/grooveTrack_img1.png"
            "results/1014/evalTrack_rmse.png",                                         "results/grooveTracking/2026-1014_evaluation/evalTrack_rmse.png"
            "results/figures/paper/202609asj/fig1.png",                                "results/figures/202609asj/paper/fig1.png"
            "experiments/1014/cycleResult_origD_1014.mat",                             "experiments/2026-1014/cycleResult_origD_2026-1014.mat"
            "experiments/1014/cycleResult_origD_track_1014.mat",                       "experiments/2026-1014/cycleResult_origD_track_2026-1014.mat"
            "experiments/archive/cycleResult_origD_0731_trash.mat",                    "experiments/archive/cycleResult_origD_0731_trash.mat"]
        % 上の移行に使う対応表（mapping-draft.md 5章の形式。note に日本語を含める）
        MAPPING_LINES = [ ...
            "phase,kind,source,destination,note"
            "results,deleteEmpty,results/0710,,空のフォルダ"
            "results,dir,results/0721,results/upsampling/2026-0721,"
            "results,files,results/1014/audio_(*)(original).wav,results/grooveTracking/2026-1014_manual,"
            "results,files,results/1014/audio_(*)(original)_*,results/grooveTracking/2026-1014_manual,"
            "results,files,results/1014/audio_(*)(original)(tracking)*,results/grooveTracking/2026-1014_track,"
            "results,files,results/1014/grooveTrack_img*,results/grooveTracking/2026-1014_track,"
            "results,files,results/1014/evalTrack_*,results/grooveTracking/2026-1014_evaluation,"
            "results,deleteEmpty,results/1014,,"
            "results,dir,results/figures/paper/202609asj,results/figures/202609asj/paper,"
            "results,deleteEmpty,results/figures/paper,,"
            "experiments,file,experiments/1014/cycleResult_origD_1014.mat,experiments/2026-1014/cycleResult_origD_2026-1014.mat,"
            "experiments,file,experiments/1014/cycleResult_origD_track_1014.mat,experiments/2026-1014/cycleResult_origD_track_2026-1014.mat,"
            "experiments,deleteEmpty,experiments/1014,,"
            "experiments,deleteEmpty,experiments/1026,,"]
    end

    properties (TestParameter)
        % cycleConditions の今の呼び方と新しい呼び方を比べる場合（plan.md 6章の5つ）
        CycleCase = struct("origDManual","origDManual", "rsmplDManual","rsmplDManual", ...
            "intpDManual","intpDManual", "tracking","tracking", "histogram","histogram")
    end

    properties
        root   % 一時フォルダ（プロジェクトのルートに見立てる）
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.root = string(fixture.Folder);
        end
    end

    %% resultDir：実行フォルダの名前と、上書きしないこと
    methods (Test)

        function testRunFolderWithoutLabel(testCase)
            % results/<実験名>/<日付>/ を作り、末尾に区切り文字の付いた絶対パスを返す
            outDir = resultDir(testCase.root, "grooveTracking", "2026-1124", struct());
            expected = fullfile(testCase.root, "results", "grooveTracking", "2026-1124");
            testCase.verifyTrue(isfolder(expected), "実行フォルダ results/grooveTracking/2026-1124 ができていない");
            testCase.verifyEqual(string(outDir), expected + filesep, ...
                "戻り値が、実行フォルダの絶対パスに区切り文字を付けたものになっていない");
            testCase.verifyTrue(isfile(fullfile(expected, "runInfo.json")), "runInfo.json が無い");
        end

        function testRunFolderWithLabel(testCase)
            % 説明は日付の後ろに _ でつなぐ。詳細も _ でつなげる
            outDir = resultDir(testCase.root, "grooveTracking", "2026-1014", struct(), ...
                Label="evaluation_polyDegree");
            expected = fullfile(testCase.root, "results", "grooveTracking", "2026-1014_evaluation_polyDegree");
            testCase.verifyTrue(isfolder(expected), "実行フォルダ 2026-1014_evaluation_polyDegree ができていない");
            testCase.verifyEqual(string(outDir), expected + filesep);
            info = testCase.readRunInfo(outDir);
            testCase.verifyEqual(string(info.run), "2026-1014_evaluation_polyDegree");
        end

        function testSameNameGetsNumberAndWarning(testCase)
            % 同じ名前があれば _2、_3 を付けて警告する。先にあるフォルダの runInfo.json は書き換えない
            expDir = fullfile(testCase.root, "results", "multiGroove");
            first = resultDir(testCase.root, "multiGroove", "2026-1028", struct(), Label="hist5");
            firstText = fileread(fullfile(first, "runInfo.json"));

            second = testCase.verifyWarning(@() resultDir(testCase.root, "multiGroove", "2026-1028", ...
                struct(), Label="hist5"), "resultDir:folderExists");
            third = testCase.verifyWarning(@() resultDir(testCase.root, "multiGroove", "2026-1028", ...
                struct(), Label="hist5"), "resultDir:folderExists");
            testCase.verifyEqual(string(second), fullfile(expDir, "2026-1028_hist5_2") + filesep);
            testCase.verifyEqual(string(third), fullfile(expDir, "2026-1028_hist5_3") + filesep);
            testCase.verifyEqual(string(testCase.readRunInfo(second).run), "2026-1028_hist5_2", ...
                "runInfo.json の run に、付けた番号が入っていない");
            testCase.verifyEqual(fileread(fullfile(first, "runInfo.json")), firstText, ...
                "先にあったフォルダの runInfo.json が書き換えられた");

            % 説明が無いときも同じ
            resultDir(testCase.root, "multiGroove", "2026-1104", struct());
            again = testCase.verifyWarning(@() resultDir(testCase.root, "multiGroove", "2026-1104", ...
                struct()), "resultDir:folderExists");
            testCase.verifyEqual(string(again), fullfile(expDir, "2026-1104_2") + filesep);
        end

        function testDateNotSet(testCase)
            % 日付を書き換えずに実行したら止め、何も作らない
            testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "YYYY-MMDD", struct()), ...
                "resultDir:dateNotSet");
            testCase.verifyEmpty(testCase.runInfoFiles(), "日付が未設定なのに runInfo.json を書いた");
        end

        function testInvalidDate(testCase)
            % YYYY-MMDD の形でない日付、暦に無い日付はエラーにし、何も作らない
            for d = ["1028", "2026-1328", "2026-0230", "2026-0000", "26-1124", "2026-11-24", "2026_1124"]
                testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", d, struct()), ...
                    "resultDir:invalidDate", "日付 """ + d + """ をエラーにしていない");
            end
            testCase.verifyEmpty(testCase.runInfoFiles(), "誤った日付なのに runInfo.json を書いた");
        end

        function testInvalidExperiment(testCase)
            % 実験名は camelCase。figures は図の置き場所なので使えない
            for e = ["figures", "MultiGroove", "multi-groove", "1cycle", "grooveTracking/sub"]
                testCase.verifyError(@() resultDir(testCase.root, e, "2026-1124", struct()), ...
                    "resultDir:invalidExperiment", "実験名 """ + e + """ をエラーにしていない");
            end
            testCase.verifyEmpty(testCase.runInfoFiles());
        end

        function testInvalidLabel(testCase)
            % 説明の各部分は英数字だけ。数字だけの部分は _2 などの番号と見分けられないので使えない
            for lb = ["a b", "hist_2", "2", "hist-5", "評価"]
                testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "2026-1124", struct(), ...
                    Label=lb), "resultDir:invalidLabel", "説明 """ + lb + """ をエラーにしていない");
            end
            testCase.verifyEmpty(testCase.runInfoFiles());
        end
    end

    %% resultDir：runInfo.json の中身
    methods (Test)

        function testRunInfoTopKeysAndSchemaVersion(testCase)
            % 先頭が "schemaVersion": 1 で、決まった順にキーが並ぶ。conditions は渡したとおりに書く
            cond = struct();
            cond.segmentation = struct("numImages", 8, "numSegments", 10, "lMask", 20);
            cond.detrend = struct("polyDegree", 9, "scope", "photo");
            outDir = resultDir(testCase.root, "multiGroove", "2026-1028", cond, Label="hist5", ...
                Note="試しの実行");
            [info, txt] = testCase.readRunInfo(outDir);

            firstKey = regexp(txt, '"(\w+)"\s*:', 'tokens', 'once');
            testCase.verifyEqual(string(firstKey), "schemaVersion", "runInfo.json の先頭のキーが schemaVersion でない");
            testCase.verifyEqual(string(fieldnames(info))', testCase.TOP_KEYS, "最上位のキーの順が plan.md 4.3 と違う");
            testCase.verifyEqual(info.schemaVersion, 1);
            testCase.verifyEqual(string(info.experiment), "multiGroove");
            testCase.verifyEqual(string(info.run), "2026-1028_hist5");
            testCase.verifyEqual(string(info.note), "試しの実行");
            testCase.verifyEqual(string(fieldnames(info.inputs))', ["images","files"]);
            testCase.verifyEqual(string(fieldnames(info.conditions))', ["segmentation","detrend"]);
            testCase.verifyEqual(string(fieldnames(info.conditions.segmentation))', ["numImages","numSegments","lMask"]);
            testCase.verifyEqual(info.conditions.segmentation.lMask, 20);
            testCase.verifyEqual(info.conditions.detrend.polyDegree, 9);
            testCase.verifyEqual(string(info.conditions.detrend.scope), "photo");
        end

        function testRunInfoIsUtf8WithoutBom(testCase)
            % UTF-8（BOM なし）で書き、日本語の note を読み戻せる
            outDir = resultDir(testCase.root, "multiGroove", "2026-1028", struct(), Note="N周分（テスト）");
            fid = fopen(fullfile(outDir, "runInfo.json"), "r");
            testCase.assertGreaterThan(fid, 0, "runInfo.json を開けない");
            firstByte = fread(fid, 1, "*uint8");
            fclose(fid);
            testCase.verifyEqual(firstByte, uint8('{'), "runInfo.json の先頭が { でない（BOM が付いている、など）");
            info = testCase.readRunInfo(outDir);
            testCase.verifyEqual(string(info.note), "N周分（テスト）");
        end

        function testListsAreArraysAndPathsAreRelative(testCase)
            % 要素が1つの一覧も JSON の配列にする。"" の入力ファイルは除く。
            % ルートの下のパスは、ルートからの / 区切りの相対パスにする（conditions の中も）
            relMat = "experiments/2026-1014/cycleResult_origD_2026-1014.mat";
            absMat = fullfile(testCase.root, "experiments", "2026-1014", "cycleResult_origD_2026-1014.mat");
            cond = struct();
            cond.grooveBottom = struct("methods", {{"centroid"}}, "dThresh", 0.6);
            cond.grooveSelection = struct("method", "manual", "replayFrom", absMat);
            outDir = resultDir(testCase.root, "grooveTracking", "2026-1124", cond, ...
                Images="DSC1111-00001-ori", InputFiles=[absMat; ""]);
            [info, txt] = testCase.readRunInfo(outDir);

            testCase.verifyTrue(iscell(info.inputs.images), "要素が1つの inputs.images が配列になっていない");
            testCase.verifyEqual(string(info.inputs.images), "DSC1111-00001-ori");
            testCase.verifyTrue(iscell(info.inputs.files), "要素が1つの inputs.files が配列になっていない");
            testCase.verifyEqual(string(info.inputs.files), relMat, ...
                "inputs.files が、空の要素を除いたルートからの相対パスになっていない");
            testCase.verifyTrue(iscell(info.conditions.grooveBottom.methods), ...
                "要素が1つの conditions.grooveBottom.methods が配列になっていない");
            testCase.verifyEqual(string(info.conditions.grooveSelection.replayFrom), relMat, ...
                "conditions の中のパスが、ルートからの相対パスになっていない");
            testCase.verifyEmpty(regexp(txt, '\\\\', 'once'), "runInfo.json に \ 区切りのパスが残っている");
        end

        function testScriptPath(testCase)
            % ScriptName から scripts/ の下のパスを探す（archive の中は数えない）。
            % 見つからなければ名前だけを書いて警告する。名前が無ければ空にする
            subDir = fullfile(testCase.root, "scripts", "sub");
            arcDir = fullfile(testCase.root, "scripts", "archive");
            mkdir(subDir);
            mkdir(arcDir);
            writelines("x = 1;", fullfile(subDir, "fooScript.m"));
            writelines("x = 1;", fullfile(arcDir, "fooScript.m"));

            lastwarn("");
            outDir = resultDir(testCase.root, "grooveTracking", "2026-1124", struct(), ScriptName="fooScript");
            [~, warnId] = lastwarn;
            testCase.verifyNotEqual(string(warnId), "resultDir:scriptNotFound", ...
                "archive の中の同じ名前のスクリプトも数えて、見つからない扱いにしている");
            testCase.verifyEqual(string(testCase.readRunInfo(outDir).script), "scripts/sub/fooScript.m");

            outDir2 = testCase.verifyWarning(@() resultDir(testCase.root, "grooveTracking", "2026-1125", ...
                struct(), ScriptName="noSuchScript"), "resultDir:scriptNotFound");
            testCase.verifyEqual(string(testCase.readRunInfo(outDir2).script), "noSuchScript.m");

            outDir3 = resultDir(testCase.root, "grooveTracking", "2026-1126", struct());
            testCase.verifyEqual(string(testCase.readRunInfo(outDir3).script), "");
        end

        function testMeta(testCase)
            % meta は createdAt・git（commit・branch・dirty）・matlabRelease・computerName の順
            outDir = resultDir(testCase.root, "grooveTracking", "2026-1124", struct());
            m = testCase.readRunInfo(outDir).meta;
            testCase.verifyEqual(string(fieldnames(m))', ["createdAt","git","matlabRelease","computerName"]);
            testCase.verifyMatches(string(m.createdAt), "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$", ...
                "meta.createdAt が yyyy-MM-ddTHH:mm:ss の形でない");
            testCase.verifyEqual(string(fieldnames(m.git))', ["commit","branch","dirty"]);
            testCase.verifyClass(m.git.dirty, "logical");
            testCase.verifyTrue(startsWith(string(m.matlabRelease), "R"), "meta.matlabRelease が R で始まらない");
        end

        function testUnencodableValueLeavesNoFolder(testCase)
            % JSON にできない値があればエラーにし、空のフォルダを残さない
            cond = struct("other", struct("f", @sin));
            testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "2026-1124", cond), ?MException);
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results", "grooveTracking", "2026-1124")), ...
                "JSON にできない値で止まったのに、実行フォルダが残っている");
        end
    end

    %% runConditions
    methods (Test)

        function testIssueExampleGroupsAndKeys(testCase)
            % issue の例の呼び方で、グループとキーが plan.md 4.3 の順に並ぶ。省いた NumImages などは既定値
            c = runConditions(LMask=20, Upsampling="origD", Methods=["centroid","localMax"], ...
                DThresh=0.6, WidthThresh=4, Selection="histogram", ...
                ReplayFrom="experiments/2026-1026/cycleResult_origD_track_2026-1026.mat", ...
                Tracking=struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40), ...
                Histogram=struct(numGrooves=5, binWidth=1, thHistRatio=0.3, bandTol=3), ...
                PolyDegree=9, DetrendScope="photo", AmpDiv=1.5);

            testCase.verifyFieldOrder(c, ["segmentation","upsampling","grooveBottom","grooveSelection","detrend","audio"]);
            testCase.verifyFieldOrder(c.segmentation, ["numImages","numSegments","lMask"]);
            testCase.verifyEqual([c.segmentation.numImages c.segmentation.numSegments c.segmentation.lMask], [8 10 20]);
            testCase.verifyFieldOrder(c.upsampling, "kind");
            testCase.verifyFieldOrder(c.grooveBottom, ["methods","dThresh","widthThresh"]);
            testCase.verifyFieldOrder(c.grooveSelection, ["method","replayFrom","tracking","histogram"]);
            testCase.verifyFieldOrder(c.detrend, ["polyDegree","scope"]);
            testCase.verifyFieldOrder(c.audio, ["rpm","ampDiv"]);
            testCase.verifyEqual(c.audio.rpm, 78, "audio.rpm の既定値が 78 でない");
            testCase.verifyEqual(string(c.grooveSelection.method), "histogram");
            testCase.verifyEqual(c.grooveSelection.tracking.fitLength, 60);
            testCase.verifyEqual(c.grooveSelection.histogram.bandTol, 3);

            txt = jsonencode(c);
            testCase.verifySubstring(txt, '"kind":["origD"]');
            testCase.verifySubstring(txt, '"methods":["centroid","localMax"]');
        end

        function testOrderDoesNotDependOnArguments(testCase)
            % 引数を渡す順を変えても、同じ順の struct になる（JSON の文字列で比べる）
            tracking = struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40, minFitPoints=5);
            a = runConditions(AmpDiv=1.5, PolyDegree=9, DThresh=0.6, Upsampling="origD", LMask=20, ...
                Selection="tracking", Tracking=tracking, DetrendScope="photo", Methods="centroid", ...
                WidthThresh=4, NumImages=8, Rpm=78);
            b = runConditions(NumImages=8, LMask=20, Upsampling="origD", Methods="centroid", DThresh=0.6, ...
                WidthThresh=4, Selection="tracking", Tracking=tracking, PolyDegree=9, DetrendScope="photo", ...
                Rpm=78, AmpDiv=1.5);
            testCase.verifyEqual(a, b);
            testCase.verifyEqual(jsonencode(a), jsonencode(b), "引数の順で、グループやキーの順が変わる");
        end

        function testAllGroupsInOrder(testCase)
            % すべてのグループを渡すと、region から other までの決まった順に並ぶ
            c = runConditions(Other=struct(wMin=2), AmpDiv=1.5, Rpm=78, DetrendScope="segment", PolyDegree=3, ...
                Manual=struct(thHist=150, tol=3, binWidth=5, hPrl=8), ...
                Histogram=struct(numGrooves=5, binWidth=1, thHistRatio=0.3, bandTol=3), ...
                Tracking=struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40, ...
                    minFitPoints=5, numGrooves=5, minSeedGap=13, reclickImages=[3 7]), ...
                ReplayFrom="experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat", Selection="manual", ...
                WidthThresh=8, DThresh=0.6, Methods=["centroid","localMax"], ...
                InterpMethod="spline", QueryStep=0.125, QRsmpl=1, PRsmpl=8, Upsampling=["rsmplD","intpD"], ...
                Bilateral=struct(kernelSizes=[3 5 9], spatialSigmas=[0.5 1 2], degreeOfSmoothing=650.25), ...
                LMask=20, NumSegments=10, NumImages=8, Region=struct(imgIndex=1, jSegment=3));

            testCase.verifyFieldOrder(c, testCase.GROUP_ORDER);
            testCase.verifyFieldOrder(c.upsampling, ["kind","p","q","queryStep","interpMethod"]);
            testCase.verifyFieldOrder(c.preprocessing, "bilateral");
            testCase.verifyFieldOrder(c.preprocessing.bilateral, ["kernelSizes","spatialSigmas","degreeOfSmoothing"]);
            testCase.verifyFieldOrder(c.grooveSelection, ["method","replayFrom","tracking","histogram","manual"]);
            testCase.verifyEqual(c.region.jSegment, 3);
            testCase.verifyEqual(c.other.wMin, 2);
            testCase.verifyEqual(c.grooveSelection.manual.hPrl, 8);

            txt = jsonencode(c);
            testCase.verifySubstring(txt, '"kind":["rsmplD","intpD"]');
            testCase.verifySubstring(txt, '"kernelSizes":[3,5,9]');
            testCase.verifySubstring(txt, '"spatialSigmas":[0.5,1,2]');
            testCase.verifySubstring(txt, '"reclickImages":[3,7]');
        end

        function testNoArgumentsGivesEmptyStruct(testCase)
            c = runConditions();
            testCase.verifyClass(c, "struct");
            testCase.verifyEmpty(fieldnames(c), "引数なしでグループを作っている");
            testCase.verifyEqual(jsonencode(c), '{}');
        end

        function testDefaultsAreFilledPerGroup(testCase)
            % segmentation・audio は、その引数を1つでも渡したときだけ作り、既定値（8・10・78）で埋める
            c = runConditions(LMask=20);
            testCase.verifyFieldOrder(c, "segmentation");
            testCase.verifyFieldOrder(c.segmentation, ["numImages","numSegments","lMask"]);
            testCase.verifyEqual([c.segmentation.numImages c.segmentation.numSegments c.segmentation.lMask], [8 10 20]);

            c = runConditions(AmpDiv=1.5);
            testCase.verifyFieldOrder(c, "audio");
            testCase.verifyFieldOrder(c.audio, ["rpm","ampDiv"]);
            testCase.verifyEqual([c.audio.rpm c.audio.ampDiv], [78 1.5]);

            c = runConditions(NumSegments=5);
            testCase.verifyFieldOrder(c.segmentation, ["numImages","numSegments"]);
            testCase.verifyEqual([c.segmentation.numImages c.segmentation.numSegments], [8 5]);
        end

        function testSingleElementListsBecomeJsonArrays(testCase)
            % 一覧のキーは、要素が1つでも JSON の配列になる。一覧でないキーは数のまま
            c = runConditions(Upsampling="origD", Methods="centroid", ...
                Bilateral=struct(kernelSizes=3, spatialSigmas=0.5, degreeOfSmoothing=650.25), ...
                Selection="tracking", Tracking=struct(tolerance=2, reclickImages=4));
            txt = jsonencode(c);
            testCase.verifySubstring(txt, '"kind":["origD"]');
            testCase.verifySubstring(txt, '"methods":["centroid"]');
            testCase.verifySubstring(txt, '"kernelSizes":[3]');
            testCase.verifySubstring(txt, '"spatialSigmas":[0.5]');
            testCase.verifySubstring(txt, '"reclickImages":[4]');
            testCase.verifySubstring(txt, '"degreeOfSmoothing":650.25');
            testCase.verifySubstring(txt, '"tolerance":2');
        end

        function testEmptyReplayFromIsOmitted(testCase)
            c = runConditions(Selection="manual", ReplayFrom="");
            testCase.verifyFieldOrder(c, "grooveSelection");
            testCase.verifyFieldOrder(c.grooveSelection, "method");
        end

        function testRunConditionsErrors(testCase)
            % 高解像度化に要る引数の不足、表に無いキー、深すぎる入れ子、知らない引数
            testCase.verifyError(@() runConditions(Upsampling="rsmplD"), "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Upsampling="rsmplD", PRsmpl=8), "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Upsampling="intpD", InterpMethod="spline"), "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Upsampling=["origD","intpD"], QueryStep=0.125), ...
                "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Tracking=struct(tolerance=2, foo=1)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Histogram=struct(binWidth=1, bar=1)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Manual=struct(thHist=150, hprl=8)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Bilateral=struct(kernelSize=3)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Other=struct(a=struct(b=1))), "runConditions:tooDeep");
            testCase.verifyError(@() runConditions(Region=struct(r=struct(c=1))), "runConditions:tooDeep");
            testCase.verifyError(@() runConditions(Foo=1), "MATLAB:TooManyInputs");
        end
    end

    %% cycleConditions の新しい呼び方
    methods (Test)

        function testNewCallEqualsOldCall(testCase, CycleCase)
            % 同じ定数から今の呼び方と新しい呼び方で作った conditions が等しい
            % （NaN を等しいとみなすため isequal ではなく verifyEqual。フィールドの順も同じ）
            [oldArgs, runArgs] = testCase.cycleCaseArgs(CycleCase);
            common = {"Date","2026-1124", "SaveDir",fullfile(testCase.root,"out"), ...
                "ExperimentDir",fullfile(testCase.root,"experiments","2026-1124"), ...
                "Filenames",["DSC1111-00001-ori";"DSC1111-00002-ori"], "ScriptName","someScript", ...
                "Note","テストの実行"};
            oldCond = cycleConditions(oldArgs{:}, common{:});
            runCond = runConditions(runArgs{:});
            newCond = cycleConditions(runCond, common{:});

            testCase.verifyEqual(newCond, oldCond, "新しい呼び方の出力が、今の呼び方と違う（" + CycleCase + "）");
            testCase.verifyEqual(string(fieldnames(newCond))', string(fieldnames(oldCond))', ...
                "新しい呼び方の出力のフィールドの順が、今の呼び方と違う（" + CycleCase + "）");
        end

        function testOldCallKeepsFields(testCase)
            % 今の呼び方（name-value だけ）の出力の形と既定値は変わらない
            c = cycleConditions(Upsampling="origD", Date="0731", SaveDir="out", LMask=20, ThHist=150, ...
                DThresh=0.6, WTh=8, Tol=3, BinWidth=5, HPrl=8);
            testCase.verifyEqual(string(fieldnames(c))', testCase.CYCLE_FIELDS);
            testCase.verifyEqual([c.numImages c.numSegments c.totalSegments c.polyDegree c.rpm], [8 10 80 3 78]);
            testCase.verifyEqual(c.experimentDir, "");
            testCase.verifyEqual(c.filenames, strings(0,1));
            testCase.verifyEqual(c.scriptName, "");
        end

        function testNewCallErrors(testCase)
            % 2つの書き方を混ぜたとき、必要なグループが無いとき、高解像度化が2つ以上のとき
            rc = runConditions(Upsampling="origD", LMask=20, DThresh=0.6, WidthThresh=8, ...
                Selection="manual", Manual=struct(thHist=150, tol=3, binWidth=5, hPrl=8));
            common = {"Date","2026-1124", "SaveDir",fullfile(testCase.root,"out")};
            testCase.verifyError(@() cycleConditions(rc, common{:}, "LMask", 20), "cycleConditions:mixedForms");
            testCase.verifyError(@() cycleConditions(rc, common{:}, "Upsampling", "origD"), "cycleConditions:mixedForms");
            testCase.verifyError(@() cycleConditions(rc, common{:}, "PolyDegree", 3), "cycleConditions:mixedForms");

            testCase.verifyError(@() cycleConditions(rmfield(rc, "upsampling"), common{:}), ...
                "cycleConditions:missingArgument");
            noMask = runConditions(Upsampling="origD", DThresh=0.6, WidthThresh=8);
            testCase.verifyError(@() cycleConditions(noMask, common{:}), "cycleConditions:missingArgument");
            noBottom = runConditions(Upsampling="origD", LMask=20);
            testCase.verifyError(@() cycleConditions(noBottom, common{:}), "cycleConditions:missingArgument");

            two = runConditions(Upsampling=["rsmplD","intpD"], PRsmpl=8, QRsmpl=1, QueryStep=0.125, ...
                InterpMethod="spline", LMask=20, DThresh=0.6, WidthThresh=8);
            testCase.verifyError(@() cycleConditions(two, common{:}), "cycleConditions:multipleUpsampling");
        end
    end

    %% figureDir
    methods (Test)

        function testFigureDirPaths(testCase)
            % 進捗報告用は results/figures/progress/<テーマ>、スライド用・原稿用は
            % results/figures/<発表名>/<用途>。フォルダを作り、末尾に区切り文字を付けない
            figRoot = fullfile(testCase.root, "results", "figures");
            cases = ["progress", "grooveTracking", fullfile(figRoot, "progress", "grooveTracking")
                     "slides",   "202609asj",      fullfile(figRoot, "202609asj", "slides")
                     "paper",    "202609asj",      fullfile(figRoot, "202609asj", "paper")
                     "paper",    "202702thesis",   fullfile(figRoot, "202702thesis", "paper")];
            for k = 1:size(cases, 1)
                p = figureDir(testCase.root, cases(k,1), cases(k,2));
                testCase.verifyEqual(string(p), cases(k,3), "figureDir(" + cases(k,1) + ", " + cases(k,2) + ") のパス");
                testCase.verifyTrue(isfolder(cases(k,3)), "フォルダを作っていない：" + cases(k,3));
            end
            % すでにあっても、エラーにならず同じパスを返す
            testCase.verifyEqual(string(figureDir(testCase.root, "slides", "202609asj")), cases(2,3));
        end

        function testFigureDirErrors(testCase)
            % 発表名は「年月6桁と略称」、テーマは camelCase。外れたらエラーにし、フォルダを作らない
            for v = ["202609", "asj202609", "2026asj", "202609ASJ", "202609-asj"]
                testCase.verifyError(@() figureDir(testCase.root, "slides", v), "figureDir:invalidVenue", ...
                    "発表名 """ + v + """ をエラーにしていない（slides）");
                testCase.verifyError(@() figureDir(testCase.root, "paper", v), "figureDir:invalidVenue", ...
                    "発表名 """ + v + """ をエラーにしていない（paper）");
            end
            for t = ["Grooves", "groove-tracking", "202609asj"]
                testCase.verifyError(@() figureDir(testCase.root, "progress", t), "figureDir:invalidTheme", ...
                    "テーマ """ + t + """ をエラーにしていない");
            end
            testCase.verifyError(@() figureDir(testCase.root, "poster", "202609asj"), ?MException);
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results")), "エラーなのにフォルダを作った");
        end
    end

    %% collectMeta・gitState と、saveCycleResult が保存する meta
    methods (Test)

        function testCollectMetaFields(testCase)
            m = collectMeta("fooScript");
            testCase.verifyEqual(string(fieldnames(m))', testCase.META_FIELDS, ...
                "collectMeta のフィールドの名前・順が、今の saveCycleResult のものと違う");
            testCase.verifyEqual(string(m.scriptName), "fooScript");
            testCase.verifyClass(m.savedAt, "datetime");
            testCase.verifyClass(m.gitDirty, "logical");

            m2 = collectMeta("fooScript", IncludeBranch=true);
            testCase.verifyEqual(string(fieldnames(m2))', [testCase.META_FIELDS "gitBranch"], ...
                "IncludeBranch=true のとき、gitBranch が最後に付いていない");
        end

        function testGitStateOutsideRepository(testCase)
            % git のリポジトリでないフォルダでも、エラーにならず空の値を返す
            [commit, isDirty, branch] = gitState(testCase.root);
            testCase.verifyEqual(string(commit), "");
            testCase.verifyEqual(isDirty, false);
            testCase.verifyEqual(string(branch), "");
        end

        function testSaveCycleResultMetaUnchanged(testCase)
            % saveCycleResult が保存する meta は、今と同じ8つのフィールド（gitBranch は足さない）
            img = repmat([255*ones(5,1); 10; 10; 255*ones(5,1)], 1, 10);
            allImg = ImageData(img, [1; 1]);
            y = sin(2*pi*(1:10)'/10);
            res = cycleMethodResult("centroid", GroovePointCloud(), {(1:10)'}, {y}, y, AudioData("test", y, 100));
            cond = cycleConditions(Upsampling="origD", Date="2026-1124", SaveDir=testCase.root, ...
                NumImages=1, NumSegments=1, LMask=20, ThHist=150, DThresh=0.6, WTh=8, Tol=3, BinWidth=5, ...
                HPrl=8, ScriptName="ResultLayoutAcceptanceTest");
            matPath = saveCycleResult(cond, allImg, res);
            S = load(matPath, "result");
            testCase.verifyEqual(string(fieldnames(S.result.meta))', testCase.META_FIELDS, ...
                "saveCycleResult が保存する meta のフィールドが変わった");
            testCase.verifyEqual(string(S.result.meta.scriptName), "ResultLayoutAcceptanceTest");
        end
    end

    %% migrateResults（scripts/migration/）
    methods (Test)

        function testDryRunMovesNothing(testCase)
            % 既定（試し）では何も動かさず、行ごとに何をするかを返す
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");

            actions = migrateResults(testCase.root, csv, Phase="results");

            testCase.verifyOldTreeIntact("試しなのにファイルが動いた");
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results", "grooveTracking")), ...
                "試しなのに行き先のフォルダを作った");
            testCase.verifyTrue(isfolder(fullfile(testCase.root, "results", "0710")), "試しなのに空のフォルダを消した");
            testCase.verifyClass(actions, "table");
            kind = string(actions.kind);
            status = string(actions.status);
            testCase.verifyEqual(unique(string(actions.phase))', "results", "Phase=""results"" なのに experiments の行を扱った");
            testCase.verifyTrue(all(status(kind == "deleteEmpty") == "delete"), ...
                "空のフォルダを消す行の status が delete でない");
            testCase.verifyTrue(all(status(kind ~= "deleteEmpty") == "move"), ...
                "移す行の status が move でない");
            testCase.verifyEqual(sum(actions.count(kind == "files")), 6, ...
                "パターンで移すファイルの数（6）が count に出ていない");
        end

        function testExecuteMovesAndIsIdempotent(testCase)
            % 実行すると移し、空になった元のフォルダを消す。もう一度呼ぶと、すべて移し終えた（done）になる
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");

            migrateResults(testCase.root, csv, Phase="results", DryRun=false);

            isResults = startsWith(testCase.MIGRATION_FILES(:,1), "results/");
            testCase.verifyMoved(testCase.MIGRATION_FILES(isResults, :));
            for d = ["results/0710", "results/0721", "results/1014", "results/figures/paper"]
                testCase.verifyFalse(isfolder(testCase.absPath(d)), "元のフォルダが残っている：" + d);
            end
            testCase.verifyTrue(isfile(testCase.absPath("experiments/1014/cycleResult_origD_1014.mat")), ...
                "Phase=""results"" なのに experiments を動かした");

            again = migrateResults(testCase.root, csv, Phase="results");
            testCase.verifyTrue(all(string(again.status) == "done"), ...
                "移し終えた後の試しで、done でない行がある");
        end

        function testExperimentsPhaseRenames(testCase)
            % experiments の段階では、1ファイルずつ名前を変えて移し、空になったフォルダを消す。archive は変えない
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");

            migrateResults(testCase.root, csv, Phase="experiments", DryRun=false);

            isExp = startsWith(testCase.MIGRATION_FILES(:,1), "experiments/");
            testCase.verifyMoved(testCase.MIGRATION_FILES(isExp, :));
            testCase.verifyFalse(isfolder(testCase.absPath("experiments/1014")), "元のフォルダ experiments/1014 が残っている");
            testCase.verifyFalse(isfolder(testCase.absPath("experiments/1026")), "空のフォルダ experiments/1026 が残っている");
            testCase.verifyTrue(isfile(testCase.absPath("results/1014/evalTrack_rmse.png")), ...
                "Phase=""experiments"" なのに results を動かした");

            again = migrateResults(testCase.root, csv, Phase="experiments");
            testCase.verifyTrue(all(string(again.status) == "done"), "移し終えた後の試しで、done でない行がある");
        end

        function testExistingDestinationFileStopsEverything(testCase)
            % 行き先に同じ名前のファイルがあれば、上書きせずにエラーにし、どの行も動かさない
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");
            existing = testCase.absPath("results/grooveTracking/2026-1014_track/grooveTrack_img1.png");
            mkdir(fileparts(existing));
            writelines("既存のファイル", existing);

            testCase.verifyError(@() migrateResults(testCase.root, csv, Phase="results", DryRun=false), ...
                "migrateResults:destinationExists");
            testCase.verifyOldTreeIntact("エラーで止まったのに、ファイルが動いた");
            testCase.verifyEqual(strtrim(string(fileread(existing, Encoding="UTF-8"))), "既存のファイル", "行き先のファイルを上書きした");
        end

        function testExistingDestinationFolderStopsEverything(testCase)
            % フォルダごと移す行で、行き先のフォルダがすでにあればエラーにし、どの行も動かさない
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");
            mkdir(testCase.absPath("results/upsampling/2026-0721"));

            testCase.verifyError(@() migrateResults(testCase.root, csv, Phase="results", DryRun=false), ...
                "migrateResults:destinationExists");
            testCase.verifyOldTreeIntact("エラーで止まったのに、ファイルが動いた");
        end

        function testUnmatchedFileStopsEverything(testCase)
            % どの行にも当たらないファイルが元のフォルダに残るなら、エラーにし、どの行も動かさない
            testCase.addMigrationPath();
            testCase.makeOldTree();
            writelines("どの行にも当たらない", testCase.absPath("results/1014/unexpected.txt"));
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");

            testCase.verifyError(@() migrateResults(testCase.root, csv, Phase="results", DryRun=false), ...
                "migrateResults:unmatchedFiles");
            testCase.verifyOldTreeIntact("エラーで止まったのに、ファイルが動いた");
            testCase.verifyTrue(isfile(testCase.absPath("results/1014/unexpected.txt")));
        end

        function testMissingSourceWarnsAndSkips(testCase)
            % 元も行き先も無い行は、警告を出して飛ばす（一部のフォルダが無い PC でも動かせるように）
            testCase.addMigrationPath();
            testCase.makeOldTree();
            lines = [testCase.MAPPING_LINES; "results,dir,results/0999,results/upsampling/2026-0999,"];
            csv = testCase.writeMapping(lines, "mapping.csv");

            actions = testCase.verifyWarning(@() migrateResults(testCase.root, csv, Phase="results"), ...
                "migrateResults:sourceMissing");
            status = string(actions.status);
            isMissingRow = contains(string(actions.source), "0999");
            testCase.verifyEqual(status(isMissingRow), "missing", "元も行き先も無い行の status が missing でない");
            testCase.verifyTrue(all(ismember(status(~isMissingRow), ["move","delete"])));
        end

        function testResumesAfterInterruption(testCase)
            % 途中で止まった移行も、もう一度呼べば、移し終えたものを飛ばして続きを移す
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");
            mkdir(testCase.absPath("results/grooveTracking/2026-1014_track"));
            movefile(testCase.absPath("results/1014/grooveTrack_img1.png"), ...
                testCase.absPath("results/grooveTracking/2026-1014_track/grooveTrack_img1.png"));
            mkdir(testCase.absPath("results/upsampling"));
            movefile(testCase.absPath("results/0721"), testCase.absPath("results/upsampling/2026-0721"));

            migrateResults(testCase.root, csv, Phase="results", DryRun=false);

            isResults = startsWith(testCase.MIGRATION_FILES(:,1), "results/");
            testCase.verifyMoved(testCase.MIGRATION_FILES(isResults, :));
            again = migrateResults(testCase.root, csv, Phase="results");
            testCase.verifyTrue(all(string(again.status) == "done"), "続きを移した後の試しで、done でない行がある");
        end

        function testMappingErrors(testCase)
            % Phase を渡さない、知らない kind、列が足りない対応表はエラーにし、何も動かさない
            testCase.addMigrationPath();
            testCase.makeOldTree();
            csv = testCase.writeMapping(testCase.MAPPING_LINES, "mapping.csv");
            testCase.verifyError(@() migrateResults(testCase.root, csv), "migrateResults:missingPhase");

            badKind = testCase.writeMapping(["phase,kind,source,destination,note"
                "results,move,results/0721,results/upsampling/2026-0721,"], "badKind.csv");
            testCase.verifyError(@() migrateResults(testCase.root, badKind, Phase="results", DryRun=false), ...
                "migrateResults:invalidMapping");
            noDest = testCase.writeMapping(["phase,kind,source,note"
                "results,dir,results/0721,"], "noDest.csv");
            testCase.verifyError(@() migrateResults(testCase.root, noDest, Phase="results", DryRun=false), ...
                "migrateResults:invalidMapping");
            testCase.verifyOldTreeIntact("対応表の誤りで止まったのに、ファイルが動いた");
        end
    end

    %% 補助
    methods (Access = protected)

        function p = absPath(testCase, rel)
            % ルートからの / 区切りの相対パスを、この OS の絶対パスにする
            p = testCase.root + filesep + replace(rel, "/", filesep);
        end

        function files = runInfoFiles(testCase)
            listing = dir(fullfile(testCase.root, "**", "runInfo.json"));
            files = string({listing.name});
        end

        function [info, txt] = readRunInfo(~, outDir)
            jsonPath = fullfile(outDir, "runInfo.json");
            txt = fileread(jsonPath, Encoding="UTF-8");
            info = jsondecode(txt);
        end

        function verifyFieldOrder(testCase, s, expected)
            testCase.verifyEqual(string(fieldnames(s))', string(expected), ...
                "フィールドの名前か順が plan.md 4.3 と違う");
        end

        function [oldArgs, runArgs] = cycleCaseArgs(~, name)
            % 各スクリプトの今の cycleConditions の呼び出しと同じ定数（plan.md 付録 A.4）
            common = {"NumImages",8, "NumSegments",10, "LMask",20, "DThresh",0.6};
            manualOld = {"WTh",8, "ThHist",150, "Tol",3, "BinWidth",5, "HPrl",8};
            manualRun = {"Methods",["centroid","localMax"], "WidthThresh",8, "Selection","manual", ...
                "ReplayFrom","experiments/2026-1014/cycleResult_origD_2026-1014.mat", ...
                "Manual",struct(thHist=150, tol=3, binWidth=5, hPrl=8)};
            tracking = struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40, ...
                minFitPoints=5);
            autoRun = {"Methods",["centroid","localMax"], "WidthThresh",4, "PolyDegree",9, ...
                "DetrendScope","photo", "Rpm",78, "AmpDiv",1.5};
            switch name
                case "origDManual"
                    up = {"Upsampling","origD"};
                    oldArgs = [up, common, manualOld];
                    runArgs = [up, common, manualRun];
                case "rsmplDManual"
                    up = {"Upsampling","rsmplD", "PRsmpl",8, "QRsmpl",1};
                    oldArgs = [up, common, manualOld];
                    runArgs = [up, common, manualRun];
                case "intpDManual"
                    up = {"Upsampling","intpD", "QueryStep",0.125, "InterpMethod","spline"};
                    oldArgs = [up, common, manualOld];
                    runArgs = [up, common, manualRun];
                case "tracking"
                    up = {"Upsampling","origD"};
                    oldArgs = [up, common, {"WTh",4, "ThHist",NaN, "Tol",NaN, "BinWidth",NaN, "HPrl",NaN, ...
                        "PolyDegree",9, "Rpm",78}];
                    runArgs = [up, common, autoRun, {"Selection","tracking", "Tracking",tracking}];
                case "histogram"
                    % grooveHist_Ncycle.m は Tol に BAND_TOL、BinWidth に BIN_WIDTH を渡している（Q4）
                    up = {"Upsampling","origD"};
                    oldArgs = [up, common, {"WTh",4, "ThHist",NaN, "Tol",3, "BinWidth",1, "HPrl",NaN, ...
                        "PolyDegree",9, "Rpm",78}];
                    runArgs = [up, common, autoRun, {"Selection","histogram", "Tracking",tracking, ...
                        "Histogram",struct(numGrooves=5, binWidth=1, thHistRatio=0.3, bandTol=3)}];
            end
        end

        function addMigrationPath(testCase)
            % scripts/migration/ はプロジェクトのパスに入っていないので、このテストの間だけ足す
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            migrationDir = fullfile(thisDir, '..', '..', 'scripts', 'migration');
            testCase.assertTrue(isfolder(migrationDir), "scripts/migration/ がありません");
            testCase.applyFixture(PathFixture(migrationDir));
        end

        function makeOldTree(testCase)
            % 古い形の results/・experiments/ を合成する。中身は、移す前のパスの文字列にする
            % （移した後に、どのファイルが来たかを中身で確かめるため）
            for k = 1:size(testCase.MIGRATION_FILES, 1)
                oldPath = testCase.absPath(testCase.MIGRATION_FILES(k,1));
                folder = fileparts(oldPath);
                if ~isfolder(folder)
                    mkdir(folder);
                end
                writelines(testCase.MIGRATION_FILES(k,1), oldPath, Encoding="UTF-8");
            end
            mkdir(testCase.absPath("results/0710"));       % 空のフォルダ
            mkdir(testCase.absPath("experiments/1026"));   % 空のフォルダ
        end

        function csv = writeMapping(testCase, lines, name)
            csv = fullfile(testCase.root, name);
            writelines(lines, csv, Encoding="UTF-8");
        end

        function verifyOldTreeIntact(testCase, message)
            % 合成した移す前のファイルが、すべて元の場所に元の中身のまま残っている
            for k = 1:size(testCase.MIGRATION_FILES, 1)
                oldRel = testCase.MIGRATION_FILES(k,1);
                oldPath = testCase.absPath(oldRel);
                testCase.verifyTrue(isfile(oldPath), message + "：" + oldRel);
                if isfile(oldPath)
                    testCase.verifyEqual(strtrim(string(fileread(oldPath, Encoding="UTF-8"))), oldRel, message + "（中身）：" + oldRel);
                end
            end
        end

        function verifyMoved(testCase, pairs)
            % 移した後のパスに、移す前のファイルの中身がある。元の場所には無い（名前が同じものを除く）
            for k = 1:size(pairs, 1)
                newPath = testCase.absPath(pairs(k,2));
                testCase.verifyTrue(isfile(newPath), "移した先に無い：" + pairs(k,2));
                if isfile(newPath)
                    testCase.verifyEqual(strtrim(string(fileread(newPath, Encoding="UTF-8"))), pairs(k,1), ...
                        "移した先の中身が、移す前のファイルと違う：" + pairs(k,2));
                end
                if pairs(k,1) ~= pairs(k,2)
                    testCase.verifyFalse(isfile(testCase.absPath(pairs(k,1))), "元の場所に残っている：" + pairs(k,1));
                end
            end
        end
    end
end
