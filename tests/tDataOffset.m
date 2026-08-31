classdef (TestTags = {'Slow'}) tDataOffset < matlab.unittest.TestCase
    % Automatic data offset estimation
    %
    % Centre-out readouts start with a number of junk samples. The
    % reconstruction crops the data to 1+offset:end and pairs it with the
    % trajectory from its start, so a wrong offset misplaces every sample along
    % its spoke and the spokes stop agreeing about the same k-space location.
    %
    % estimateDataOffset finds the offset by minimising the data consistency
    % residual ||A*x - d||/||d||. Image sharpness does not work here: a
    % misaligned radial data set concentrates its energy at the origin, so a
    % peakiness measure scores the wrong offset highest and lands consistently
    % off by two.

    methods (Static)

        function [kSpace, traj] = uteData(N, nSpokes, nSamples, nJunk, seed)
            % A centre-out 3D UTE data set with nJunk junk samples prepended to
            % every readout, and the nominal trajectory that belongs to the real
            % samples -- which is exactly what the reconstruction is handed.
            rng(seed);

            k = (0:nSpokes-1)';
            z = 1 - 2*(k+0.5)/nSpokes;
            phi = k*pi*(3-sqrt(5));
            dirv = [sqrt(max(0,1-z.^2)).*cos(phi), ...
                    sqrt(max(0,1-z.^2)).*sin(phi), z]';
            r = (0:nSamples-1)*(N/2)/(nSamples-1);
            traj = zeros(3,nSamples,nSpokes);
            for s = 1:nSpokes
                traj(:,:,s) = dirv(:,s)*r;
            end

            [xx,yy,zz] = ndgrid((1:N)-N/2-0.5);
            im = double(sqrt(xx.^2+yy.^2+zz.^2) < N/3);
            im(abs(xx-4) < 3 & abs(yy) < 4 & abs(zz+3) < 3) = 0.5;

            p = proud.defaultRecoParams(); p.bartDetected = false; p.gpuPresent = false;
            d = proud.reco.fwdNUFT(p, proud.Reporter(), traj, reshape(im,[N N N]), [N N N]);
            d = reshape(d, [nSamples nSpokes]);

            junk = 0.02*max(abs(d(:)))*(randn(nJunk,nSpokes) + 1i*randn(nJunk,nSpokes));
            kSpace = [junk; d];
        end

        function p = params()
            p = proud.defaultRecoParams();
            p.bartDetected = false;
            p.gpuPresent = false;
        end

    end

    methods (Test, ParameterCombination = 'sequential')

        function findsTheOffsetThatWasPutIn(tc)
            % The candidate loop steps by two, so only even offsets are
            % representable and the answer should be exact
            for nJunk = [0 2 4 6 8 10]
                [kSpace, traj] = tDataOffset.uteData(32, 300, 48, nJunk, 21);
                est = proud.reco.estimateDataOffset(tDataOffset.params(), ...
                    proud.Reporter(), kSpace, traj, 16);
                tc.verifyEqual(est, nJunk, ...
                    sprintf('offset %d estimated as %d', nJunk, est));
            end
        end

        function noHeadroomYieldsZero(tc)
            % maxOffset below 2 leaves nothing to search
            [kSpace, traj] = tDataOffset.uteData(32, 100, 48, 0, 5);
            tc.verifyEqual(proud.reco.estimateDataOffset(tDataOffset.params(), ...
                proud.Reporter(), kSpace, traj, 1), 0);
            tc.verifyEqual(proud.reco.estimateDataOffset(tDataOffset.params(), ...
                proud.Reporter(), kSpace, traj, 0), 0);
        end

        function emptyDataYieldsZero(tc)
            % An all-zero data set has no residual to minimise; the estimator
            % must fall back rather than pick an arbitrary candidate
            [~, traj] = tDataOffset.uteData(32, 100, 48, 0, 5);
            kSpace = zeros(48, 100);
            tc.verifyEqual(proud.reco.estimateDataOffset(tDataOffset.params(), ...
                proud.Reporter(), kSpace, traj, 8), 0);
        end

        function degenerateTrajectoryYieldsZero(tc)
            [kSpace, traj] = tDataOffset.uteData(32, 100, 48, 4, 5);
            tc.verifyEqual(proud.reco.estimateDataOffset(tDataOffset.params(), ...
                proud.Reporter(), kSpace, 0*traj, 8), 0);
        end

    end

end
