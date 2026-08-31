classdef tEstdelay < matlab.unittest.TestCase
    % Bart's gradient delay conventions
    %
    % Three things have to hold for the estdelay path to correct anything, and
    % each is checked against Bart itself rather than derived on paper:
    %
    %   1. trajApplyDelays implements the same model as "bart traj -q", which
    %      shifts each spoke along its own readout.
    %   2. trajInterpolation, given the axis swap and sign flip the class
    %      applies, implements the same model as "bart traj -O -q", which
    %      displaces the trajectory in the plane.
    %   3. the number estdelay returns, put through the class's mapping and
    %      applied, actually removes the delay that was in the data.
    %
    % (1) and (2) are convention checks and hold to float precision. (3) is the
    % one that matters: a mapping can be self-consistent -- applying what it
    % estimated, in the convention it estimated it -- and still be the wrong
    % inverse of what estdelay actually measures.
    %
    % Skipped when Bart is not installed.

    properties (Constant)
        Q = [0.30 -0.45 0.20]    % as bart documents -q : y, x, yx
    end

    methods (TestMethodSetup)
        function requireBart(tc)
            tc.assumeNotEmpty(which('bart'), 'bart.m not on the path');
            [st,~] = system('which bart');
            tc.assumeEqual(st, 0, 'the bart executable is not installed');
        end
    end

    methods (Static)

        function t = traj(N, S, opts)
            if nargin < 3; opts = ''; end
            t = real(bart(proud.Reporter(), sprintf('traj -x%d -y%d -r%s', N, S, opts)));
        end

        function t = trajQ(N, S, q, opts)
            if nargin < 4; opts = ''; end
            t = real(bart(proud.Reporter(), sprintf('traj -x%d -y%d -r%s -q%g:%g:%g', ...
                N, S, opts, q(1), q(2), q(3))));
        end

        function e = relErr(a, b)
            e = norm(a(:)-b(:))/norm(b(:));
        end

    end

    methods (Test)

        % -----------------------------------------------------------------
        % 1. the along-readout model
        % -----------------------------------------------------------------

        function trajApplyDelaysMatchesBartTrajQ(tc)
            N = 64; S = 89; q = tEstdelay.Q;
            t0 = tEstdelay.traj(N,S);
            tq = tEstdelay.trajQ(N,S,q);
            tc.verifyLessThan(tEstdelay.relErr(proud.traj.trajApplyDelays(t0,q), tq), ...
                1e-6, 'trajApplyDelays must reproduce bart traj -q exactly');
        end

        function trajApplyDelaysIsSignSensitive(tc)
            % The same test with the sign flipped must fail, or it is not
            % testing the convention at all
            N = 64; S = 89; q = tEstdelay.Q;
            t0 = tEstdelay.traj(N,S);
            tq = tEstdelay.trajQ(N,S,q);
            tc.verifyGreaterThan(tEstdelay.relErr(proud.traj.trajApplyDelays(t0,-q), tq), ...
                1e-3);
        end

        % -----------------------------------------------------------------
        % 2. the in-plane displacement model, and the axis swap
        % -----------------------------------------------------------------

        function trajInterpolationMatchesBartTrajOQ(tc)
            % The class maps a bart triple qf onto its own per-axis delays as
            % dTotal = [-qf(2), -qf(1), 0, -qf(3)], swapping x and y because
            % bart stores the trajectory transposed, and flipping the sign
            % because trajInterpolation resamples where bart displaces.
            N = 64; S = 89; q = tEstdelay.Q;
            t0 = tEstdelay.traj(N,S,' -O');
            tq = tEstdelay.trajQ(N,S,q,' -O');

            dTotal = [-q(2), -q(1), 0, -q(3), 0, 0];
            ti = proud.traj.trajInterpolation(t0, dTotal);

            m = 6:N-5;                         % away from the extrapolated ends
            tc.verifyLessThan(tEstdelay.relErr(ti(:,m,:), tq(:,m,:)), 1e-6, ...
                'the documented axis swap and sign must reproduce bart traj -O -q');
        end

        function theAxisSwapIsNecessary(tc)
            % x and y are not interchangeable: without the swap the correction is
            % wrong for any delay that is not isotropic, and applying it leaves
            % more error than applying nothing
            N = 64; S = 89; q = tEstdelay.Q;
            t0 = tEstdelay.traj(N,S,' -O');
            tq = tEstdelay.trajQ(N,S,q,' -O');
            m = 6:N-5;

            straight = proud.traj.trajInterpolation(t0, [-q(1), -q(2), 0, -q(3), 0, 0]);
            tc.verifyGreaterThan(tEstdelay.relErr(straight(:,m,:), tq(:,m,:)), 1e-3, ...
                'x and y must not be interchangeable here');
        end

        % -----------------------------------------------------------------
        % 3. the end-to-end claim
        % -----------------------------------------------------------------

        function estdelayMappingRemovesTheDelay(tc)
            % Sample a phantom along a delayed trajectory, estimate the delay
            % from the nominal one, apply the class's mapping, and check that
            % the corrected trajectory is the one the data was really acquired
            % along. This is what the reconstruction does.
            N = 64; S = 121;
            r = proud.Reporter();
            ph = real(bart(r, sprintf('phantom -x%d', N)));
            t0 = tEstdelay.traj(N,S);

            for q = {[0.30 0 0], [0 0.30 0], [0 0 0.30], [0.30 -0.45 0.20]}
                qTrue = q{1};
                tq = tEstdelay.trajQ(N,S,qTrue);
                data = bart(r, 'nufft', tq, reshape(ph,[N N 1]));

                qf = double(reshape(real(bart(r,'estdelay ',t0,data)),1,[]));
                dTotal = proud.reco.estdelayToDelays(qf);

                % what the reconstruction applies for the final 2D correction
                qBart = [-dTotal(2), -dTotal(1), -dTotal(4)];
                corrected = proud.traj.trajApplyDelays(t0, qBart);

                before = tEstdelay.relErr(t0, tq);
                after  = tEstdelay.relErr(corrected, tq);
                tc.verifyLessThan(after, 0.1*before, sprintf( ...
                    ['estdelay correction left %.1f%% of the delay for q = %s ' ...
                     '(residual %.4f, uncorrected %.4f)'], ...
                    100*after/before, mat2str(qTrue), after, before));
            end
        end

        function estdelayMappingIsExactForIsotropicDelays(tc)
            % The isotropic case is the one every candidate mapping gets right,
            % so passing it alone proves nothing -- it is here to show the test
            % above is not simply failing everything
            N = 64; S = 121;
            r = proud.Reporter();
            ph = real(bart(r, sprintf('phantom -x%d', N)));
            t0 = tEstdelay.traj(N,S);
            qTrue = [0.2 0.2 0];
            tq = tEstdelay.trajQ(N,S,qTrue);
            data = bart(r, 'nufft', tq, reshape(ph,[N N 1]));

            qf = double(reshape(real(bart(r,'estdelay ',t0,data)),1,[]));
            dTotal = proud.reco.estdelayToDelays(qf);
            qBart = [-dTotal(2), -dTotal(1), -dTotal(4)];
            corrected = proud.traj.trajApplyDelays(t0, qBart);

            tc.verifyLessThan(tEstdelay.relErr(corrected, tq), ...
                0.1*tEstdelay.relErr(t0, tq));
        end

        function estdelayRejectsUnusableOutput(tc)
            % The mapping must not pass through a nonsense estimate
            tc.verifyError(@() proud.reco.estdelayToDelays([1 2]), ...
                'proudData:estdelayOutput');
            tc.verifyError(@() proud.reco.estdelayToDelays([1 NaN 2]), ...
                'proudData:estdelayOutput');
            tc.verifyError(@() proud.reco.estdelayToDelays([1 1e6 2]), ...
                'proudData:estdelayOutput');
        end

    end

end
