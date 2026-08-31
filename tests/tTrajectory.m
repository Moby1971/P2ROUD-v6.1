classdef tTrajectory < matlab.unittest.TestCase
    % Trajectory delay models
    %
    % Covers the two models the class keeps side by side:
    %
    %   trajApplyDelays   shifts every spoke ALONG its own readout direction by
    %                     delta(theta) = q(2)cos^2 + q(1)sin^2 + q(3)sin(2 theta).
    %                     This is the model Bart's estdelay estimates and Bart's
    %                     own "traj -q" applies. Used for the final 2D
    %                     application.
    %
    %   trajInterpolation shifts the kx, ky and kz COMPONENTS independently, and
    %                     applies the cross-terms as delta_k = -dRho*(S*n). Used
    %                     by the iterative estimators, which differentiate with
    %                     respect to its per-axis parameters, and by the 3D UTE
    %                     and ZTE paths.
    %
    % The expectations below are derived from those two definitions, not from
    % the implementation.

    methods (Static)

        function traj = spoke(theta, nrSamples)
            % One radial spoke through the origin, at angle theta, unit sample step
            if nargin < 2; nrSamples = 65; end
            r = (0:nrSamples-1) - floor(nrSamples/2);
            traj = zeros(3,nrSamples);
            traj(1,:) = r*cos(theta);
            traj(2,:) = r*sin(theta);
        end

    end

    methods (Test)

        % -----------------------------------------------------------------
        % trajApplyDelays
        % -----------------------------------------------------------------

        function alongReadoutShiftIsExactOnAxis(tc)
            % A spoke along +x sees only q(2), a spoke along +y only q(1)
            qx = 0.37; qy = -0.21;

            tx = tTrajectory.spoke(0);
            sx = proud.traj.trajApplyDelays(tx,[qy qx 0]);
            tc.verifyEqual(sx(1,:), tx(1,:) + qx, 'AbsTol', 1e-12, ...
                'x spoke must shift by q(2) along x');
            tc.verifyEqual(sx(2,:), tx(2,:), 'AbsTol', 1e-12, ...
                'x spoke must not move in y');

            ty = tTrajectory.spoke(pi/2);
            sy = proud.traj.trajApplyDelays(ty,[qy qx 0]);
            tc.verifyEqual(sy(2,:), ty(2,:) + qy, 'AbsTol', 1e-12, ...
                'y spoke must shift by q(1) along y');
            tc.verifyEqual(sy(1,:), ty(1,:), 'AbsTol', 1e-12, ...
                'y spoke must not move in x');
        end

        function crossTermActsAt45Degrees(tc)
            % sin(2 theta) is 1 at 45 degrees and 0 on both axes
            qxy = 0.44;

            t45 = tTrajectory.spoke(pi/4);
            s45 = proud.traj.trajApplyDelays(t45,[0 0 qxy]);
            d = [s45(1,:) - t45(1,:); s45(2,:) - t45(2,:)];
            tc.verifyEqual(d, repmat(qxy*[cos(pi/4); sin(pi/4)],1,size(d,2)), ...
                'AbsTol', 1e-12, 'cross term must displace by q(3) along the spoke');

            t0 = tTrajectory.spoke(0);
            tc.verifyEqual(proud.traj.trajApplyDelays(t0,[0 0 qxy]), t0, ...
                'AbsTol', 1e-12, 'cross term must vanish on the x axis');
        end

        function shiftFollowsTheAngularModel(tc)
            % The full delta(theta) over a fan of spokes
            q = [0.31 -0.17 0.09];
            theta = linspace(0, pi, 17);
            for k = 1:numel(theta)
                t = tTrajectory.spoke(theta(k));
                s = proud.traj.trajApplyDelays(t,q);
                expect = q(2)*cos(theta(k))^2 + q(1)*sin(theta(k))^2 + q(3)*sin(2*theta(k));
                moved = [s(1,1)-t(1,1); s(2,1)-t(2,1)];
                tc.verifyEqual(norm(moved)*sign(moved'*[cos(theta(k)); sin(theta(k))]), ...
                    expect, 'AbsTol', 1e-12, ...
                    sprintf('delta(theta) wrong at theta = %.3f rad', theta(k)));
            end
        end

        function zeroDelayIsIdentity(tc)
            t = tTrajectory.spoke(0.7);
            tc.verifyEqual(proud.traj.trajApplyDelays(t,[0 0 0]), t);
            tc.verifyEqual(proud.traj.trajApplyDelays(t,[]), t);
        end

        function shortDelayVectorIsPadded(tc)
            t = tTrajectory.spoke(0);
            tc.verifyEqual(proud.traj.trajApplyDelays(t,[0 0.5]), ...
                           proud.traj.trajApplyDelays(t,[0 0.5 0]), 'AbsTol', 1e-12);
        end

        function kzIsUntouched(tc)
            % The model is 2D: it must never move kz
            t = tTrajectory.spoke(0.4);
            t(3,:) = linspace(-3,3,size(t,2));
            s = proud.traj.trajApplyDelays(t,[0.3 -0.2 0.1]);
            tc.verifyEqual(s(3,:), t(3,:), 'AbsTol', 1e-12);
        end

        function shapeIsPreserved(tc)
            % Multi-dimensional trajectory arrays must come back the same shape
            t = repmat(tTrajectory.spoke(0.3),[1 1 8 2]);
            s = proud.traj.trajApplyDelays(t,[0.2 0.1 0]);
            tc.verifyEqual(size(s), size(t));
        end

        % -----------------------------------------------------------------
        % trajInterpolation
        % -----------------------------------------------------------------

        function perComponentShiftIsPerAxis(tc)
            % trajInterpolation resamples as k_new(i) = k_old(i - d), so a delay
            % of d samples moves the kx component by -d along the readout, and
            % leaves ky alone. The sign is the point: this is the convention the
            % iterative estimators differentiate against.
            dx = 0.4;
            theta = pi/4;
            t = tTrajectory.spoke(theta, 129);
            s = proud.traj.trajInterpolation(t,[dx 0 0]);

            % Away from the ends, where the extrapolation takes over
            m = 10:size(t,2)-10;
            tc.verifyEqual(s(1,m), t(1,m) - dx*cos(theta), 'AbsTol', 1e-9, ...
                'kx must move by -dx samples along the readout');
            tc.verifyEqual(s(2,m), t(2,m), 'AbsTol', 1e-9, ...
                'a pure dx must not move ky');
        end

        function theTwoModelsAgreeUnderTheDocumentedConversion(tc)
            % The 2D radial paths hand Bart's model the physical delays as
            %
            %     q = (-Gy, -Gx, -Sxy)
            %
            % Isotropic delays are the case both models represent exactly, so
            % under that conversion they must agree to interpolation accuracy.
            % A wrong conversion here leaves more error than applying no
            % correction at all.
            d = 0.3;
            for theta = linspace(0, pi, 9)
                t = tTrajectory.spoke(theta, 129);
                m = 10:size(t,2)-10;
                a = proud.traj.trajApplyDelays(t, [-d -d 0]);     % q = (-Gy,-Gx,-Sxy)
                b = proud.traj.trajInterpolation(t, [d d 0]);     % [Gx Gy Gz]
                tc.verifyEqual(b(1:2,m), a(1:2,m), 'AbsTol', 1e-9, ...
                    sprintf('models disagree at theta = %.3f rad', theta));
            end
        end

        function theModelsMustDifferForAnisotropicDelays(tc)
            % When dx ~= dy the along-readout model cannot be reproduced by
            % per-axis shifts: the mismatch is a real perpendicular displacement,
            % which is why both models are kept rather than one.
            t = tTrajectory.spoke(pi/4, 129);
            m = 10:size(t,2)-10;
            a = proud.traj.trajApplyDelays(t, [0 -0.3 0]);        % Gx only
            b = proud.traj.trajInterpolation(t, [0.3 0 0]);
            tc.verifyGreaterThan(max(vecnorm(b(1:2,m)-a(1:2,m),2,1)), 1e-3, ...
                'the models must differ off axis when dx ~= dy');
        end

        function zeroShiftIsIdentity(tc)
            t = tTrajectory.spoke(0.7);
            tc.verifyEqual(proud.traj.trajInterpolation(t,[0 0 0]), t);
        end

        function crossTermIsAFirstOrderDisplacement(tc)
            % delta_k = -dRho*(S*n), with n the unit readout direction and dRho
            % the k-space step per sample along it. For a unit-step spoke at
            % theta with only sxy set, S*n = sxy*[sin(theta); cos(theta)].
            sxy = 0.25;
            theta = 0.6;
            t = tTrajectory.spoke(theta, 129);
            s = proud.traj.trajInterpolation(t,[0 0 0 sxy 0 0]);
            m = 10:size(t,2)-10;
            expect = -sxy*[sin(theta); cos(theta)];
            got = [mean(s(1,m)-t(1,m)); mean(s(2,m)-t(2,m))];
            tc.verifyEqual(got, expect, 'AbsTol', 1e-9, ...
                'cross term must apply -dRho*(S*n)');
        end

        function shapeIsPreservedByInterpolation(tc)
            t = repmat(tTrajectory.spoke(0.3),[1 1 8 2]);
            s = proud.traj.trajInterpolation(t,[0.2 0.1 0]);
            tc.verifyEqual(size(s), size(t));
        end

    end

end
