function res = im2row3D(im, winSize)

% Sliding-window patches of a 3D volume, one patch per row
%
%   res = im2row3D(im, winSize)
%
%   im        sx x sy x sz x nc volume; the fourth dimension is carried along
%             and normally holds coils
%   winSize   [wx wy wz] sliding window, stepped one voxel at a time
%   res       (sx-wx+1)*(sy-wy+1)*(sz-wz+1) x wx*wy*wz x nc. Each row is one
%             patch position, each column one offset within the window
%
% The 3D counterpart of im2row2D, and the matrix lowRankThresh3D takes its SVD
% of. row2im3D is the inverse.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Get the size of the input image
    [sx,sy,sz,nc] = size(im);

    % Allocate memory for the output matrix
    res = zeros((sx-winSize(1)+1)*(sy-winSize(2)+1)*(sz-winSize(3)+1),prod(winSize),nc);

    % Initialize counter
    count=0;

    % Slide a window over the image
    for z=1:winSize(3)
        for y=1:winSize(2)
            for x=1:winSize(1)
                % Increment counter
                count = count+1;
                % Extract and reshape each patch of the image and store it in a column of the output matrix
                res(:,count,:) = reshape(im(x:sx-winSize(1)+x,y:sy-winSize(2)+y,z:sz-winSize(3)+z),...
                    (sx-winSize(1)+1)*(sy-winSize(2)+1)*(sz-winSize(3)+1),nc);
            end
        end
    end

end % im2row3D
