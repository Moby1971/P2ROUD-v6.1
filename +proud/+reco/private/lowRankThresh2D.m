function Xnew = lowRankThresh2D(Xold,kSize,thresh)

% Low-rank threshold of 2D k-space, over sliding-window patches
%
%   Xnew = lowRankThresh2D(Xold, kSize, thresh)
%
%   Xold     sx x sy x nCoils k-space
%   kSize    [wx wy] sliding window used to form the patch matrix
%   thresh   number of singular values to keep; rounded to an integer
%   Xnew     same size as Xold, rebuilt from the truncated patch matrix
%
% The patches are stacked by im2row2D, the stack is truncated to its largest
% thresh singular values, and row2im2D averages the overlapping patches back
% into k-space. Correlated coils and smooth structure survive the truncation
% while incoherent noise and undersampling artefacts do not.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Round threshold to nearest integer
    thresh = round(thresh);

    % Define indices of the singular values to keep
    keep = 1:thresh;

    % Get size of input matrix
    [sx,sy,Nc] = size(Xold);

    % Convert the 3D matrix to a 2D matrix, where each row corresponds to a window
    tmp = im2row2D(Xold,kSize);

    % Get size of temporary matrix
    [tsx,tsy,tsz] = size(tmp);

    % Apply SVD to temporary matrix
    A = reshape(im2row2D(Xold,kSize),tsx,tsy*tsz);
    [U,S,V] = svd(A,'econ');

    % Perform low-rank approximation by keeping only the first 'thresh' singular values
    A = U(:,keep)*S(keep,keep)*V(:,keep)';

    % Reshape the data and convert it back to 2D
    A = reshape(A,tsx,tsy,tsz);
    Xnew = row2im2D(A,[sx,sy,Nc],kSize);

end % lowRankThresh2D
