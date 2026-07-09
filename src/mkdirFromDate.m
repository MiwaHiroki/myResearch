function dir = mkdirFromDate(rootFolder,date)

tmpDir = rootFolder+"\results\"+date;
if isfolder(tmpDir)
    dir = tmpDir;
else
    mkdir(tmpDir);
    dir = tmpDir;
end


end