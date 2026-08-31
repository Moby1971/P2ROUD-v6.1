function data = fwdNUFT(params, reporter, kTraj, image, matrixSize)

% Forward NUFFT, with Bart when available and the Matlab NUFFT otherwise
%
%   data = proud.reco.fwdNUFT(params, reporter, kTraj, image, matrixSize)
%
%   params       reconstruction parameters; params.bartDetected and
%                params.gpuPresent choose the backend
%   reporter     proud.Reporter; omit or pass empty to run silent
%   kTraj        3 x samples x spokes trajectory, cycles per FOV
%   image        the volume to transform
%   matrixSize   [nx ny nz] of that volume, for the Matlab backend
%   data         samples along the trajectory
%
% Bart and nufft_3d use the same trajectory convention (cycles/FOV,
% centered on 0) and the same sign; they differ only by a real scale
% factor, 1/N in 2D and 1/N^1.5 in 3D. That factor cancels as long as the
% forward, the inverse and the derivatives all come from the same one,
% which is why the choice is made here and nowhere else.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    if params.bartDetected
        if params.gpuPresent
            data = bart(reporter,'nufft -g ',kTraj,image);
        else
            data = bart(reporter,'nufft ',kTraj,image);
        end
    else
        objNufft = nufft_3d(reshape(kTraj,3,[]),matrixSize,reporter);
        data = objNufft.fNUFT(image);
    end

end % fwdNUFT
