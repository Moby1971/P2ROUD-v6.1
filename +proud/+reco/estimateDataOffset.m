function offset = estimateDataOffset(params, reporter, kSpace, traj, maxOffset)

% Number of junk samples at the start of a centre-out readout
%
%   offset = proud.reco.estimateDataOffset(params, reporter, kSpace, traj, maxOffset)
%
%   params      reconstruction parameters, for the NUFFT backend
%   reporter    proud.Reporter; omit or pass empty to run silent
%   kSpace      the acquired data, spokes along the readout
%   traj        the matching trajectory
%   maxOffset   largest offset to try; every value from 0 up to it is scored
%   offset      the offset with the lowest data consistency residual
%
% Every candidate from 0 to maxOffset is tried and the best kept.
%
% The reconstruction crops the data to 1+offset:end and pairs it with the
% trajectory from its start, so a wrong offset misplaces every sample
% along its spoke: spokes then disagree about the same k-space location
% and no image can fit them all. The measure is therefore the data
% consistency residual,
%
%     R = || A*x - d || / || d ||     with x the reconstruction of d,
%
% which is minimal at the right offset. Image sharpness was tried first
% and is not usable here: a misaligned radial data set concentrates its
% energy at the origin, so peakiness measures reward the wrong answer.
%
% All candidates use the same number of samples and the same trajectory
% scaling, so the comparison is like for like; a small matrix and a
% subset of the spokes keep it affordable.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    dimT = size(kSpace,1);
    dimS = size(kSpace,2);

    offset = 0;
    maxOffset = min(maxOffset,dimT-8);
    if maxOffset < 2
        return;
    end

    calibDim = 32;
    calibDim(calibDim > dimT) = dimT;
    nSamples = min(calibDim,dimT-maxOffset);
    kSkip = max(1,round(dimS/500));

    % One trajectory scaling for every candidate
    t = traj(:,1:nSamples,1:kSkip:end);
    tMax = proud.util.maxn(abs(t(:)));
    if tMax == 0
        return;
    end
    t = t*(calibDim/2)/tMax;

    best = Inf;

    for cand = 0:2:maxOffset

        d = reshape(kSpace(1+cand:cand+nSamples,1:kSkip:end,1,1,1,1,1),[1 nSamples size(t,3)]);

        if ~any(d(:))
            continue;
        end

        im = invNUFT(params,reporter,t,d,[calibDim calibDim calibDim],0.01);
        fit = proud.reco.fwdNUFT(params,reporter,t,reshape(im,[calibDim calibDim calibDim 1]), ...
            [calibDim calibDim calibDim]);

        residual = norm(fit(:)-d(:))/norm(d(:));

        if residual < best
            best = residual;
            offset = cand;
        end

    end

end % estimateDataOffset
