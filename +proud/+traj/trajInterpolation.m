function kSpaceNew = trajInterpolation(kSpaceOld,dShift)

% Correct a k-space trajectory for gradient delays
%
%   kSpaceNew = proud.traj.trajInterpolation(kSpaceOld, dShift)
%
%   kSpaceOld   3 x samples x spokes x ... trajectory, in the gridder's units
%   dShift      [dx dy dz] or [dx dy dz sxy sxz syz], in samples
%   kSpaceNew   the corrected trajectory, same size as kSpaceOld
%
% dx, dy, dz are the delays of the x, y and z gradients. A delay of the x
% gradient shifts the kx component of the trajectory along the readout, and
% likewise for y and z.
%
% sxy, sxz, syz are the cross-terms of the gradient delay matrix S. These give
% a shift that depends on the direction of the spoke and are applied as a
% displacement of the trajectory:
%
%       [ dx  sxy sxz ]
%   S = [ sxy dy  syz ]      delta_k = - dRho * (S * n)
%       [ sxz syz dz  ]
%
% with n the unit readout direction of the spoke and dRho the k-space step per
% sample along that direction. Bart estdelay returns [Sxx, Syy, Sxy] with the
% opposite sign convention; proud.reco.estdelayToDelays does that conversion.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Delay vector, pad with zeros when only the diagonal is given
    dShift = double(dShift(:)');
    dShift(end+1:6) = 0;
    dShift = dShift(1:6);

    % Nothing to do
    if all(dShift == 0) || (size(kSpaceOld,2) < 2)
        kSpaceNew = kSpaceOld;
        return;
    end

    % Collapse all trailing dimensions, so that no dimension is ever lost
    dimsOld = size(kSpaceOld);
    nrSamples = dimsOld(2);
    kOld = reshape(kSpaceOld,3,nrSamples,[]);
    kNew = kOld;
    sampleIdx = 1:nrSamples;

    % Diagonal terms: shift each component along the readout.
    % Points that fall outside the readout are extrapolated along the
    % trajectory, they should never be moved to the k-space center.
    for crd = 1:3

        if dShift(crd) ~= 0
            tmp = reshape(kOld(crd,:,:),nrSamples,[]);
            tmp = interp1(sampleIdx+dShift(crd),tmp,sampleIdx,'linear','extrap');
            kNew(crd,:,:) = reshape(tmp,1,nrSamples,[]);
        end

    end

    % Cross-terms: displacement along the readout direction of each spoke
    if any(dShift(4:6) ~= 0)

        % Unit readout direction of each spoke
        readDir = kOld(:,end,:) - kOld(:,1,:);
        dirNorm = sqrt(sum(readDir.^2,1));
        dirNorm(dirNorm == 0) = 1;
        readDir = readDir./dirNorm;

        % K-space step per sample along the readout direction
        dRho = sum(diff(kOld,1,2).*readDir,1);
        dRho = cat(2,dRho(:,1,:),dRho);

        % Off-diagonal part of S * n
        nx = readDir(1,1,:);
        ny = readDir(2,1,:);
        nz = readDir(3,1,:);
        crossShift = cat(1, dShift(4)*ny + dShift(5)*nz, ...
                            dShift(4)*nx + dShift(6)*nz, ...
                            dShift(5)*nx + dShift(6)*ny);

        kNew = kNew - dRho.*crossShift;

    end

    % Restore the original shape
    kSpaceNew = reshape(kNew,dimsOld);

end % trajInterpolation
