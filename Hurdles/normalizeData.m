function [y, normsettings] = normalizeData(x, normsettings)
%NORMALIZEDATA
% If normalization data set exist use it, if not generate

if exist('normsettings', 'var')
    y = mapminmax('apply',x,normsettings);
else
    [y, normsettings] = mapminmax(x);
end

end