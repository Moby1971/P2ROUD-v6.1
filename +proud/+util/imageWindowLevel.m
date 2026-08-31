function [window, level] = imageWindowLevel(im)

% Display window and level for a reconstructed image
%
%   [window, level] = proud.util.imageWindowLevel(im)
%
%   im       the reconstructed image to scale the display for
%   window   display width, twice the level
%   level    display centre, the mean of the foreground pixels
%
% The level is the mean of the pixels above Otsu's threshold -- that is, the
% mean of what the image considers foreground -- and the window is twice that.
% Taking the mean of the whole image instead would be pulled down by background,
% and a slice that is mostly background would come out far too dark.
%
% Both are clamped to the maximum value present, so the display never asks for
% more range than the data has. An image that is entirely background leaves
% mean(nonzeros(...)) empty or NaN, which is why the NaN case falls back to the
% maximum rather than propagating.
%
% This was inline in the app's SetImageWLFcn. It is here so it can be tested on
% the edge cases -- an all-zero image, a constant image, a single bright pixel --
% which is exactly where a display scaling goes wrong and nobody notices.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    im = double(im);

    maxScale = double(round(max(im(:))));

    if isempty(maxScale) || maxScale <= 0
        window = 0;
        level = 0;
        return
    end

    threshold = double(graythresh(mat2gray(im))) * maxScale;

    imt = im;
    imt(imt < threshold) = 0;

    level = mean(nonzeros(imt(:)));
    level(isempty(level)) = maxScale;
    level(level > maxScale) = maxScale;
    level(isnan(level)) = maxScale;

    window = 2 * level;
    window(window > maxScale) = maxScale;

end % imageWindowLevel
