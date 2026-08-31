function X = fft2Dmri(x)

% Centred, norm-preserving 2D transform from image space to k-space
%
%   X = proud.util.fft2Dmri(x)
%
%   x   image, transformed along dimensions 1 and 2; further dimensions such
%       as coils or dynamics are carried through untouched
%   X   k-space, same size as x, with the origin at the centre
%
% The transform is fftshift-ifft-fftshift per dimension, scaled by sqrt(N), so
% the zero frequency sits in the middle of the matrix rather than at index 1
% and the total energy is preserved. Note that the MRI convention followed here
% names the image-to-k-space direction "fft" while the underlying call is ifft;
% proud.util.ifft2Dmri is the exact inverse.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    X = fftshift(ifft(fftshift(x,1),[],1),1)*sqrt(size(x,1));
    X = fftshift(ifft(fftshift(X,2),[],2),2)*sqrt(size(x,2));

end % FFT 2D
