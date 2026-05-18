function [epiCorr, phasePara] = twoDimLinearCorr_entropy(epiRaw, nShot)
%
% Gustav Strijkers
% May 2025
% g.j.strijkers@amsterdamumc.nl
%
% EPI Nyquist Ghost Correction using a 2D linear-phase model
% Extends the 1D model with an additional linear phase term along
% the phase-encoding direction to correct for oblique ghosting artifacts.
%
% Phase model: phi(x,y) = constant + linear_x * x + linear_y * y
%
% INPUTS:
%   epiRaw  - 4D array [kx ky slice coil]
%   nShot   - number of EPI shots (interleaves)
%
% OUTPUTS:
%   epiCorr   - corrected data, same size as input
%   phasePara - [nSlice x 3] array of [constant, linear_x, linear_y] phases

% ensure 4D
sz = size(epiRaw);
if numel(sz)<4
    epiRaw = reshape(epiRaw, sz(1), sz(2), 1, sz(3));
    sz = size(epiRaw);
end

epiCorr = zeros(sz);
nSlice = sz(3);
phasePara = zeros(nSlice,3);

for iSlice = 1:nSlice
    % permute to [ky kx coil]
    tmp = squeeze(epiRaw(:,:,iSlice,:));                % [kx ky coil]
    tmp = permute(tmp,[2 1 3]);                         % [ky kx coil]
    data_kyxc = fftshift( fft(tmp, [], 2), 2 );         % FFT along kx

    if iSlice==1
        [CorxKy_en, phasePara(iSlice,:)] = OIEntropyBasedCor2D(data_kyxc, nShot);
    else
        [CorxKy_en, phasePara(iSlice,:)] = OIEntropyBasedCor2D( ...
            data_kyxc, nShot, phasePara(iSlice-1,:) );
    end

    % inverse FFT back
    recon = ifft( fftshift(CorxKy_en,2), [], 2 );
    recon = permute(recon,[2 1 3]);                     % [kx ky coil]
    epiCorr(:,:,iSlice,:) = recon;
end

epiCorr = reshape(epiCorr, sz);
end

%% Subfunctions

function [AfterCor, PhasePara] = OIEntropyBasedCor2D(data_kyxc, Nshot, varargin)
% Chooses starting point by grid-search if none given, then Nelder-Mead
if nargin<3
    StartPoint = IGetStartPoint2D(data_kyxc, [-pi/3 pi/3], [-0.1 0.1], [-0.05 0.05], [50 30 20], Nshot);
else
    StartPoint = varargin{1};
end
opts = optimset('Display','off','MaxFunEvals',1000,'MaxIter',500);
PhasePara = fminsearch(@(x) OGetEntropy2D(data_kyxc,x,Nshot), StartPoint, opts);
% wrap constant phase into [-pi/2, +pi/2]
PhasePara(1) = mod(PhasePara(1)+pi/2,pi) - pi/2;
AfterCor = OIPhaseCor2D(data_kyxc, PhasePara, Nshot);
end

function E = OGetEntropy2D(data_kyxc, PhasePara, Nshot)
% Apply 2D phase correction then compute Shannon entropy
AfterCor = OIPhaseCor2D(data_kyxc, PhasePara, Nshot);
[nx,ny,~] = size(AfterCor);

img = fft(AfterCor,[],1);              % along ky
img = sum(abs(img).^2,3);              % sum over coils
S = sum(img(:));
B = sqrt(img)/S;
B(B == 0) = eps;
PE = B./log(B);
PE(~isfinite(PE)) = 0;
E = -sum(PE(:));
end

function StartPoint = IGetStartPoint2D(data_kyxc, ConRange, LinXRange, LinYRange, Nstep, Nshot)
% Coarse grid-search over [constant, linear_x, linear_y] phase
ConPhase  = linspace(ConRange(1),  ConRange(2),  Nstep(1)+1);
LinXPhase = linspace(LinXRange(1), LinXRange(2), Nstep(2)+1);
LinYPhase = linspace(LinYRange(1), LinYRange(2), Nstep(3)+1);

% First find best constant and linear_x with linear_y = 0 (coarse)
E2D = inf(numel(ConPhase), numel(LinXPhase));
for i=1:numel(ConPhase)
    for j=1:numel(LinXPhase)
        E2D(i,j) = OGetEntropy2D(data_kyxc, [ConPhase(i) LinXPhase(j) 0], Nshot);
    end
end
[iMin,jMin] = find(E2D==min(E2D(:)),1);
bestCon  = ConPhase(iMin);
bestLinX = LinXPhase(jMin);

% Then search linear_y around the best constant and linear_x
Ey = inf(numel(LinYPhase),1);
for k=1:numel(LinYPhase)
    Ey(k) = OGetEntropy2D(data_kyxc, [bestCon bestLinX LinYPhase(k)], Nshot);
end
[~,kMin] = min(Ey);
bestLinY = LinYPhase(kMin);

StartPoint = [bestCon bestLinX bestLinY];
end

function Cor_data_kyxc = OIPhaseCor2D(data_kyxc, PhasePara, Nshot)
% Apply constant + linear_x + linear_y phase per shot/interleaf
ConP  = PhasePara(1);
LinPx = PhasePara(2);
LinPy = PhasePara(3);
[nx,ny,nc] = size(data_kyxc);

% Phase along readout (x) direction
PhaseVecX = ConP + (0:ny-1)*LinPx;         % 1 x ny

% Phase along PE (y) direction
PhaseVecY = (0:nx-1)*LinPy;                % 1 x nx

% Build 2D phase map: phase(ky, x) = constant + linear_x * x + linear_y * ky
PhaseMat2D = PhaseVecY' + PhaseVecX;       % nx x ny

L = floor(nx/(2*Nshot));
% +phase on odd lines, -phase on even lines
PhMap = zeros(2*L, ny);
PhMap(1:2:end,:) =  PhaseMat2D(1:L,:);
PhMap(2:2:end,:) = -PhaseMat2D(1:L,:);

Cor_data_kyxc = zeros(size(data_kyxc));
for ii = 0:Nshot-1
    idx = ii+1:Nshot:nx;
    nIdx = numel(idx);
    PhMapFull = repmat(PhMap(1:nIdx,:), [1 1 nc]);
    Cor_data_kyxc(idx,:,:) = data_kyxc(idx,:,:) .* exp(1i*PhMapFull);
end
end
