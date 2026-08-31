function image = invNUFT(params, reporter, kTraj, data, matrixSize, lambda)

% Inverse NUFFT, the counterpart of fwdNUFT
%
%   image = invNUFT(params, reporter, kTraj, data, matrixSize, lambda)
%
%   params       reconstruction parameters; chooses Bart or the Matlab NUFFT
%   reporter     proud.Reporter; omit or pass empty to run silent
%   kTraj        3 x samples x spokes trajectory, cycles per FOV
%   data         samples along that trajectory
%   matrixSize   [nx ny nz] of the volume to reconstruct
%   lambda       Tikhonov regularisation weight for the iterative solve
%   image        the reconstructed volume
%
% Must use the same backend as fwdNUFT, since the two differ by a real scale
% factor that only cancels when both come from the same implementation.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    if params.bartDetected

        cSize = ['-x',num2str(matrixSize(1)),':',num2str(matrixSize(2)),':',num2str(matrixSize(3))];
        if params.gpuPresent
            image = bart(reporter,['nufft -g -i -l',num2str(lambda),' ',cSize,' -t'],kTraj,data);
        else
            image = bart(reporter,['nufft -i -l',num2str(lambda),' ',cSize,' -t'],kTraj,data);
        end

    else

        objNufft = nufft_3d(reshape(kTraj,3,[]),matrixSize,reporter);
        raw = reshape(data,size(kTraj,2)*size(kTraj,3),[]);
        image = objNufft.iNUFT(raw,10,lambda,[],'',[],reporter);
        image = reshape(image,[matrixSize(1) matrixSize(2) matrixSize(3) size(raw,2)]);

    end

end % invNUFT
