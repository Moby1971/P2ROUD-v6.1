function [image, phase] = homodyne(reporter, kSpace, method)

% Partial Fourier reconstruction for 2D or 3D data
%
%   [image, phase] = proud.reco.homodyne(reporter, kSpace, method)
%
%   reporter   proud.Reporter; omit or pass empty to run silent
%   kSpace     partially filled k-space, nx x ny x nz x nCoils. Points that
%              were not sampled must be exactly zero -- the sampled region is
%              worked out from where the zeros are, not passed in
%   method     'homodyne', 'pocs', 'least-squares', 'compressed-sensing',
%              or 'none' to bypass the reconstruction and just transform
%   image      reconstructed image, same size as kSpace
%   phase      the phase estimate taken from the symmetrically sampled centre
%              and used to make the image real
%
% Only one dimension may be partially sampled; a fully sampled data set is
% detected and takes the 'none' path. Multiple coils are handled by recursion,
% one coil at a time, so the algorithm itself only ever sees a single coil.
%
% The filter applied to the symmetric centre is set by opts.window below and
% the iterative methods are governed by the regularisation terms beside it.

% Without a reporter this function is silent, so it runs headless
if nargin < 1 || isempty(reporter)
    reporter = proud.Reporter();
end

% options

opts.method = method; % 'homodyne','pocs','least-squares','compressed-sensing','none'
opts.window = 'cubic'; % 'step','ramp','quad','cubic','quartic'
opts.removeOS = 0; % remove 2x oversampling in specified dimension (0=off)

% regularization terms (only apply to least squares/compressed sensing)
opts.damp = 1e-4; % L2 penalty on solution norm
opts.lambda = 1e-2; % L2 penalty on imag norm
opts.cs = 5e-4; % L1 penalty on tranform norm


%% handle looping over multi-coil / echo

[nx, ny, nz, nc] = size(kSpace);

if nx==1 || ny==1
    reporter.message('Only 2D or 3D kspace allowed ...');
end

if nx==0 || ny==0 || nz==0 || nc==0
   reporter.message('Empty kspace not allowed ...'); 
end

if nc>1

    for c = 1:nc
        [image(:,:,:,c), phase(:,:,:,c)] = proud.reco.homodyne(reporter,kSpace(:,:,:,c),opts.method); %#ok<*AGROW> 
    end
    
    sz = size(kSpace); 
    if opts.removeOS 
        sz(opts.removeOS) = sz(opts.removeOS)/2; 
    end
    image = reshape(image,sz);
    phase = reshape(phase,sz);  
    
else
    
    % detect sampling
    mask = (kSpace~=0);
    kx = find(any(any(mask,2),3));
    ky = find(any(any(mask,1),3));
    kz = find(any(any(mask,1),2));
    
    if any(diff(kx)~=1) || any(diff(ky)~=1) || any(diff(kz)~=1)
       % reporter.message('K-space not centered or not contiguous ...');
    end
    
    % fraction of sampling in kx, ky, kz
    f = [numel(kx)/nx numel(ky)/ny];
    if nz>1; f(3) = numel(kz)/nz; end
    
    % some checks
    [~,dim] = min(f);
    %fprintf('partial sampling: [%s]. Using dimension %i.\n',num2str(f,'%.2f '),dim);
    
    if min(f<0.1)
        reporter.message('K-space is too undersampled - must be at least 0.1 ...');
    end
    
    if all(f>0.95)
        % reporter.message('K-space is fully sampled - skipping homodyne');
        opts.method = 'none'; % fully sampled - bypass recon
    end
    
    %% set up filters

    if ~isequal(opts.method,'none')
        
        if dim==1; H = zeros(nx,1,1); index = kx; end
        if dim==2; H = zeros(1,ny,1); index = ky; end
        if dim==3; H = zeros(1,1,nz); index = kz; end
        H(index) = 1;
        
        % high pass filter
        H = H + flip(1-H);
        
        % symmetric center of kspace
        center = find(H==1);
        center(end+1) = numel(H)/2+1; % make sure
        center = unique(center);
        center = [center(1)-1;center(:);center(end)+1]; % pad by 1 point
        ramp = linspace(H(center(1)),H(center(end)),numel(center)); % symmetric points sum to 2
        
        switch opts.window
            case 'step'
                H(center) = 1;
            case {'linear','ramp'}
                H(center) = ramp;
            case {'quadratic','quad'}
                H(center) = (ramp-1).^2.*sign(ramp-1)+1;
            case {'cubic','cube'}
                H(center) = (ramp-1).^3+1;
            case {'quartic'}
                H(center) = (ramp-1).^4.*sign(ramp-1)+1;
            otherwise
                reporter.message('Opts.window not recognized ...');
        end
        
        % low pass filter
        L = sqrt(max(0,1-(H-1).^2));
        
        % low resolution phase
        phase = bsxfun(@times,L,kSpace);
        phase = angle(ifftn(ifftshift(phase)));
    end
    
    %% reconstruction
    
    maxit = 10; % no. of iterations to use for iterative opts.methods
    
    switch(opts.method)
        
        case 'homodyne'
            
            image = bsxfun(@times,H,kSpace);
            image = ifftn(ifftshift(image)).*exp(-1i*phase);
            image = abs(real(image));
            image = fftshift(image);
            phase = fftshift(phase);
            
        case 'pocs'
            
            tmp = kSpace;
            
            for iter = 1:maxit
                
                % abs and low res phase
                image = abs(ifftn(tmp));
                tmp = image.*exp(1i*phase);
                
                % data consistency
                tmp = fftshift(fftn(tmp));
                tmp(mask) = kSpace(mask);
                
            end
            
        case 'least-squares'

            % L2 penalized least squares requires pcgpc.m
            b = reshape(exp(-1i*phase).*ifftn(ifftshift(kSpace)),[],1);
            tmp = pcgpc(@(x)pcpop(x,mask,phase,opts.lambda,opts.damp),b,[],maxit);
            image = abs(real(reshape(tmp,size(phase))));

        case 'compressed-sensing'
            
            % L1 penalized least squares requires pcgpc.m
            Q = DWT([nx ny nz],'db2'); % wavelet transform
            b = reshape(Q*(exp(-1i*phase).*ifftn(ifftshift(kSpace))),[],1);
            tmp = pcgL1(@(x)pcpop(x,mask,phase,opts.lambda,opts.damp,Q),b,opts.cs);
            image = abs(real(reshape(Q'*tmp,size(phase))));
            
        case 'none'
            
            % Gustav Strijkers
            
            x = kSpace;

            X = fftshift(ifft(fftshift(x,1),[],1),1)*sqrt(size(x,1));
            X = fftshift(ifft(fftshift(X,2),[],2),2)*sqrt(size(x,2));
            X = fftshift(ifft(fftshift(X,3),[],3),3)*sqrt(size(x,3));

            image = abs(X);
            phase = angle(X);
            
        otherwise
            
            reporter.message('Unknown opts.method ...');
            
    end

    
    if opts.removeOS

        image = fftshift(image);
        phase = fftshift(phase);
        
        switch opts.removeOS
            case 1; ok = nx/4 + (1:nx/2);
                image = image(ok,:,:,:);
                phase = phase(ok,:,:,:);
            case 2; ok = ny/4 + (1:ny/2);
                image = image(:,ok,:,:);
                phase = phase(:,ok,:,:);
            case 3; ok = nz/4 + (1:nz/2);
                image = image(:,:,ok,:);
                phase = phase(:,:,ok,:);
            otherwise
                reporter.message('RemoveOS dimension not supported ...');
        end
        
    end
    
end

%% phase constrained projection operator (image <- image)
function y = pcpop(x,mask,phase,lambda,damp,Q)
% y = P' * F' * W * F * P * x + i * imag(x) + damp * x
x = reshape(x,size(phase));
if exist('Q','var'); x = Q'*x; end
y = exp(1i*phase).*x;
y = fftn(y);
y = fftshift(mask).*y;
y = ifftn(y);
y = exp(-1i*phase).*y;
y = y + lambda*1i*imag(x) + damp*x;
if exist('Q','var'); y = Q*y; end
y = reshape(y,[],1);
