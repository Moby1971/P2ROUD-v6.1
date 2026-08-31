function trajUpdate = trajApplyDelays(trajOld, q)

% Apply Bart-convention gradient delays to a 2D radial trajectory
%
%   trajUpdate = proud.traj.trajApplyDelays(trajOld, q)
%
%   trajOld      3 x samples x spokes trajectory
%   q            [qx qy qxy], Bart's estdelay triple, in samples
%   trajUpdate   the shifted trajectory, same size as trajOld
%
% Shifts each spoke ALONG its own readout direction by an angle-dependent
% amount, which is the model Bart's estdelay estimates and Bart's own
% "traj -q" applies:
%
%     delta(theta) = q(2)*cos(theta)^2 + q(1)*sin(theta)^2 + q(3)*sin(2*theta)
%
% Bart documents -q as "gradient delays: y, x, yx", so q(1) is the y delay,
% q(2) the x delay and q(3) the yx cross term.
%
% Why not trajInterpolation here: that shifts the kx and ky COMPONENTS
% independently, which cannot represent this model. Matching the
% along-readout part with per-axis shifts forces a spurious PERPENDICULAR
% displacement of (dy - dx)*sin(theta)*cos(theta) - about 0.15 samples on
% every spoke for a 0.3 sample difference between the axes - and no choice
% of dx and dy removes it. trajInterpolation stays for the iterative
% estimators, which differentiate with respect to its per-axis parameters,
% and for the 3D UTE and ZTE paths, whose own estimator produces genuine
% per-axis delays including a real z that this 2D model cannot carry.
%
% Ported from the Retrospective10 project, where it was verified against
% Bart's own displacement field to a residual of 5e-07.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    q = double(q(:)');
    q(end+1:3) = 0;
    q = q(1:3);

    trajUpdate = trajOld;

    if ~any(q) || (size(trajOld,2) < 2)
        return;
    end

    dimsOld = size(trajOld);
    nrSamples = dimsOld(2);
    kOld = reshape(trajOld,3,nrSamples,[]);

    % Readout direction of every spoke, from its two end points
    vec = kOld(1:2,end,:) - kOld(1:2,1,:);
    nrm = sqrt(sum(vec.^2,1));
    valid = nrm > 0;
    dirVec = vec./max(nrm,eps);

    theta = atan2(dirVec(2,1,:),dirVec(1,1,:));
    delta = q(2)*cos(theta).^2 + q(1)*sin(theta).^2 + q(3)*sin(2*theta);
    delta = delta.*valid;

    kOld(1,:,:) = kOld(1,:,:) + delta.*dirVec(1,1,:);
    kOld(2,:,:) = kOld(2,:,:) + delta.*dirVec(2,1,:);

    trajUpdate = reshape(kOld,dimsOld);

end % trajApplyDelays
