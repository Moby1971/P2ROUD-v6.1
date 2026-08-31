function output = circTukey2D(dimY,dimX,row,col,filterwidth)

% Radially symmetric 2D Tukey filter, centred anywhere in the matrix
%
%   output = proud.util.circTukey2D(dimY, dimX, row, col, filterwidth)
%
%   dimY, dimX    size of the filter to return
%   row, col      centre of the filter, in pixels of the dimY x dimX grid
%   filterwidth   tukeywin taper ratio: 0 is a box, 1 a Hann window
%   output        dimY x dimX filter, 1 at the centre falling to 0 at radius
%
% The filter is a 1D Tukey taper indexed by radius, so it is circular whatever
% the aspect ratio of the matrix. It is built on a fixed 256 x 256 grid and
% resized at the end, which keeps the cost the same for any matrix size.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    domain = 256;
    base = zeros(domain,domain);

    tukey1 = tukeywin(domain,filterwidth);
    tukey1 = tukey1(domain/2+1:domain);

    shiftY = (row-dimY/2)*domain/dimY;
    shiftX = (col-dimX/2)*domain/dimX;

    y = linspace(-domain/2, domain/2, domain);
    x = linspace(-domain/2, domain/2, domain);

    for i = 1:domain

        for j = 1:domain

            rad = round(sqrt((shiftX-x(i))^2 + (shiftY-y(j))^2));

            if (rad <= domain/2) && (rad > 0)

                base(j,i) = tukey1(rad);

            end

        end

    end

    output = imresize(base,[dimY dimX]);

end
