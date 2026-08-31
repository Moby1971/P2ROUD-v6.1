function output = circTukey3D(dimZ,dimY,dimX,lev,row,col,filterwidth)

% Spherically symmetric 3D Tukey filter, centred anywhere in the volume
%
%   output = proud.util.circTukey3D(dimZ, dimY, dimX, lev, row, col, filterwidth)
%
%   dimZ, dimY, dimX   size of the filter to return
%   lev, row, col      centre of the filter, in voxels of that grid
%   filterwidth        tukeywin taper ratio: 0 is a box, 1 a Hann window
%   output             dimZ x dimY x dimX filter, 1 at the centre falling to 0
%
% The 3D counterpart of circTukey2D: a 1D Tukey taper indexed by radius, built
% on a fixed 256^3 grid and resized at the end.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    domain = 256;

    base = zeros(domain,domain,domain);

    tukey1 = tukeywin(domain,filterwidth);
    tukey1 = tukey1(domain/2+1:domain);

    shiftZ = (lev-dimZ/2)*domain/dimZ;
    shiftY = (row-dimY/2)*domain/dimY;
    shiftX = (col-dimX/2)*domain/dimX;

    z = linspace(-domain/2, domain/2, domain);
    y = linspace(-domain/2, domain/2, domain);
    x = linspace(-domain/2, domain/2, domain);

    for i = 1:domain

        for j = 1:domain

            for k = 1:domain

                rad = round(sqrt((shiftX-x(i))^2 + (shiftY-y(j))^2 + (shiftZ-z(k))^2));

                if (rad <= domain/2) && (rad > 0)

                    base(k,j,i) = tukey1(rad);

                end

            end

        end

    end

    output = imresize3(base,[dimZ dimY dimX]);

end
