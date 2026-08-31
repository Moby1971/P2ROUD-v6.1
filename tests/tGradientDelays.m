classdef (TestTags = {'Slow'}) tGradientDelays < matlab.unittest.TestCase
    % End-to-end gradient delay recovery on synthetic data
    %
    % The experiment is the physical one. A phantom is sampled along a
    % trajectory that carries a KNOWN delay, and the calibrator is then handed
    % the data together with the NOMINAL, undelayed trajectory. What it
    % estimates has to be the delay that was put in, in the same sign
    % convention the reconstruction later applies with trajInterpolation.
    %
    % Between them these cover the Jacobian, the sign of the Gauss-Newton step
    % and the bound on Gz -- the three ways this estimator can be wrong while
    % still converging to something. They run without Bart and without a GUI,
    % and are tagged Slow because each runs a full iterative calibration.

    properties (Constant)
        Tol2D = 0.05    % samples; the 2D estimator is exact to ~1e-3 here
        Tol3D = 0.15    % samples; 3D on a small matrix is noisier
    end

    methods (Static)

        function p = params()
            p = proud.defaultRecoParams();
            p.bartDetected = false;          % force the MATLAB NUFFT, so the
            p.gpuPresent = false;            % test is reproducible everywhere
            p.gradDelayCalibration = true;
            p.ringMethod = false;            % the iterative method
        end

        function traj = radial2D(N, nSpokes, nSamples)
            % Golden angle full spokes through the origin
            ga = pi*(3-sqrt(5));
            r = ((0:nSamples-1) - floor(nSamples/2))*(N/2)/floor(nSamples/2);
            traj = zeros(3,nSamples,nSpokes);
            for s = 1:nSpokes
                th = (s-1)*ga;
                traj(1,:,s) = r*cos(th);
                traj(2,:,s) = r*sin(th);
            end
        end

        function traj = radial3D(N, nSpokes, nSamples)
            % Centre-out half spokes on a spiral over the sphere, UTE style
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
        end

        function im = phantom2D(N, seed)
            rng(seed);
            [xx,yy] = meshgrid((1:N)-N/2-0.5);
            im = double(sqrt(xx.^2+yy.^2) < N/3);
            im(abs(xx-4) < 3 & abs(yy+2) < 5) = 0.4;
            im = im + 0.05*randn(N);
        end

        function im = phantom3D(N, seed)
            rng(seed);
            [xx,yy,zz] = ndgrid((1:N)-N/2-0.5);
            im = double(sqrt(xx.^2+yy.^2+zz.^2) < N/3);
            im(abs(xx-3) < 2 & abs(yy+2) < 3 & abs(zz) < 4) = 0.4;
            im = im + 0.03*randn(N,N,N);
        end

        function data = sampleAlong(p, traj, im, matrixSize)
            % Acquire the phantom along a trajectory
            d = proud.reco.fwdNUFT(p, proud.Reporter(), traj, reshape(im,matrixSize), matrixSize);
            data = reshape(d, [1 size(traj,2) size(traj,3)]);
        end

    end

    methods (Test)

        % -----------------------------------------------------------------
        % 2D radial
        % -----------------------------------------------------------------

        function recovers2DDelays(tc)
            N = 32; p = tGradientDelays.params();
            traj = tGradientDelays.radial2D(N, 64, 2*N+1);
            im = tGradientDelays.phantom2D(N, 7);

            dTrue = [0.9 -0.6 0 0 0 0];
            data = tGradientDelays.sampleAlong(p, ...
                proud.traj.trajInterpolation(traj, dTrue), im, [N N 1]);

            d = proud.reco.calibrateDelays2D(proudData(), p, data, traj, ...
                zeros(1,6), [N N 1], 1, 1);

            tc.verifyEqual(d(1:2), dTrue(1:2), 'AbsTol', tGradientDelays.Tol2D, ...
                'the 2D calibration must recover the delay that was applied');
        end

        function recovers2DDelaysOfTheOppositeSign(tc)
            % A sign error in the Gauss-Newton step passes a symmetric test and
            % fails this one, so both signs are exercised
            N = 32; p = tGradientDelays.params();
            traj = tGradientDelays.radial2D(N, 64, 2*N+1);
            im = tGradientDelays.phantom2D(N, 3);

            dTrue = [-0.8 0.5 0 0 0 0];
            data = tGradientDelays.sampleAlong(p, ...
                proud.traj.trajInterpolation(traj, dTrue), im, [N N 1]);

            d = proud.reco.calibrateDelays2D(proudData(), p, data, traj, ...
                zeros(1,6), [N N 1], 1, 1);

            tc.verifyEqual(d(1:2), dTrue(1:2), 'AbsTol', tGradientDelays.Tol2D);
        end

        function undelayedDataYieldsNoDelay(tc)
            N = 32; p = tGradientDelays.params();
            traj = tGradientDelays.radial2D(N, 64, 2*N+1);
            im = tGradientDelays.phantom2D(N, 5);
            data = tGradientDelays.sampleAlong(p, traj, im, [N N 1]);

            d = proud.reco.calibrateDelays2D(proudData(), p, data, traj, ...
                zeros(1,6), [N N 1], 1, 1);

            tc.verifyEqual(d(1:2), [0 0], 'AbsTol', tGradientDelays.Tol2D, ...
                'clean data must not produce a delay out of nothing');
        end

        function twoDCalibrationLeavesTheOutOfPlaneTermsAlone(tc)
            % A 2D radial trajectory has no kz: the estimator must not invent a
            % z delay or xz/yz cross-terms
            N = 32; p = tGradientDelays.params();
            traj = tGradientDelays.radial2D(N, 64, 2*N+1);
            im = tGradientDelays.phantom2D(N, 9);
            data = tGradientDelays.sampleAlong(p, ...
                proud.traj.trajInterpolation(traj, [0.5 0.3 0 0 0 0]), im, [N N 1]);

            d = proud.reco.calibrateDelays2D(proudData(), p, data, traj, ...
                zeros(1,6), [N N 1], 1, 1);

            tc.verifyEqual(d([3 5 6]), [0 0 0], 'AbsTol', 1e-12);
        end

        % -----------------------------------------------------------------
        % 3D UTE
        % -----------------------------------------------------------------

        function recovers3DDelays(tc)
            % All three axes at once. The z column of the Jacobian is much
            % larger than x and y for centre-out spokes, which is what made Gz
            % run away before the derivative was fixed.
            N = 20; p = tGradientDelays.params();
            traj = tGradientDelays.radial3D(N, 400, N);
            im = tGradientDelays.phantom3D(N, 11);

            dTrue = [0.7 -0.4 0.5 0 0 0];
            data = tGradientDelays.sampleAlong(p, ...
                proud.traj.trajInterpolation(traj, dTrue), im, [N N N]);

            d = proud.reco.calibrateDelays3D(proudData(), p, data, traj, ...
                zeros(1,6), [N N N]);

            tc.verifyEqual(d(1:3), dTrue(1:3), 'AbsTol', tGradientDelays.Tol3D, ...
                'the 3D calibration must recover all three delays');
        end

        function threeDDelaysStayBounded(tc)
            % Gz used to grow without bound over the iterations
            N = 20; p = tGradientDelays.params();
            traj = tGradientDelays.radial3D(N, 400, N);
            im = tGradientDelays.phantom3D(N, 13);
            data = tGradientDelays.sampleAlong(p, traj, im, [N N N]);

            d = proud.reco.calibrateDelays3D(proudData(), p, data, traj, ...
                zeros(1,6), [N N N]);

            tc.verifyLessThan(max(abs(d(1:3))), 3, ...
                'an undelayed 3D dataset must not drive the delays away');
        end

        % -----------------------------------------------------------------
        % Calibration off
        % -----------------------------------------------------------------

        function calibrationOffReturnsTheInputUnchanged(tc)
            p = tGradientDelays.params();
            p.gradDelayCalibration = false;
            dIn = [0.11 0.22 0.33 0.44 0.55 0.66];

            N = 16;
            traj = tGradientDelays.radial2D(N, 16, 2*N+1);
            data = zeros(1, size(traj,2), size(traj,3));

            tc.verifyEqual(proud.reco.calibrateDelays2D(proudData(), p, data, traj, ...
                dIn, [N N 1], 1, 1), dIn);
            tc.verifyEqual(proud.reco.calibrateDelays3D(proudData(), p, data, traj, ...
                dIn, [N N N]), dIn);
        end

    end

end
