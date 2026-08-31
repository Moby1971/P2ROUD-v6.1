function dTotal = estdelayToDelays(qf)

% Bart estdelay output -> the class's per-axis gradient delays
%
%   dTotal = proud.reco.estdelayToDelays(qf)
%
%   qf       what 'bart estdelay' returns, three numbers in samples
%   dTotal   [Gx Gy Gz Sxy Sxz Syz] in samples, the form
%            proud.traj.trajInterpolation takes
%
% estdelay is a 2D radial method, so Gz, Sxz and Syz always stay zero.
%
% estdelay does NOT return the same triple that 'bart traj -q'
% consumes. Measured over 24 randomised delays, two matrix sizes and
% two spoke counts, the two are related by
%
%     qf = M * Q,    M = [ 1   0   0  ]      Q = the traj -q triple
%                        [ 1/2 1/2 0  ]          (y, x, yx)
%                        [ 0   0   1/2]
%
% to a residual of 2e-3 samples, so
%
%     Q = [ qf(1), 2*qf(2) - qf(1), 2*qf(3) ].
%
% Taking qf for Q directly leaves half the delay in place on the x
% and cross terms; it is exact only when the delay is isotropic,
% where M is the identity, which is why it looked verified.
%
% From Q to dTotal: Bart stores the trajectory with x and y
% interchanged (traj.c fills samples[0] from d[1]), so Q(1) belongs
% to the y gradient and Q(2) to the x gradient, and the sign is
% opposite because trajInterpolation resamples along the readout
% where Bart displaces the trajectory. The reconstruction inverts
% this again at the point of use, qBart = [-dTotal(2), -dTotal(1),
% -dTotal(4)], so the round trip has to hold.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    qf = double(qf(:)');

    if (numel(qf) ~= 3) || any(~isfinite(qf)) || any(abs(qf) > proud.Constants.MAX_GRAD_DELAY)
        error('proudData:estdelayOutput', ...
            'Bart estdelay did not return a usable gradient delay');
    end

    % estdelay's parameterisation -> the triple 'bart traj -q' takes
    q = [qf(1), 2*qf(2) - qf(1), 2*qf(3)];

    dTotal = [-q(2), -q(1), 0, -q(3), 0, 0];

end % estdelayToDelays
