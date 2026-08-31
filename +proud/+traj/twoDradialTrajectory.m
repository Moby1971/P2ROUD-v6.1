function traj = twoDradialTrajectory(dimX, dimY, dimZ, dimD, dimF, dimE)

% 2D radial trajectory, spokes spread over 0 to 180 degrees
%
%   traj = proud.traj.twoDradialTrajectory(dimX, dimY, dimZ, dimD, dimF, dimE)
%
%   dimX    readout samples per spoke
%   dimY    number of spokes; they divide 180 degrees evenly
%   dimZ    slices
%   dimD    dynamics
%   dimF    flip angles
%   dimE    echoes
%   traj    3 x dimX x dimY x dimZ x dimD x dimF x dimE trajectory
%
% The same spoke pattern is repeated for every slice, dynamic, flip angle and
% echo; those dimensions exist so the trajectory lines up with the data array
% without further reshaping.
%
% DC sits at the centre of the readout. The sample positions are offset by
% (dimX-1)/2, so for an even number of samples DC falls between two of them,
% which is what Bart expects.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    fullAngle = 180;

    % Sample positions along the spoke, with DC in the center of the readout.
    % Correct for an even and for an odd number of readout samples, for an
    % even number DC falls between two samples, as Bart expects.
    kRadius = (0:dimX-1) - (dimX-1)/2;

    % Spoke angles
    spokeAngle = (pi/180)*((0:dimY-1)*fullAngle/dimY);

    traj = zeros(3,dimX,dimY,dimZ,dimD,dimF,dimE);

    for echo = 1:dimE
        for fa = 1:dimF
            for dynamic = 1:dimD
                for slice = 1:dimZ
                    for y = 1:dimY
                        % crds, x, y(spoke), slice, repetitions, flip-anlge, echo-times
                        traj(1,:,y,slice,dynamic,fa,echo) = kRadius*cos(spokeAngle(y));
                        traj(2,:,y,slice,dynamic,fa,echo) = kRadius*sin(spokeAngle(y));
                        traj(3,:,y,slice,dynamic,fa,echo) = 0;
                    end
                end
            end
        end
    end

end % twoDradialTrajectory
