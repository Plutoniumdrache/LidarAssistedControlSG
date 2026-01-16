function [y] = dnormalizeData(x, normsettings)
%DNORMALIZEDATA
    y = mapminmax('reverse',x,normsettings);
end