% runConditions（実験条件の入れ子の struct）の単体テスト
%
% 外側から見た仕様は ResultLayoutAcceptanceTest が確かめるので、ここでは実装の細部
% （キーの並べ直し、空の ReplayFrom、渡した値の記録、エラーの細目）を確かめる。
classdef RunConditionsTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testIssueExample(testCase)
            % issue #28 の例の呼び方で、runInfo.json の例と同じグループ・キー・値になる
            c = runConditions(LMask=20, Upsampling="origD", Methods=["centroid","localMax"], ...
                DThresh=0.6, WidthThresh=4, Selection="histogram", ...
                ReplayFrom="experiments/2026-1026/cycleResult_origD_track_2026-1026.mat", ...
                Tracking=struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40), ...
                Histogram=struct(numGrooves=5, binWidth=1, thHistRatio=0.3, bandTol=3), ...
                PolyDegree=9, DetrendScope="photo", AmpDiv=1.5);
            d = jsondecode(jsonencode(c));
            testCase.verifyEqual(string(fieldnames(d))', ...
                ["segmentation","upsampling","grooveBottom","grooveSelection","detrend","audio"]);
            testCase.verifyEqual([d.segmentation.numImages d.segmentation.numSegments d.segmentation.lMask], [8 10 20]);
            testCase.verifyEqual(string(d.upsampling.kind), "origD");
            testCase.verifyEqual(string(d.grooveBottom.methods), ["centroid";"localMax"]);
            testCase.verifyEqual(string(d.grooveSelection.replayFrom), ...
                "experiments/2026-1026/cycleResult_origD_track_2026-1026.mat");
            testCase.verifyEqual(d.grooveSelection.histogram.thHistRatio, 0.3);
            testCase.verifyEqual([d.detrend.polyDegree d.audio.rpm d.audio.ampDiv], [9 78 1.5]);
            testCase.verifyEqual(string(d.detrend.scope), "photo");
        end

        function testKeysAreReorderedWithinGroups(testCase)
            % struct で渡したキーも、表の順に並べ直す
            c = runConditions(Tracking=struct(minFitPoints=5, reclickImages=[3 7], tolerance=2, numGrooves=5), ...
                Manual=struct(hPrl=8, binWidth=5, tol=3, thHist=150), ...
                Histogram=struct(bandTol=3, numGrooves=5), ...
                Bilateral=struct(degreeOfSmoothing=650.25, kernelSizes=[3 5 9]));
            testCase.verifyEqual(string(fieldnames(c.grooveSelection.tracking))', ...
                ["tolerance","minFitPoints","numGrooves","reclickImages"]);
            testCase.verifyEqual(string(fieldnames(c.grooveSelection.manual))', ["thHist","tol","binWidth","hPrl"]);
            testCase.verifyEqual(string(fieldnames(c.grooveSelection.histogram))', ["numGrooves","bandTol"]);
            testCase.verifyEqual(string(fieldnames(c.preprocessing.bilateral))', ["kernelSizes","degreeOfSmoothing"]);
            testCase.verifyEqual(c.grooveSelection.tracking.reclickImages, {3, 7});
            testCase.verifyEqual(c.preprocessing.bilateral.kernelSizes, {3, 5, 9});
        end

        function testListsAreCellRows(testCase)
            c = runConditions(Upsampling=["rsmplD","intpD"], PRsmpl=8, QRsmpl=1, QueryStep=0.125, ...
                InterpMethod="spline", Methods="localMax");
            testCase.verifyEqual(c.upsampling.kind, {"rsmplD", "intpD"});
            testCase.verifyEqual(c.grooveBottom.methods, {"localMax"});
            testCase.verifyEqual(jsonencode(c.grooveBottom), '{"methods":["localMax"]}');
        end

        function testEmptyReplayFromIsNotGiven(testCase)
            % ReplayFrom="" だけなら grooveSelection を作らない（空のグループを書かない）
            c = runConditions(LMask=20, ReplayFrom="");
            testCase.verifyEqual(string(fieldnames(c))', "segmentation");
            c2 = runConditions(ReplayFrom="experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat");
            testCase.verifyEqual(string(fieldnames(c2.grooveSelection))', "replayFrom");
        end

        function testGivenUpsamplingParamsAreRecorded(testCase)
            % 高解像度化のパラメータは、kind に関係なく、渡したら記録する
            c = runConditions(Upsampling="origD", QueryStep=0.25);
            testCase.verifyEqual(string(fieldnames(c.upsampling))', ["kind","queryStep"]);
            testCase.verifyEqual(c.upsampling.queryStep, 0.25);
        end

        function testRegionAndOtherArePassedThrough(testCase)
            c = runConditions(Region=struct(imgIndex=1, jSegment=3, rows=[100 200]), ...
                Other=struct(wMin=2, label="x"));
            testCase.verifyEqual(c.region, struct(imgIndex=1, jSegment=3, rows=[100 200]));
            testCase.verifyEqual(c.other, struct(wMin=2, label="x"));
        end

        function testDefaultsOnlyWhenGroupIsWritten(testCase)
            c = runConditions(NumImages=4, Rpm=45);
            testCase.verifyEqual(c.segmentation, struct(numImages=4, numSegments=10));
            testCase.verifyEqual(c.audio, struct(rpm=45));
            c2 = runConditions(Methods="centroid");
            testCase.verifyFalse(isfield(c2, "segmentation"));
            testCase.verifyFalse(isfield(c2, "audio"));
        end

        function testErrors(testCase)
            testCase.verifyError(@() runConditions(Upsampling="rsmplD", QRsmpl=1), "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Upsampling="intpD", QueryStep=0.125), "runConditions:missingArgument");
            testCase.verifyError(@() runConditions(Tracking=struct(tolerence=2)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Histogram=struct(tol=3)), "runConditions:unknownField");
            testCase.verifyError(@() runConditions(Tracking=struct(tolerance=struct(a=1))), "runConditions:tooDeep");
            testCase.verifyError(@() runConditions(Bilateral=struct(kernelSizes=struct(a=1))), "runConditions:tooDeep");
            testCase.verifyError(@() runConditions(Upsampling="bicubic"), ?MException);
            testCase.verifyError(@() runConditions(Methods="mean"), ?MException);
            testCase.verifyError(@() runConditions(Selection="auto"), ?MException);
            testCase.verifyError(@() runConditions(DetrendScope="cycle"), ?MException);
            testCase.verifyError(@() runConditions(Bar=1), "MATLAB:TooManyInputs");
        end
    end
end
