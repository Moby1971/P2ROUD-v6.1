function [window, level] = kspaceWindowLevel(im, isSenseMap)

% Display window and level for k-space, or for a coil sensitivity map
%
%   [window, level] = proud.util.kspaceWindowLevel(im, isSenseMap)
%
%   im            the k-space or sensitivity map to scale the display for
%   isSenseMap    true when im is a coil sensitivity map rather than k-space
%   window        display width
%   level         display centre
%
% Three cases, and the reason they differ is what the data means:
%
%   all zero      nothing to scale to, so use the full k-space range
%   sensitivity   values are relative, around 1, so scale by MAX_KSPACE
%   k-space       values are absolute, so scale by the maximum present
%
% The 0.8 and 0.4 on the k-space branch keep the bright centre from saturating
% the display of the much fainter outer k-space, which is what one is usually
% looking at.
%
% This was inline in the app's SetKspaceWLFcn.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    if nargin < 2
        isSenseMap = false;
    end

    im = double(im);
    maxim = max(im(:));

    if isempty(maxim) || maxim == 0

        window = proud.Constants.MAX_KSPACE;
        level = 0.5 * proud.Constants.MAX_KSPACE;

    elseif isSenseMap

        window = double(round(1 * proud.Constants.MAX_KSPACE * maxim));
        level = double(round(0.75 * proud.Constants.MAX_KSPACE * maxim));

    else

        window = double(round(0.8 * maxim));
        level = double(round(0.4 * window));

    end

end % kspaceWindowLevel
