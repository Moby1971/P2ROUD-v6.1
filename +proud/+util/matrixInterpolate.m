function outputMatrix = matrixInterpolate(inputMatrix, scaling, varargin)

% Resize an n-dimensional matrix by interpolation
%
%   outputMatrix = proud.util.matrixInterpolate(inputMatrix, scaling)
%   outputMatrix = proud.util.matrixInterpolate(inputMatrix, scaling, method)
%
%   inputMatrix    array of any dimensionality
%   scaling        size multiplier, one per dimension; a scalar applies to all.
%                  Each output dimension becomes round(size*scaling)
%   method         griddedInterpolant method, for example 'linear' or 'cubic';
%                  omitted takes the griddedInterpolant default
%   outputMatrix   the resized array
%
% Singleton dimensions are left at length 1 rather than scaled, so a vector
% stays a vector. The sample positions are cell centres on a -0.5 to 0.5 axis,
% so the field of view is unchanged by the resize and no half-pixel shift is
% introduced.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    N = ndims(inputMatrix);
    scaling = scaling(1:N);
    scaling(1,1:N) = scaling(:).';
    sz = size(inputMatrix);
    xvec = cell(1,N);
    yvec = cell(1,N);
    szy = nan(1,N);
    nonsing = true(1,N);

    for i = 1:N

        n = sz(i);

        if n==1 %for vector input
            nonsing(i) = 0;
            szy(i) = 1;
            continue
        end

        szy(i) = round(sz(i)*scaling(i));
        m = szy(i);

        xax = linspace(1/n/2, 1-1/n/2 ,n);
        xax = xax-.5;

        yax = linspace(1/m/2, 1-1/m/2 ,m);
        yax = yax-.5;

        xvec{i} = xax;
        yvec{i} = yax;

    end

    xvec = xvec(nonsing);
    yvec = yvec(nonsing);
    F = griddedInterpolant(xvec,squeeze(inputMatrix),varargin{:});
    outputMatrix = reshape(F(yvec),szy);

end % matrixInterpolate
