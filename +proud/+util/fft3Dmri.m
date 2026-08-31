function X = fft3Dmri(x)

% Centred, norm-preserving 3D transform from image space to k-space
%
%   X = proud.util.fft3Dmri(x)
%
%   x   image, transformed along dimensions 1, 2 and 3; further dimensions
%       such as coils or dynamics are carried through untouched
%   X   k-space, same size as x, with the origin at the centre
%
% The 3D counterpart of proud.util.fft2Dmri, and the same convention: the
% image-to-k-space direction is called "fft" but is built from ifft.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    X = fftshift(ifft(fftshift(x,1),[],1),1)*sqrt(size(x,1));
    X = fftshift(ifft(fftshift(X,2),[],2),2)*sqrt(size(x,2));
    X = fftshift(ifft(fftshift(X,3),[],3),3)*sqrt(size(x,3));

end % FFT 3D
