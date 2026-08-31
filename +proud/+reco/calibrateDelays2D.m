function dTotal = calibrateDelays2D(obj, params, kSpacePics, trajPics, dTotal, calibSizeDelay, dimD, dimZ)

% Gradient delay calibration for 2D radial data
%
%   dTotal = proud.reco.calibrateDelays2D(obj, params, kSpacePics, trajPics, ...
%       dTotal, calibSizeDelay, dimD, dimZ)
%
%   obj              proudData, for reporting and the abort check
%   params           reconstruction parameters, including which method to use
%   kSpacePics       k-space in Bart's dimension order
%   trajPics         the matching trajectory
%   dTotal           starting delays [Gx Gy Gz Sxy Sxz Syz], in samples
%   calibSizeDelay   matrix size the calibration reconstructs at
%   dimD, dimZ       dynamics and slices, so one representative can be picked
%   dTotal           the calibrated delays, in the same six-element form
%
% Estimates the gradient delays from the data itself, either with Bart's
% estdelay or with the iterative low-rank method. Called by the CS and by
% the NUFFT reconstruction, so that the calibration does not depend on
% which reconstruction is selected. The iterative method runs with or
% without Bart, see fwdNUFT/invNUFT.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Gradient delay calibration
    if params.gradDelayCalibration

        % Delays as entered by the user, to fall back on
        dInit = dTotal;

        % Local copy of the ring-method flag. The iterative method takes
        % over when Bart's estimation fails, so this has to be mutable
        useRing = params.ringMethod;

        % Middle dynamic and middle slice, clamped to what the arrays actually
        % have: the NUFFT path passes a trajectory that is singleton in those
        % dimensions because every dynamic and slice shares the same spokes
        dynIdx = min(floor(dimD/2)+1,size(kSpacePics,12));
        sliceIdx = min(floor(dimZ/2)+1,size(kSpacePics,14));
        kSpacePicsRing = kSpacePics(1,:,:,:,1,1,1,1,1,1,1,dynIdx,1,sliceIdx);
        trajPicsRing = trajPics(:,:,:,1,1,1,1,1,1,1,1,min(dynIdx,size(trajPics,12)),1,min(sliceIdx,size(trajPics,14)));

        % Ring method
        if useRing

            % Gradient delay estimation with estdelay in Bart
            try

                td = trajPicsRing;
                tk = kSpacePicsRing;

                % The default estimator (Block & Uecker, ISMRM 19:2816) is used,
                % not the RING variant (-R, Rosenzweig et al., MRM 81:1898-1906).
                % RING is unreliable on the 0-180 degree trajectories used here:
                % it clips at the +/-0.75 sample capture range of its default
                % central region, and a larger -r makes it worse, not better.
                %
                % Bart returns the quadratic form of the gradient delays in
                % units of samples, qf = [Sxx, Syy, Sxy]. There is no z
                % component, estdelay is a 2D radial method.
                qf = real(bart(obj.reporter,'estdelay ',td,tk));

                dTotal = proud.reco.estdelayToDelays(qf);

                obj.reporter.message(strcat("Bart gradient delays Gx : Gy : Sxy = ", ...
                    num2str(dTotal(1),'%.3f')," : ",num2str(dTotal(2),'%.3f'), ...
                    " : ",num2str(dTotal(4),'%.3f')," samples ..."));

            catch ME

                obj.reporter.message(ME.message,2);
                obj.reporter.message('Bart gradient delay estimation failed ...');
                obj.reporter.message('Trying iterative method ...');
                obj.reporter.status(1);
                useRing = false;
                dTotal = dInit;

            end

            % Sent gradient delay vector back to the caller

        end % Ring method

        % Iterative method
        if ~useRing

            try

                % Calibration size
                kSize = [6,6];
                kSkip = round(size(kSpacePicsRing,3)/2000);
                kSkip(kSkip < 1) = 1;

                % M1:M2 = indices in trajectory for which k-space value <= calibSizeDelay
                % Use the spoke with the largest k-space extent as reference
                spokeExtent = squeeze(sum(trajPicsRing(1,:,:).^2 + trajPicsRing(2,:,:).^2,2));
                [~,zm] = max(spokeExtent(:));
                M = find(sqrt(trajPicsRing(1,:,zm).^2+trajPicsRing(2,:,zm).^2) <= calibSizeDelay(1)/2);
                M1 = M(1);
                M2 = M(end);

                % Reduce size for gradient calibration
                kTrajCalib = trajPicsRing(:,M1:M2,1:kSkip:end);
                dataCalib = kSpacePicsRing(1,M1:M2,1:kSkip:end);
                obj.reporter.message(strcat("Calibration spokes = ",num2str(size(kTrajCalib,3))," ..."));

                % Start from zero. The iterative method estimates the two
                % in-plane delays only, the cross-terms stay zero.
                dTotal = zeros(1,6);
                kTraj = kTrajCalib;

                % Initial image
                imCalib = invNUFT(params,obj.reporter,kTrajCalib,dataCalib,calibSizeDelay,0.01);

                % Initialization
                iteration = 0;
                incre = 10;
                kCalib = proud.util.fft2Dmri(imCalib);
                wnRank = params.llrRankWeight2D;
                rank = floor(wnRank*prod(kSize));
                obj.reporter.message(strcat("Rank = ",num2str(rank)," ..."));

                % Data consistency
                spoke = squeeze(dataCalib);
                xOld = kCalib;

                % Prepare for manual stop
                obj.reporter.setAborted('gradcal', false);

                % Iterative method with Bart
                while  (iteration<100) && (incre>0.001) && ~obj.reporter.aborted('gradcal')

                    % Iteration number
                    iteration = iteration + 1;
                    obj.reporter.message(strcat("Iteration = ",num2str(iteration)," ..."));

                    % Solve for X
                    rank(rank>prod(kSize)) = prod(kSize);
                    xNew = lowRankThresh2D(xOld,kSize,rank);
                    rank = rank+1;
             
                    % NUFFT to get updated k-space data
                    kNew = proud.util.ifft2Dmri(xNew);
                    dataCalib = proud.reco.fwdNUFT(params,obj.reporter,kTraj,kNew,calibSizeDelay);
                    kNew  = reshape(dataCalib,[M2-M1+1 size(kTrajCalib,3) 1]);

                    % Partial derivatives
                    [dydtx,dydty] = partialDerivative2D(params,obj.reporter,kTraj,xNew,calibSizeDelay);

                    % Direct solver
                    dydt = [real(vec(dydtx)) real(vec(dydty)) ; imag(vec(dydtx)) imag(vec(dydty))];
                    dStep = (dydt'*dydt)\(dydt' * [real(vec(kNew - spoke)) ; imag(vec(kNew - spoke))]);
                    dStep(isnan(dStep)) = 0;

                    % Gauss-Newton on ||f(d) - y||^2 with residual f(d) - y,
                    % so the delays move against the step
                    dTotal(1) = dTotal(1) - real(dStep(1));
                    dTotal(2) = dTotal(2) - real(dStep(2));
                    dTotal(dTotal > params.maxGradDelay) = params.maxGradDelay;
                    dTotal(dTotal < -params.maxGradDelay) = -params.maxGradDelay;

                    % Conversion criterium
                    incre = norm(real(dStep));

                    % Message
                    obj.reporter.message(strcat("Estimated delays ",num2str(dTotal(1))," : ",num2str(dTotal(2))));

                    % Sent gradient delay vector back to the caller
                    drawnow;

                    % Interpolation to update trajectory with new delays
                    kTraj = proud.traj.trajInterpolation(kTrajCalib,dTotal);

                    % The new image with k-space updated for gradient delays
                    imCalib = invNUFT(params,obj.reporter,kTraj,reshape(spoke,[1 M2-M1+1 size(kTrajCalib,3) 1]),calibSizeDelay,0.01);

                    % Show image
                    im = squeeze(abs(imCalib(:,:)));
                    if obj.phaseOrientation
                        im = rot90(im,-1);
                    end
                    obj.reporter.showImage(rot90(im));

                    % Calculate k-space from new image
                    xOld = proud.util.fft2Dmri(squeeze(imCalib));

                end

            catch ME

                obj.reporter.message(ME.message,2);
                obj.reporter.message('Gradient delay estimation failed ...',1);
                obj.reporter.status(1);
                dTotal = dInit;

            end

        end

        % Reset calibration button
        obj.reporter.setAborted('gradcal', true);

    end % Gradient calibration

end % calibrateDelays2D
