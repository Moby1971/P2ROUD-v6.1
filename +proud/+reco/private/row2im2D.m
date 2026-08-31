function [res,W] = row2im2D(mtx,imSize, winSize)

% Reassemble a 2D image from sliding-window patches
%
%   [res, W] = row2im2D(mtx, imSize, winSize)
%
%   mtx       (sx-wx+1)*(sy-wy+1) x wx*wy x channels, as im2row2D returns
%   imSize    [sx sy], the size of the image to rebuild
%   winSize   [wx wy], the window that produced mtx
%   res       sx x sy x channels image, each pixel the mean of every patch
%             that covered it
%   W         sx x sy x channels count of how many patches covered each pixel
%
% The inverse of im2row2D. Overlapping patches disagree once they have been
% altered, for instance by the low-rank threshold, so the contributions are
% summed and divided by W rather than simply written back. W is returned
% because the caller sometimes needs the weighting itself.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    sx = imSize(1);
    sy = imSize(2);
    sz = size(mtx,3);

    % Initialize res and W as 3D matrices of zeros
    res = zeros(imSize(1),imSize(2),sz);
    W = res;

    count=0;
    for y=1:winSize(2)
        for x=1:winSize(1)
            count = count+1;
            % Update res with the current window and mtx count
            res(x:sx-winSize(1)+x,y:sy-winSize(2)+y,:) = res(x:sx-winSize(1)+x,y:sy-winSize(2)+y,:) + reshape(mtx(:,count,:),(sx-winSize(1)+1),(sy-winSize(2)+1),sz);
            % Update W with the weight of the current window
            W(x:sx-winSize(1)+x,y:sy-winSize(2)+y,:) = W(x:sx-winSize(1)+x,y:sy-winSize(2)+y,:)+1;
        end
    end

    % Divide res by W to get the final image
    res = res./W;

end % row2im
