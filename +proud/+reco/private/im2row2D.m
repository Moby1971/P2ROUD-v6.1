function res = im2row2D(im, winSize)

% Sliding-window patches of a 2D image, one patch per row
%
%   res = im2row2D(im, winSize)
%
%   im        sx x sy x sz image; the third dimension is carried along, so it
%             can hold coils or channels
%   winSize   [wx wy] sliding window, stepped one pixel at a time
%   res       (sx-wx+1)*(sy-wy+1) x wx*wy x sz. Each row is one patch position
%             and each column one offset within the window
%
% This is the matrix the low-rank step takes its SVD of: patch positions down
% the rows, so structure shared between overlapping patches shows up as a small
% number of large singular values. row2im2D is the inverse.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Get the dimensions of the input image
    [sx,sy,sz] = size(im);

    % Compute the size of the output matrix
    res = zeros((sx-winSize(1)+1)*(sy-winSize(2)+1),prod(winSize),sz);

    % Counter variable to keep track of the column in the output matrix
    count=0;

    % Loop over the rows and columns of the sliding window
    for y=1:winSize(2)
        for x=1:winSize(1)
            count = count+1;
            % Extract the patches from the input image and reshape them
            % into columns of the output matrix
            res(:,count,:) = reshape(im(x:sx-winSize(1)+x,y:sy-winSize(2)+y,:),...
                (sx-winSize(1)+1)*(sy-winSize(2)+1),1,sz);
        end
    end

end % im2row2D
