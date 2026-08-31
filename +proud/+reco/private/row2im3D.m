function [res,W] = row2im3D(mtx, imSize, winSize)

% Reassemble a 3D volume from sliding-window patches
%
%   [res, W] = row2im3D(mtx, imSize, winSize)
%
%   mtx       patch matrix as im2row3D returns it, with coils in dimension 4
%   imSize    [sx sy sz], the volume to rebuild
%   winSize   [wx wy wz], the window that produced mtx
%   res       sx x sy x sz x nCoils volume, each voxel the mean of every patch
%             that covered it
%   W         the same size, counting how many patches covered each voxel
%
% The inverse of im2row3D. Overlapping patches disagree once they have been
% altered, so contributions are summed and divided by W rather than written
% back. The 3D counterpart of row2im2D.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    nCoils = size(mtx,4);
    sx = imSize(1);
    sy = imSize(2);
    sz = imSize(3);
    res = zeros(imSize(1),imSize(2),imSize(3),nCoils);
    W = res;

    count=0;
    for z=1:winSize(3)
        for y=1:winSize(2)
            for x=1:winSize(1)
                count = count+1;
                res(x:sx-winSize(1)+x,y:sy-winSize(2)+y,z:sz-winSize(3)+z,:) = res(x:sx-winSize(1)+x,y:sy-winSize(2)+y,z:sz-winSize(3)+z,:) + reshape(mtx(:,count,:,:),(sx-winSize(1)+1),(sy-winSize(2)+1),(sz-winSize(3)+1),nCoils);
                W(x:sx-winSize(1)+x,y:sy-winSize(2)+y,z:sz-winSize(3)+z,:) = W(x:sx-winSize(1)+x,y:sy-winSize(2)+y,z:sz-winSize(3)+z,:)+1;
            end
        end
    end

    res = res./W;

end % row2im3D
