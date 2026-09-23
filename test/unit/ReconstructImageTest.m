% reconstructImage の単体テスト
%
% cycleResultにはImageData.imgを保存しない（issue#17）ため、必要な撮影画像
% （iImg）だけを元のPNGファイルから読み直して作り直せることを検証する。
% 合成PNGを一時フォルダに書き出し、PhotoDirとして渡す。
classdef ReconstructImageTest < matlab.unittest.TestCase

    properties (Constant)
        NUM_IMAGES   = 2
        NUM_SEGMENTS = 2
        IMG_H = 8
        IMG_W = 20   % NUM_SEGMENTS=2 で割り切れる幅
        L_MASK = 20  % どの画素もこれより大きいのでomitMaskは何もトリムしない
    end

    properties
        photoDir
        cond
        patternA
        patternB
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
        function writePhotosAndBuildConditions(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.photoDir = string(fixture.Folder);

            % iImg=1 用の撮影画像パターン（列ごとに異なる値、L_MASKより十分大きい）
            testCase.patternA = uint8(repmat(50 + (1:testCase.IMG_W), testCase.IMG_H, 1));
            % iImg=2 用の撮影画像パターン（別の値でpatternAと区別できるようにする）
            testCase.patternB = uint8(repmat(150 + (1:testCase.IMG_W), testCase.IMG_H, 1));

            imwrite(repmat(testCase.patternA, 1, 1, 3), fullfile(testCase.photoDir, "photoA.png"));
            imwrite(repmat(testCase.patternB, 1, 1, 3), fullfile(testCase.photoDir, "photoB.png"));

            % reconstructImage は fileIdx = numImages+1-iImg で反転して読むため、
            % iImg=1 が "photoA" になるように filenames(2)="photoA" とする
            % （filenames(1)="photoB" は iImg=2 用）。
            filenames = ["photoB"; "photoA"];

            testCase.cond = cycleConditions( ...
                Upsampling="origD", Date="0101", SaveDir=testCase.photoDir, ...
                NumImages=testCase.NUM_IMAGES, NumSegments=testCase.NUM_SEGMENTS, ...
                LMask=testCase.L_MASK, ThHist=150, DThresh=0.6, WTh=8, ...
                Tol=3, BinWidth=5, HPrl=8, ...
                Filenames=filenames, ScriptName="ReconstructImageTest");
        end
    end

    methods (Test)
        function testReturnsAllSegmentsForGivenIImg(testCase)
            imgs = testCase.reconstruct(1);

            testCase.verifyNumElements(imgs, testCase.NUM_SEGMENTS);
            for jSegment = 1:testCase.NUM_SEGMENTS
                testCase.verifyEqual(imgs(jSegment).imgID, [1;jSegment]);
            end
        end

        function testUsesReversedFileIndex(testCase)
            % iImg=1 -> photoA (patternA), iImg=2 -> photoB (patternB)
            imgsForImg1 = testCase.reconstruct(1);
            imgsForImg2 = testCase.reconstruct(2);

            divWidth = round(testCase.IMG_W / testCase.NUM_SEGMENTS);
            expectedSeg1FromA = testCase.patternA(:, 1:divWidth);
            expectedSeg1FromB = testCase.patternB(:, 1:divWidth);

            testCase.verifyEqual(double(imgsForImg1(1).img), double(expectedSeg1FromA));
            testCase.verifyEqual(double(imgsForImg2(1).img), double(expectedSeg1FromB));
        end

        function testPixelExactMatchWithManualPipeline(testCase)
            imgs = testCase.reconstruct(2);

            width = testCase.IMG_W;
            numSegments = testCase.NUM_SEGMENTS;
            divWidth = round(width/numSegments);
            xarray = [1:divWidth:width width+1]';

            imgGray = rgb2gray(imread(fullfile(testCase.photoDir, "photoB.png")));
            for jSegment = 1:numSegments
                imgSmall = imgGray(:, xarray(jSegment):xarray(jSegment+1)-1);
                expected = omitMask(imgSmall, testCase.L_MASK);
                testCase.verifyEqual(imgs(jSegment).img, double(expected), ...
                    "reconstructImage は imread->rgb2gray->crop->omitMask と同じ結果を返すべき");
            end
        end

        function testIndependentAcrossMultipleIImgCalls(testCase)
            imgs1 = testCase.reconstruct(1);
            imgs2 = testCase.reconstruct(2);

            testCase.verifyNumElements(imgs1, testCase.NUM_SEGMENTS);
            testCase.verifyNumElements(imgs2, testCase.NUM_SEGMENTS);
            testCase.verifyEqual(imgs1(1).imgID, [1;1]);
            testCase.verifyEqual(imgs2(1).imgID, [2;1]);
        end

        function testErrorsWhenFilenamesEmpty(testCase)
            condNoFilenames = testCase.cond;
            condNoFilenames.filenames = strings(0,1);

            testCase.verifyError(...
                @() reconstructImage(condNoFilenames, 1, PhotoDir=testCase.photoDir), ...
                "reconstructImage:noFilenames");
        end

        function testErrorsWhenIImgOutOfRange(testCase)
            testCase.verifyError(...
                @() reconstructImage(testCase.cond, testCase.NUM_IMAGES+1, PhotoDir=testCase.photoDir), ...
                "reconstructImage:iImgOutOfRange");
        end
    end

    methods
        function imgs = reconstruct(testCase, iImg)
            imgs = reconstructImage(testCase.cond, iImg, PhotoDir=testCase.photoDir);
        end
    end
end
