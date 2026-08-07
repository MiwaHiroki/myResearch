% MediaData（抽象クラス）の単体テスト
%
% MediaData は継承されないまま孤立していたため src/archive/ へ退避した
% （rename-proposal.md の P3、2026-08-07）。それに伴いこのテストも
% test/archive/ に移し、runAllTests（test/unit/ のみを探索）の対象外にしている。
% 参照用に残しているだけなので、実行したいときは手動で
%   runtests('test/archive/MediaDataTest.m')
% を呼ぶ（PathFixture は src/archive/ を指すようにしてある）。
classdef MediaDataTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir    = fullfile(thisDir, '..', '..', 'src', 'archive');
            helperDir = fullfile(thisDir, 'helpers');
            testCase.applyFixture(PathFixture(srcDir));
            testCase.applyFixture(PathFixture(helperDir));
        end
    end

    methods (Test)
        function testIsAbstractClass(testCase)
            mc = ?MediaData;
            testCase.verifyTrue(mc.Abstract, ...
                "MediaData は抽象クラスであるべき");
        end

        function testIsHandleClass(testCase)
            testCase.verifyTrue(ismember("handle", superclasses("MediaData")), ...
                "MediaData は handle を継承しているべき");
        end

        function testCannotInstantiateAbstract(testCase)
            testCase.verifyError(@() MediaData("x"), ...
                "MATLAB:class:abstract");
        end

        function testSaveIsAbstractMethod(testCase)
            mc = ?MediaData;
            methodNames = {mc.MethodList.Name};
            saveMeta = mc.MethodList(strcmp(methodNames, "save"));
            testCase.assertNotEmpty(saveMeta, "save メソッドが定義されているべき");
            testCase.verifyTrue(saveMeta.Abstract, "save は抽象メソッドであるべき");
        end

        function testConstructorSetsName(testCase)
            obj = ConcreteMediaData("track01");
            testCase.verifyEqual(obj.Name, "track01");
        end

        function testHandleSemanticsSharedState(testCase)
            a = ConcreteMediaData("first");
            b = a;                 % handle なので同一オブジェクトを参照
            b.Name = "second";
            testCase.verifyEqual(a.Name, "second", ...
                "handle クラスなので b の変更が a にも反映されるべき");
        end

        function testSubclassSaveOverride(testCase)
            obj = ConcreteMediaData("x");
            obj.save("./out/");
            testCase.verifyTrue(obj.SaveWasCalled);
            testCase.verifyEqual(obj.SaveDir, "./out/");
        end
    end
end
