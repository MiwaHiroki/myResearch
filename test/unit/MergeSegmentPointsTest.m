% mergeSegmentPoints の単体テスト
% （受け入れテスト GrooveTrackingAcceptanceTest で見ていない細部を確かめる）
classdef MergeSegmentPointsTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testPointsKeepSegmentOrder(testCase)
            % 連結はセグメントの順（ソートしない）。各セグメントの中の並びも変えない
            clouds = [ ...
                testCase.cloud(3, {[1 10; 1 20], [], [3 12]}); ...
                testCase.cloud(2, {[2 17], [1 16]})];

            pks = mergeSegmentPoints(clouds);

            testCase.verifyEqual(pks, [1 10; 1 20; 3 12; 5 17; 4 16]);
        end

        function testSingleSegmentHasZeroOffset(testCase)
            clouds = testCase.cloud(4, {[1 5], [2 6], [3 7], [4 8]});

            [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds);

            testCase.verifyEqual(xOffsets, 0);
            testCase.verifyEqual(counts, 4);
            testCase.verifyEqual(xQuery, (1:4)');
            testCase.verifyEqual(pks, [1 5; 2 6; 3 7; 4 8]);
        end

        function testAllSegmentsEmptyGivesZeroByTwo(testCase)
            % 点が1つも無くても pks は (0,2)、xQuery は列の数だけある
            clouds = [testCase.cloud(3, {[], [], []}); testCase.cloud(2, {[], []})];

            [pks, xQuery, counts] = mergeSegmentPoints(clouds);

            testCase.verifySize(pks, [0 2]);
            testCase.verifyEqual(xQuery, (1:5)');
            testCase.verifyEqual(counts, [3; 2]);
        end

        function testQueryStepNotDividingWidth(testCase)
            % width-1 が QueryStep で割り切れないとき、最後の列は width にならない
            % （dInterp の meshgrid(1:step:width,...) と同じ並び）
            clouds = [testCase.cloud(4, {[], [], [], []}); testCase.cloud(3, {[], [], []})];

            [~, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds, QueryStep=0.4);

            % 幅4：(4-1)/0.4 は割り切れないので最後は3.8。幅3：(3-1)/0.4=5 なので最後は3
            testCase.verifyEqual(counts, [8; 6]);
            testCase.verifyEqual(xOffsets, [0; 4]);
            expected = [1 1.4 1.8 2.2 2.6 3.0 3.4 3.8, 5 5.4 5.8 6.2 6.6 7.0]';
            testCase.verifyEqual(xQuery, expected, "AbsTol", 1e-12);
        end

        function testCountsSplitXQueryBySegment(testCase)
            % counts で mat2cell すると、各セグメントのローカルな列に xOffsets を足したものになる
            clouds = [testCase.cloud(3, {[], [], []}); testCase.cloud(4, {[], [], [], []}); ...
                testCase.cloud(2, {[], []})];

            [~, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds, QueryStep=0.5);

            segs = mat2cell(xQuery, counts);
            widths = [3; 4; 2];
            for j = 1:3
                testCase.verifyEqual(segs{j}, (1:0.5:widths(j))' + xOffsets(j), "AbsTol", 1e-12);
            end
        end
    end

    methods (Static, Access = private)
        function pc = cloud(width, cells)
            pc = GroovePointCloud();
            pc.imgID = [1; 1];
            pc.width = width;
            pc.height = 100;
            pc.peakCells = cells;
        end
    end
end
