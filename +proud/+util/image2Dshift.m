function imOut = image2Dshift(imIn, xShift, yShift)

% Shift an image by a fractional number of pixels
%
%   imOut = proud.util.image2Dshift(imIn, xShift, yShift)
%
%   imIn     image to shift
%   xShift   shift along dimension 2, in pixels; may be fractional
%   yShift   shift along dimension 1, in pixels; may be fractional
%   imOut    shifted image, same size as imIn, complex
%
% The shift is applied as a linear phase ramp in k-space, which is exact for a
% band-limited image and so does not need an interpolation kernel. The result
% is complex even when the input is real, because the ramp is only exactly
% Hermitian for a whole-pixel shift; take abs() if a magnitude image is wanted.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Transform image to k-space
    H = proud.util.ifft2Dmri(imIn);

    % Create linear grid
    [xF,yF] = meshgrid(-size(imIn,2)/2:size(imIn,2)/2-1,-size(imIn,1)/2:size(imIn,1)/2-1);

    % Perform the shift in k-space
    H = H.*exp(-1i*2*pi.*(xF*xShift/size(imIn,2)+yF*yShift/size(imIn,1)));

    % Transform image back from k-space
    % Note: this is a complex image now
    imOut = proud.util.fft2Dmri(H);

end % image2Dshift
