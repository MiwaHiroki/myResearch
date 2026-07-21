num_samples = length(y);

seg = 0.1;
y2 = zeros(num_samples,1);
xVec = ([1:round(seg*fs):num_samples num_samples])';
for i=1:length(xVec)-1
    tmpXrange = xVec(i):xVec(i+1);
    tmpAmp = y(tmpXrange);
    y2(tmpXrange) = tmpAmp - mean(tmpAmp);
end

y2(abs(y2)>1)=0;
% amplitude2 = (amplitude2 - min(amplitude2)) / (max(amplitude2) - min(amplitude2)) * 2 - 1;

soundCheck(y2,fs,"DSC0120-0113 5cycles 0721-2");