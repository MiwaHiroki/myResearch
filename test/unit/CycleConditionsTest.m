% cycleConditions の新しい呼び方（runConditions の出力を受け取る）の単体テスト
%
% 同じ定数から今の呼び方と新しい呼び方で作った conditions が等しいこと（NaN を含むので
% isequal ではなく verifyEqual で比べる）と、写し方の細目・エラーを確かめる。
% 今の呼び方そのもののテストは CycleResultTest にある（変えない）。
classdef CycleConditionsTest < matlab.unittest.TestCase

    properties (TestParameter)
        % plan.md 6章の5つの場合
        CycleCase = {"origDManual", "rsmplDManual", "intpDManual", "tracking", "histogram"}
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testNewCallEqualsOldCall(testCase, CycleCase)
            [oldArgs, runArgs] = CycleConditionsTest.caseArgs(CycleCase);
            run = {"Date","2026-1124", "SaveDir","out", "ExperimentDir","exp", ...
                "Filenames",["f1";"f2"], "SegmentXRanges",[1 10; 11 20], "ScriptName","s", "Note","n"};
            oldCond = cycleConditions(oldArgs{:}, run{:});
            newCond = cycleConditions(runConditions(runArgs{:}), run{:});
            testCase.verifyEqual(newCond, oldCond);
            testCase.verifyEqual(string(fieldnames(newCond))', string(fieldnames(oldCond))');
            testCase.verifyTrue(isequaln(newCond, oldCond), "isequaln でも等しくない");
        end

        function testScaleFactorIsComputedFromRunConditions(testCase)
            base = {"LMask",20, "DThresh",0.6, "WidthThresh",8};
            c = cycleConditions(runConditions("Upsampling","rsmplD", "PRsmpl",8, "QRsmpl",2, base{:}), ...
                Date="2026-1124", SaveDir="out");
            testCase.verifyEqual(c.upsampling.scaleFactor, 4);
            c = cycleConditions(runConditions("Upsampling","intpD", "QueryStep",0.125, "InterpMethod","spline", base{:}), ...
                Date="2026-1124", SaveDir="out");
            testCase.verifyEqual(c.upsampling.scaleFactor, 8);
            testCase.verifyEqual(c.upsampling.interpMethod, "spline");
        end

        function testDefaultsWhenGroupsAreMissing(testCase)
            % segmentation の枚数、detrend、audio が無ければ、今の呼び方の既定値（8・10・3・78）
            rc = runConditions(Upsampling="origD", LMask=20, DThresh=0.6, WidthThresh=8);
            c = cycleConditions(rc, Date="2026-1124", SaveDir="out");
            testCase.verifyEqual([c.numImages c.numSegments c.totalSegments c.polyDegree c.rpm], [8 10 80 3 78]);
            testCase.verifyTrue(all(isnan([c.thHist c.tol c.binWidth c.hPrl])), ...
                "Manual・Histogram が無いのに NaN でない");
            testCase.verifyEqual(c.experimentDir, "");
            testCase.verifyEqual(c.filenames, strings(0,1));
            testCase.verifyEqual(c.note, "");
        end

        function testSegmentationAndAudioAreCopied(testCase)
            rc = runConditions(Upsampling="origD", NumImages=2, NumSegments=3, LMask=20, DThresh=0.6, ...
                WidthThresh=8, PolyDegree=5, Rpm=45);
            c = cycleConditions(rc, Date="2026-1124", SaveDir="out");
            testCase.verifyEqual([c.numImages c.numSegments c.totalSegments c.polyDegree c.rpm], [2 3 6 5 45]);
        end

        function testOldCallDefaultsUnchanged(testCase)
            % 既定値を arguments からコードの中へ移しても、今の呼び方の出力は変わらない
            c = cycleConditions(Upsampling="origD", Date="0731", SaveDir="out", LMask=20, ThHist=150, ...
                DThresh=0.6, WTh=8, Tol=3, BinWidth=5, HPrl=8);
            testCase.verifyEqual([c.numImages c.numSegments c.totalSegments c.polyDegree c.rpm], [8 10 80 3 78]);
            c = cycleConditions(Upsampling="origD", Date="0731", SaveDir="out", LMask=20, ThHist=150, ...
                DThresh=0.6, WTh=8, Tol=3, BinWidth=5, HPrl=8, NumImages=2, NumSegments=5);
            testCase.verifyEqual(c.totalSegments, 10);
        end

        function testMixedFormsError(testCase)
            rc = runConditions(Upsampling="origD", LMask=20, DThresh=0.6, WidthThresh=8);
            for name = ["ThHist","DThresh","WTh","Tol","BinWidth","HPrl","NumImages","NumSegments","Rpm", ...
                    "PRsmpl","QRsmpl","QueryStep"]
                testCase.verifyError(@() cycleConditions(rc, "Date","2026-1124", "SaveDir","out", name,1), ...
                    "cycleConditions:mixedForms", name + " を一緒に渡しても止めない");
            end
            testCase.verifyError(@() cycleConditions(rc, Date="2026-1124", SaveDir="out", InterpMethod="linear"), ...
                "cycleConditions:mixedForms");
        end

        function testMissingArgumentErrors(testCase)
            base = {"Upsampling","origD", "LMask",20, "DThresh",0.6, "WidthThresh",8};
            run = {"Date","2026-1124", "SaveDir","out"};
            noWidth = runConditions("Upsampling","origD", "LMask",20, "DThresh",0.6);
            testCase.verifyError(@() cycleConditions(noWidth, run{:}), "cycleConditions:missingArgument");
            partialManual = runConditions(base{:}, "Selection","manual", "Manual",struct(thHist=150, tol=3));
            testCase.verifyError(@() cycleConditions(partialManual, run{:}), "cycleConditions:missingArgument");
            partialHist = runConditions(base{:}, "Selection","histogram", "Histogram",struct(binWidth=1));
            testCase.verifyError(@() cycleConditions(partialHist, run{:}), "cycleConditions:missingArgument");
            full = runConditions(base{:});
            testCase.verifyError(@() cycleConditions(full, SaveDir="out"), "cycleConditions:missingArgument", ...
                "Date が無いのに止めない");
            noKind = full;
            noKind.upsampling = struct();
            testCase.verifyError(@() cycleConditions(noKind, run{:}), "cycleConditions:missingArgument");
        end

        function testManualTakesPriorityOverHistogram(testCase)
            rc = runConditions(Upsampling="origD", LMask=20, DThresh=0.6, WidthThresh=8, ...
                Histogram=struct(binWidth=1, bandTol=3), Manual=struct(thHist=150, tol=4, binWidth=5, hPrl=8));
            c = cycleConditions(rc, Date="2026-1124", SaveDir="out");
            testCase.verifyEqual([c.thHist c.tol c.binWidth c.hPrl], [150 4 5 8]);
        end
    end

    methods (Static, Access = private)
        function [oldArgs, runArgs] = caseArgs(name)
            % 各スクリプトの今の cycleConditions の呼び出しと同じ定数（plan.md 付録 A.4）
            common = {"NumImages",8, "NumSegments",10, "LMask",20, "DThresh",0.6};
            manualOld = {"WTh",8, "ThHist",150, "Tol",3, "BinWidth",5, "HPrl",8};
            manualRun = {"Methods",["centroid","localMax"], "WidthThresh",8, "Selection","manual", ...
                "ReplayFrom","experiments/2026-1014/cycleResult_origD_2026-1014.mat", ...
                "Manual",struct(thHist=150, tol=3, binWidth=5, hPrl=8)};
            tracking = struct(tolerance=2, fitLength=60, snapRadius=10, initLength=20, maxGapLength=40, minFitPoints=5);
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
                    up = {"Upsampling","origD"};
                    oldArgs = [up, common, {"WTh",4, "ThHist",NaN, "Tol",3, "BinWidth",1, "HPrl",NaN, ...
                        "PolyDegree",9, "Rpm",78}];
                    runArgs = [up, common, autoRun, {"Selection","histogram", "Tracking",tracking, ...
                        "Histogram",struct(numGrooves=5, binWidth=1, thHistRatio=0.3, bandTol=3)}];
            end
        end
    end
end
