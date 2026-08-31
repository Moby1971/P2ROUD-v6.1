function x = ifft2Dmri(X)

% Centred, norm-preserving 2D transform from k-space to image space
%
%   x = proud.util.ifft2Dmri(X)
%
%   X   k-space with the origin at the centre, transformed along dimensions
%       1 and 2; further dimensions are carried through untouched
%   x   image, same size as X
%
% The exact inverse of proud.util.fft2Dmri: fftshift-fft-fftshift per dimension,
% scaled by 1/sqrt(N).
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    x = fftshift(fft(fftshift(X,1),[],1),1)/sqrt(size(X,1));
    x = fftshift(fft(fftshift(x,2),[],2),2)/sqrt(size(X,2));

end
