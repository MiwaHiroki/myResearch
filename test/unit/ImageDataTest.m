% ImageData クラスの単体テスト
classdef ImageDataTest < matlab.unittest.TestCase

    properties
        fig
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
        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testDefaultConstructorIsEmpty(testCase)
            obj = ImageData();
            testCase.verifyEmpty(obj.img, "img は空であるべき");
        end

        function testConstructorStoresImageAndId(testCase)
            img = reshape(1:15, 3, 5);   % 3行5列
            id  = [7; 9];
            obj = ImageData(img, id);

            testCase.verifyEqual(obj.img, img);
            testCase.verifyEqual(obj.imgID, id);
        end

        function testConstructorComputesHeightAndWidth(testCase)
            img = reshape(1:15, 3, 5);   % height=3, width=5
            obj = ImageData(img, [1; 1]);

            testCase.verifyEqual(obj.height, 3, "height は行数と一致すべき");
            testCase.verifyEqual(obj.width, 5, "width は列数と一致すべき");
        end

        function testClearImageEmptiesImgButKeepsMetadata(testCase)
            img = reshape(1:15, 3, 5);   % height=3, width=5
            id  = [7; 9];
            obj = ImageData(img, id);

            newObj = obj.clearImage();

            testCase.verifyEmpty(newObj.img, "clearImage 後は img が空であるべき");
            testCase.verifyEqual(newObj.imgID, id, "imgID は保持されるべき");
            testCase.verifyEqual(newObj.width, obj.width, "width は保持されるべき");
            testCase.verifyEqual(newObj.height, obj.height, "height は保持されるべき");

            testCase.verifyEqual(obj.img, img, "clearImage は元のオブジェクトを変更しないべき（値クラス）");
        end

        function testShowImageDrawsImage(testCase)
            img = 100 * ones(4, 6);
            obj = ImageData(img, [1; 1]);
            obj.showImage();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'image'), ...
                "showImage は image オブジェクトを描画すべき");
        end

        function testShowImageFitOption(testCase)
            img = 100 * ones(4, 6);
            obj = ImageData(img, [1; 1]);
            obj.showImage("fit");
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'image'));
        end

        function testShowImageInvalidArgumentErrors(testCase)
            img = 100 * ones(4, 6);
            obj = ImageData(img, [1; 1]);
            testCase.verifyError(@() obj.showImage("bogus"), ?MException);
        end
    end
end
