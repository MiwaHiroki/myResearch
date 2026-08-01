% 1周分の実験結果の保存・読み込み（cycleConditions, cycleMethodResult,
% cycleResultFileName, cycleResultPath, experimentDir, saveCycleResult,
% loadCycleResult）の単体テスト
%
% saveDir はテスト用の一時フォルダで、experiments/ 側を試すテストでは
% プロジェクトのルートフォルダに見立てて使う。
classdef CycleResultTest < matlab.unittest.TestCase

    properties (Constant)
        N_SEG = 4      % テスト用のセグメント数（2画像 x 2分割）
        IMG_H = 12
        IMG_W = 10
        FS    = 100
        DATE  = "0101"
    end

    properties
        saveDir
        cond
        allImg
        allD
        resCnt
        resMax
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
        function makeTempDir(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.saveDir = string(fixture.Folder);
        end

        function buildData(testCase)
            n = testCase.N_SEG;

            imgArr(n,1) = ImageData();
            dArr(n,1)   = DarknessValue();
            ptsCnt(n,1) = GrooveCandidates();
            ptsMax(n,1) = GrooveCandidates();
            xcoords = cell(n,1);
            ycoords = cell(n,1);

            for k = 1:n
                % 上下が明るく中央が暗い（溝底が1本ある）縦方向のパターン
                col = 255*ones(testCase.IMG_H,1);
                col(6:7) = 10;
                img = repmat(col, 1, testCase.IMG_W);

                imgData = ImageData(img, [1; k]);
                dValue  = setDiffTF(DarknessValue(imgData), 0.6);

                pts = GrooveCandidates(dValue);
                for x = 1:imgData.width
                    [startIdx, endIdx] = dValue.getStartEndIdx(x);
                    [dValue, ~, ~, pksNum] = ...
                        getGrooveBtmIdx(dValue, x, startIdx, endIdx, 8);
                    pts.pksCell{x} = [x*ones(pksNum,1), dValue.extractGrv_cnt(x)];
                end

                imgArr(k) = imgData;
                dArr(k)   = dValue;
                ptsCnt(k) = pts;
                ptsMax(k) = pts;

                xcoords{k} = (1:testCase.IMG_W)';
                ycoords{k} = sin(2*pi*(1:testCase.IMG_W)'/testCase.IMG_W);
            end

            yComb = vertcat(ycoords{:});
            audioCnt = AudioData("test audio (centroid)", yComb, testCase.FS);
            audioMax = AudioData("test audio (localMax)", yComb, testCase.FS);

            testCase.allImg = imgArr;
            testCase.allD   = dArr;
            testCase.resCnt = cycleMethodResult("centroid", ptsCnt, xcoords, ycoords, yComb, audioCnt);
            testCase.resMax = cycleMethodResult("localMax", ptsMax, xcoords, ycoords, yComb, audioMax);

            testCase.cond = cycleConditions( ...
                Upsampling="intpD", Date=testCase.DATE, SaveDir=testCase.saveDir, ...
                NumImages=2, NumSegments=2, ...
                LMask=20, ThHist=150, DThresh=0.6, WTh=8, ...
                Tol=3, BinWidth=5, HPrl=8, ...
                QueryStep=0.25, InterpMethod="spline", ...
                Filenames=["a.png";"b.png"], ScriptName="CycleResultTest");
        end
    end

    methods (Test)

        function testConditionsHoldsUpsamplingParams(testCase)
            testCase.verifyEqual(testCase.cond.upsampling.kind, "intpD");
            testCase.verifyEqual(testCase.cond.upsampling.queryStep, 0.25);
            testCase.verifyEqual(testCase.cond.upsampling.scaleFactor, 4);
            testCase.verifyEqual(testCase.cond.totalSegments, testCase.N_SEG);
        end

        function testConditionsRequiresConstants(testCase)
            % DThresh を渡さなければエラーになる
            testCase.verifyError( ...
                @() cycleConditions(Upsampling="origD", Date="0101", ...
                    SaveDir=testCase.saveDir, LMask=20, ThHist=150, ...
                    WTh=8, Tol=3, BinWidth=5, HPrl=8), ...
                "cycleConditions:missingArgument");
        end

        function testConditionsRequiresUpsamplingParams(testCase)
            % rsmplD なのに PRsmpl/QRsmpl が無い
            testCase.verifyError( ...
                @() cycleConditions(Upsampling="rsmplD", Date="0101", ...
                    SaveDir=testCase.saveDir, LMask=20, ThHist=150, DThresh=0.6, ...
                    WTh=8, Tol=3, BinWidth=5, HPrl=8), ...
                "cycleConditions:missingArgument");
        end

        function testMethodResultRejectsInconsistentYComb(testCase)
            testCase.verifyError( ...
                @() cycleMethodResult("centroid", testCase.resCnt.pts, ...
                    testCase.resCnt.xcoords, testCase.resCnt.ycoords, ...
                    [0;0;0], testCase.resCnt.audio), ...
                "cycleMethodResult:yCombLength");
        end

        function testMethodResultRejectsPartialWaveform(testCase)
            testCase.verifyError( ...
                @() cycleMethodResult("localMax", testCase.resCnt.pts, ...
                    testCase.resCnt.xcoords), ...
                "cycleMethodResult:partialWaveform");
        end

        function testMethodResultWithPtsOnlyRoundTrip(testCase)
            % 音声を作っていない手法は溝底候補点だけを保存できる
            resPtsOnly = cycleMethodResult("localMax", testCase.resMax.pts);
            testCase.verifyEmpty(resPtsOnly.audio);
            testCase.verifyEmpty(resPtsOnly.ycoords);

            matPath = saveCycleResult(testCase.cond, testCase.allImg, ...
                [testCase.resCnt resPtsOnly]);
            result = loadCycleResult(matPath);

            testCase.verifyNumElements(result.localMax.pts, testCase.N_SEG);
            testCase.verifyEmpty(result.localMax.audio);
            testCase.verifyClass(result.centroid.audio, "AudioData");
            testCase.verifySize(result.centroid.audio, [1 1]);
        end

        function testFileNameConvention(testCase)
            [matName, dName] = cycleResultFileName("rsmplD", "0724");
            testCase.verifyEqual(matName, "cycleResult_rsmplD_0724.mat");
            testCase.verifyEqual(dName, "cycleResult_rsmplD_0724_dValue.mat");
        end

        function testSaveAndLoadRoundTrip(testCase)
            matPath = saveCycleResult(testCase.cond, testCase.allImg, ...
                [testCase.resCnt testCase.resMax]);

            expectedPath = fullfile(testCase.saveDir, ...
                cycleResultFileName("intpD", testCase.DATE));
            testCase.verifyEqual(matPath, expectedPath);
            testCase.verifyTrue(isfile(matPath));

            % .mat に含まれる変数は result だけ
            vars = who("-file", matPath);
            testCase.verifyEqual(vars, {'result'});

            result = loadCycleResult(matPath);

            testCase.verifyEqual(result.conditions.dThresh, 0.6);
            testCase.verifyEqual(result.conditions.upsampling.kind, "intpD");
            testCase.verifyEqual(result.meta.scriptName, "CycleResultTest");
            testCase.verifyClass(result.meta.savedAt, "datetime");

            testCase.verifyClass(result.allImg, "ImageData");
            testCase.verifyNumElements(result.allImg, testCase.N_SEG);
            testCase.verifyEqual(result.allImg(2).imgID, [1;2]);

            % 手法ごとにフィールドが分かれている
            testCase.verifyTrue(isfield(result, "centroid"));
            testCase.verifyTrue(isfield(result, "localMax"));
            testCase.verifyFalse(isfield(result.centroid, "method"));

            testCase.verifyClass(result.centroid.pts, "GrooveCandidates");
            testCase.verifyNumElements(result.centroid.pts, testCase.N_SEG);
            testCase.verifyClass(result.centroid.audio, "AudioData");
            testCase.verifySize(result.centroid.audio, [1 1]);
            testCase.verifyEqual(result.centroid.audio.fs, testCase.FS);
            testCase.verifyEqual(result.centroid.y_comb, testCase.resCnt.y_comb, ...
                "AbsTol", 1e-12);
            testCase.verifyNumElements(result.centroid.xcoords, testCase.N_SEG);
            testCase.verifyNumElements(result.centroid.ycoords, testCase.N_SEG);

            % 既定では DarknessValue を保存しない
            testCase.verifyEqual(result.dValueFile, "");
        end

        function testSaveSingleMethod(testCase)
            matPath = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt);
            result  = loadCycleResult(matPath);
            testCase.verifyTrue(isfield(result, "centroid"));
            testCase.verifyFalse(isfield(result, "localMax"));
        end

        function testDarknessValuesGoToSidecarFile(testCase)
            [matPath, dValuePath] = saveCycleResult(testCase.cond, testCase.allImg, ...
                testCase.resCnt, DarknessValues=testCase.allD, SaveDarknessValues=true);

            testCase.verifyTrue(isfile(dValuePath));
            testCase.verifyEqual(dValuePath, fullfile(testCase.saveDir, ...
                "cycleResult_intpD_" + testCase.DATE + "_dValue.mat"));

            % 既定の load では allD は付いてこない
            result = loadCycleResult(matPath);
            testCase.verifyFalse(isfield(result, "allD"));
            testCase.verifyEqual(result.dValueFile, ...
                "cycleResult_intpD_" + testCase.DATE + "_dValue.mat");

            result = loadCycleResult(matPath, LoadDarknessValues=true);
            testCase.verifyClass(result.allD, "DarknessValue");
            testCase.verifyNumElements(result.allD, testCase.N_SEG);
            testCase.verifyEqual(result.allD(1).dMat, testCase.allD(1).dMat, ...
                "AbsTol", 1e-12);
        end

        function testLoadDarknessValuesErrorsWhenNotSaved(testCase)
            matPath = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt);
            testCase.verifyError(@() loadCycleResult(matPath, LoadDarknessValues=true), ...
                "loadCycleResult:noDarknessValues");
        end

        function testExistingFileIsNotOverwrittenByDefault(testCase)
            first = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt);

            second = testCase.verifyWarning( ...
                @() saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt), ...
                "saveCycleResult:fileExists");

            testCase.verifyNotEqual(second, first);
            testCase.verifyTrue(isfile(first));
            testCase.verifyTrue(isfile(second));
            testCase.verifyTrue(endsWith(second, "_2.mat"));
        end

        function testOverwriteReplacesFile(testCase)
            first  = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt);
            second = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt, ...
                Overwrite=true);
            testCase.verifyEqual(second, first);
            testCase.verifyEmpty(dir(fullfile(testCase.saveDir, "*_2.mat")));
        end

        function testRejectsDuplicateMethod(testCase)
            testCase.verifyError( ...
                @() saveCycleResult(testCase.cond, testCase.allImg, ...
                    [testCase.resCnt testCase.resCnt]), ...
                "saveCycleResult:duplicateMethod");
        end

        function testRejectsSegmentCountMismatchBetweenImgAndPts(testCase)
            testCase.verifyError( ...
                @() saveCycleResult(testCase.cond, testCase.allImg(1:2), testCase.resCnt), ...
                "saveCycleResult:sizeMismatch");
        end

        function testExperimentDirCreatesOnlyWhenAsked(testCase)
            root = testCase.saveDir;
            expected = fullfile(root, "experiments", testCase.DATE);

            % 読み込み側でパスを組むだけのときは空フォルダを作らない
            testCase.verifyEqual( ...
                experimentDir(root, testCase.DATE, Create=false), expected);
            testCase.verifyFalse(isfolder(expected));

            testCase.verifyEqual(experimentDir(root, testCase.DATE), expected);
            testCase.verifyTrue(isfolder(expected));
        end

        function testSaveGoesToExperimentDirNotSaveDir(testCase)
            % SaveDir は図・音声の出力先。結果.matは ExperimentDir 側に置く
            expDir = experimentDir(testCase.saveDir, testCase.DATE);
            cond2 = cycleConditions( ...
                Upsampling="origD", Date=testCase.DATE, ...
                SaveDir=testCase.saveDir, ExperimentDir=expDir, ...
                NumImages=2, NumSegments=2, ...
                LMask=20, ThHist=150, DThresh=0.6, WTh=8, ...
                Tol=3, BinWidth=5, HPrl=8, ScriptName="CycleResultTest");

            matPath = saveCycleResult(cond2, testCase.allImg, testCase.resCnt);

            testCase.verifyEqual(matPath, fullfile(expDir, ...
                cycleResultFileName("origD", testCase.DATE)));
            testCase.verifyEmpty(dir(fullfile(testCase.saveDir, "*.mat")));
        end

        function testSaveFallsBackToSaveDirWithoutExperimentDir(testCase)
            % ExperimentDir を渡していない conditions は従来どおり SaveDir に保存する
            matPath = saveCycleResult(testCase.cond, testCase.allImg, testCase.resCnt);
            testCase.verifyEqual(matPath, fullfile(testCase.saveDir, ...
                cycleResultFileName("intpD", testCase.DATE)));
        end

        function testCycleResultPathPrefersExperimentsOverResults(testCase)
            root = testCase.saveDir;
            matName = cycleResultFileName("origD", testCase.DATE);

            % 移行前の置き場にしか無ければ results/ 側を返す
            legacyDir = fullfile(root, "results", testCase.DATE);
            mkdir(legacyDir);
            legacyPath = fullfile(legacyDir, matName);
            touchFile(legacyPath);

            testCase.verifyEqual( ...
                cycleResultPath(root, "origD", testCase.DATE), legacyPath);

            % experiments/ にも置いたらそちらが優先される
            newPath = fullfile(experimentDir(root, testCase.DATE), matName);
            touchFile(newPath);

            testCase.verifyEqual( ...
                cycleResultPath(root, "origD", testCase.DATE), newPath);
        end

        function testCycleResultPathDefaultsToExperiments(testCase)
            % どこにも無ければ experiments/ 側のパスを返す（エラーメッセージが
            % 新しい置き場を指すように）
            root = testCase.saveDir;
            [matPath, dValuePath] = cycleResultPath(root, "intpD", testCase.DATE);

            [matName, dName] = cycleResultFileName("intpD", testCase.DATE);
            expDir = fullfile(root, "experiments", testCase.DATE);
            testCase.verifyEqual(matPath, fullfile(expDir, matName));
            testCase.verifyEqual(dValuePath, fullfile(expDir, dName));
        end

        function testSaveAndLoadRoundTripThroughCycleResultPath(testCase)
            % 保存側と読み込み側が同じ場所を指しているか
            root = testCase.saveDir;
            cond2 = cycleConditions( ...
                Upsampling="rsmplD", Date=testCase.DATE, ...
                SaveDir=root, ExperimentDir=experimentDir(root, testCase.DATE), ...
                NumImages=2, NumSegments=2, ...
                LMask=20, ThHist=150, DThresh=0.6, WTh=8, ...
                Tol=3, BinWidth=5, HPrl=8, PRsmpl=8, QRsmpl=1, ...
                ScriptName="CycleResultTest");

            saved = saveCycleResult(cond2, testCase.allImg, testCase.resCnt);
            found = cycleResultPath(root, "rsmplD", testCase.DATE);
            testCase.verifyEqual(found, saved);

            result = loadCycleResult(found);
            testCase.verifyEqual(result.conditions.upsampling.kind, "rsmplD");
        end

        function testLoadMissingFileGivesClearError(testCase)
            testCase.verifyError( ...
                @() loadCycleResult(fullfile(testCase.saveDir, "nope.mat")), ...
                "loadCycleResult:fileNotFound");
        end

    end
end


function touchFile(filePath)
% 中身を読まない探索のテスト用に空ファイルを作る
    fid = fopen(filePath, "w");
    fclose(fid);
end
