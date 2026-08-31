function Xnew = lowRankThresh3D(Xold, kSize, thresh)

% Low-rank threshold of 3D k-space, over sliding-window patches
%
%   Xnew = lowRankThresh3D(Xold, kSize, thresh)
%
%   Xold     sx x sy x sz x nCoils k-space
%   kSize    [wx wy wz] sliding window used to form the patch matrix
%   thresh   number of singular values to keep; rounded to an integer
%   Xnew     same size as Xold, rebuilt from the truncated patch matrix
%
% The 3D counterpart of lowRankThresh2D, using im2row3D and row2im3D.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Round the threshold to the nearest integer value
    thresh = round(thresh);

    % Define indices of the singular values to keep
    keep = 1:thresh;

    % Get the size of the input data
    [sx, sy, sz, ~] = size(Xold);

    % Convert the input data into a 2D matrix
    tmp = im2row3D(Xold, kSize);
    [tsx, tsy, Nc] = size(tmp);
    A = reshape(im2row3D(Xold, kSize), tsx, tsy*Nc);

    % Perform singular value decomposition and keep only the top k singular values
    [U, S, V] = svd(A, 'econ');
    A = U(:, keep)*S(keep, keep)*V(:, keep)';

    % Reshape the data and convert it back to 3D
    A = reshape(A, tsx, tsy*Nc);
    Xnew = row2im3D(A, [sx, sy, sz, Nc], kSize);

end % lowRankThresh3D
