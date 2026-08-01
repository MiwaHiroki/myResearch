function dirPath = mkdirFromDate(rootFolder,date)
% mkdirFromDate  図・音声の出力先 results/<日付>/ を作りパスを返す。
%
% 戻り値は末尾に区切り文字が付く（呼び出し側が dir+filename と連結するため）。
% 実験結果の.matは寿命が違うので results/ ではなく experiments/ に置く。
% その保存先は experimentDir で得る。
%
% 関連: experimentDir, cycleResultPath

tmpDir = fullfile(rootFolder,"results",date) + filesep;
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end
dirPath = tmpDir;

end
