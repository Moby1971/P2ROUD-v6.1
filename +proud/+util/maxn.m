function maksimi = maxn(matriisi)

% Largest element anywhere in an array
%
%   maksimi = proud.util.maxn(matriisi)
%
%   matriisi   array of any size and dimensionality
%   maksimi    the single largest element, that is max(matriisi(:))
%
% Called with no argument it returns empty rather than erroring, so it is safe
% in expressions that may be reached before the data exists.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    maksimi=[];
    if nargin<1
        return
    end
    maksimi=max(matriisi(:));

end % maxn
