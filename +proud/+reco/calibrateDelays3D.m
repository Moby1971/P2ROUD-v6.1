function dTotal = calibrateDelays3D(obj, params, kSpacePics, trajPics, dTotal, calibSize)

% Gradient delay calibration for 3D UTE data
%
%   dTotal = proud.reco.calibrateDelays3D(obj, params, kSpacePics, trajPics, ...
%       dTotal, calibSize)
%
%   obj          proudData, for reporting and the abort check
%   params       reconstruction parameters, including which method to use
%   kSpacePics   k-space in Bart's dimension order
%   trajPics     the matching trajectory
%   dTotal       starting delays [Gx Gy Gz Sxy Sxz Syz], in samples
%   calibSize    matrix size the calibration reconstructs at
%   dTotal       the calibrated delays, in the same six-element form
%
% Iterative low-rank estimation of the three gradient delays. Called by
% the CS and by the NUFFT reconstruction, so that the calibration does not
% depend on which reconstruction is selected. Runs with or without Bart,
% see fwdNUFT/invNUFT. Bart's estdelay is not usable here: it is a 2D
% radial method, see the notes on RING.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    % Gradient delay calibration
    if params.gradDelayCalibration

        % Delays as entered by the user, to fall back on
        dInit = dTotal;

        try

            % Find the k-space for which signal is maximal, for best coil sensitivity estimation
            ks = abs(kSpacePics);
            [~,indx] = max(ks(:));
            [~,~,~,cIdx,~,teIdx,faIdx,~,~,~,~,dynIdx,~,~] = ind2sub(size(ks),indx);
            kSpacePicsRing = kSpacePics(1,:,:,cIdx,1,teIdx,faIdx,1,1,1,1,dynIdx,1,1);
            trajPicsRing = trajPics;

            % Calibration size
            kSize = [6,6,6];
            kSkip = round(size(kSpacePicsRing,3)/2000);
            kSkip(kSkip < 1) = 1;

            % M = index in trajectory for which k-space value >= calibSize
            % Use the spoke with the largest k-space extent as reference
            spokeExtent = squeeze(sum(trajPicsRing(1,:,:).^2 + trajPicsRing(2,:,:).^2 + trajPicsRing(3,:,:).^2,2));
            [~,zm] = max(spokeExtent(:));
            M = find(sqrt(trajPicsRing(1,:,zm).^2+trajPicsRing(2,:,zm).^2+trajPicsRing(3,:,zm).^2) >= calibSize(1,1)/2,1);

            % Reduce size for gradient calibration
            kTrajCalib = trajPicsRing(:,1:M,1:kSkip:end);
            dataCalib = kSpacePicsRing(1,1:M,1:kSkip:end);
            ze = squeeze(abs(dataCalib(1,1,:))) > 0;
            kTrajCalib = kTrajCalib(:,:,ze);
            obj.reporter.message(strcat("Calibration spokes = ",num2str(size(kTrajCalib,3))," ..."));

            % The delays are estimated with respect to the nominal trajectory, so
            % that the values remain absolute and a second calibration
            % run on the same data gives the same answer
            kTraj = proud.traj.trajInterpolation(kTrajCalib,dTotal);

            % Initial image
            dataCalib = dataCalib(:,:,ze);
            imCalib = invNUFT(params,obj.reporter,kTraj,dataCalib,calibSize,0.01);

            % Initialization
            iteration = 0;
            incre = 10;
            kCalib = proud.util.fft3Dmri(imCalib);
            wnRank = params.llrRankWeight3D;
            rank = floor(wnRank*prod(kSize));
            obj.reporter.message(strcat("Rank = ",num2str(rank)," ..."));

            % Data consistency
            y = squeeze(dataCalib);
            xOld = kCalib;

            % Prepare for manual stop
            obj.reporter.setAborted('gradcal', false);

            % Calibration
            while  (iteration<20)  && (incre>0.01) && ~obj.reporter.aborted('gradcal')

                % Iteration number
                iteration = iteration + 1;
                obj.reporter.message(strcat("Iteration = ",num2str(iteration)," ..."));

                % Solve for X
                xNew = lowRankThresh3D(xOld,kSize,rank);
                rank = rank+1;
                rank(rank>prod(kSize)) = prod(kSize);

                % NUFFT to get updated k-space data
                kNew = ifft3Dmri(xNew);
                dataCalib = proud.reco.fwdNUFT(params,obj.reporter,kTraj,kNew,calibSize);
                % The calibration uses a single coil
                kNew  = reshape(dataCalib,[M size(kTrajCalib,3) 1]);

                % Partial derivatives
                [dydtx,dydty,dydtz] = partialDerivative3D(params,obj.reporter,kTraj,xNew,calibSize);

                % Direct solver
                dydt = [real(vec(dydtx)) real(vec(dydty)) real(vec(dydtz)) ; imag(vec(dydtx)) imag(vec(dydty)) imag(vec(dydtz))];
                % How well the spokes determine each of the three delays. A
                % delay that the spoke distribution barely constrains shows up
                % as a small column norm and a large condition number, and the
                % solver will happily put a large value into it. Worth knowing
                % before trusting the number, in particular for z: a center-out
                % trajectory shares one ramp between all three components, so
                % the common-mode part of the three delays is close to
                % degenerate with a shift of the readout itself.
                if iteration == 1
                    colNorm = sqrt(sum(dydt.^2,1));
                    obj.reporter.message(strcat("Delay fit, Jacobian column norms x:y:z = ", ...
                        num2str(colNorm(1),'%.3g')," : ",num2str(colNorm(2),'%.3g'), ...
                        " : ",num2str(colNorm(3),'%.3g')," ..."));
                    obj.reporter.message(strcat("Delay fit, condition number = ", ...
                        num2str(cond(dydt'*dydt),'%.3g')," ..."));
                end

                dStep = (dydt'*dydt)\(dydt' * [real(vec(kNew - y)) ; imag(vec(kNew - y))]);
                dStep(isnan(dStep)) = 0;

                % Gauss-Newton on ||f(d) - y||^2 with residual f(d) - y, so the
                % delays move against the step. No damping: the derivative is
                % correctly scaled, so a full step converges.
                dTotal(1:3) = dTotal(1:3) - real(dStep(1:3))';
                dTotal(dTotal > params.maxGradDelay) = params.maxGradDelay;
                dTotal(dTotal < -params.maxGradDelay) = -params.maxGradDelay;

                % Conversion criterium
                incre = norm(real(dStep));

                % Message
                obj.reporter.message(strcat("Estimated delays: ",num2str(dTotal(1)),":",num2str(dTotal(2)),":",num2str(dTotal(3))));

                % Sent gradient delay vector back to the caller

                % Interpolation to update trajectory with new delays
                kTraj = proud.traj.trajInterpolation(kTrajCalib,dTotal);

                % The new image with k-space updated for gradient delays
                imCalib = invNUFT(params,obj.reporter,kTraj,reshape(y,[1 M size(kTrajCalib,3) 1]),calibSize,0.01);

                % Show image
                im = squeeze(abs(imCalib(:,:,round(calibSize(3)/2),1)));
                im = flip(im,3);
                if obj.phaseOrientation
                    im = rot90(im,-1);
                else
                    im = flip(im,1);
                end
                obj.reporter.showImage(rot90(im));

                % Recompute k-space from the updated image, closing the loop for
                % the next iteration.
                %
                % This feedback drives the convergence: the image has to sharpen
                % as the delays improve, and low-rank thresholding alone will not
                % do that. Without it the estimator stalls near the starting
                % point -- on a known [0.90 -0.60 1.40] it reaches
                % [0.899 -0.579 1.393] with the feedback and [0.378 -0.034 0.053]
                % without.
                xOld = proud.util.fft3Dmri(squeeze(imCalib));

            end

        catch ME

            % A failed calibration should not abort the reconstruction
            obj.reporter.message(ME.message,2);
            obj.reporter.message('Gradient delay estimation failed ...',1);
            obj.reporter.status(1);
            dTotal = dInit;

        end


        % Report on progress
        obj.reporter.advance();
        obj.reporter.showProgress();
        drawnow;

    end % Gradient calibration

end % calibrateDelays3D
