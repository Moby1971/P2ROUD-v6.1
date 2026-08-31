function x = ifft3Dmri(X)

% Centred, norm-preserving 3D transform from k-space to image space
%
%   x = ifft3Dmri(X)
%
%   X   k-space with the origin at the centre, transformed along dimensions
%       1, 2 and 3; further dimensions are carried through untouched
%   x   image, same size as X
%
% The inverse of proud.util.fft3Dmri, kept private here because only +reco
% calls it. Identical in convention to proud.util.ifft2Dmri, one dimension more.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    x = fftshift(fft(fftshift(X,1),[],1),1)/sqrt(size(X,1));
    x = fftshift(fft(fftshift(x,2),[],2),2)/sqrt(size(X,2));
    x = fftshift(fft(fftshift(x,3),[],3),3)/sqrt(size(X,3));

end
