function [dydtx,dydty] = partialDerivative2D(params,reporter,kTraj,Xnew,calibSize)

% Derivative of the 2D forward NUFFT with respect to the gradient delays
%
%   [dydtx, dydty] = partialDerivative2D(params, reporter, kTraj, Xnew, calibSize)
%
%   params      reconstruction parameters, for the NUFFT backend
%   reporter    proud.Reporter; omit or pass empty to run silent
%   kTraj       3 x samples x spokes trajectory
%   Xnew        current image estimate, coils in dimension 3
%   calibSize   matrix size the derivative is evaluated at
%   dydtx       derivative with respect to the x gradient delay
%   dydty       derivative with respect to the y gradient delay
%
%   y(k) = sum_r m(r) exp(-2i*pi*k.r/N)  =>  dy/dk = NUFFT( -2i*pi*(r/N) m )
%
% and trajInterpolation(k,d) evaluates the trajectory at sample i-d, so
% dk/dd = -dk/di. Both factors matter: without them the step is scaled
% wrongly and points the wrong way.%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    nCoils = size(Xnew,3);

    kx = squeeze(kTraj(1,:,:));
    ky = squeeze(kTraj(2,:,:));

    % K-space step per readout sample
    dkx = zeros(size(kx));
    dky = zeros(size(ky));

    dkx(2:end,:) = kx(2:end,:)- kx(1:end-1,:);
    dky(2:end,:) = ky(2:end,:)- ky(1:end-1,:);
    dkx(1,:) = dkx(2,:);
    dky(1,:) = dky(2,:);

    % Image coordinates, centered in the same way as the image that
    % ifft2Dmri returns
    repX = reshape(((0:calibSize(1)-1)-floor(calibSize(1)/2))/calibSize(1),[calibSize(1) 1]);
    repY = reshape(((0:calibSize(2)-1)-floor(calibSize(2)/2))/calibSize(2),[1 calibSize(2)]);

    imCalib = (-2j*pi)*proud.util.ifft2Dmri(Xnew);

    tmp = imCalib.*repX;
    tmpCalib = proud.reco.fwdNUFT(params,reporter,kTraj,reshape(tmp,[calibSize 1 nCoils]),calibSize);
    dydkx = reshape(tmpCalib,[size(kx) nCoils]);

    tmp = imCalib.*repY;
    tmpCalib = proud.reco.fwdNUFT(params,reporter,kTraj,reshape(tmp,[calibSize 1 nCoils]),calibSize);
    dydky = reshape(tmpCalib,[size(kx) nCoils]);

    dydtx = dydkx.*repmat(-dkx,[1 1 nCoils]);
    dydty = dydky.*repmat(-dky,[1 1 nCoils]);

    dydtx(isnan(dydtx)) = 0;
    dydty(isnan(dydty)) = 0;

end % partialDerivative2D
