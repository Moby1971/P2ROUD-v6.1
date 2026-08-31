function folderName = exportGifProud(obj, params, reporter)

% Export the reconstructed images as animated GIF files
%
%   folderName = proud.io.exportGifProud(obj, params, reporter)
%
%   obj          proudData holding the images to export
%   params       reconstruction parameters, for the export path and labels
%   reporter     proud.Reporter; omit or pass empty to run silent
%   folderName   folder the GIFs were written to, '' if nothing was written
%
% One GIF per slice and per echo, animated over the dynamic dimension, so a
% time series can be looked at without loading it into anything. Returns early
% with an empty folder name when the object holds no images.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

% Without a reporter this function is silent, so it runs headless
if nargin < 3 || isempty(reporter)
    reporter = proud.Reporter();
end

folderName = '';

% Check that image data exists
if isempty(obj.images)
    reporter.message("ERROR: no image data available for GIF export ...", 1);
    return
end

% Input images
gifImages = obj.images;

% Create new directory
maxAttempts = params.maxDirAttempts;
ready = false;
cnt = 1;
while ~ready && cnt <= maxAttempts
    folderName = strcat(params.gifExportPath,filesep,"GIF",filesep,params.tag,"P",filesep,num2str(cnt),filesep);
    if ~exist(folderName, 'dir')
        try
            mkdir(folderName);
            ready = true;
        catch ME
            reporter.message("ERROR: could not create GIF export folder ...", 1);
            reporter.message(ME.message, 2);
            folderName = '';
            return
        end
    end
    cnt = cnt + 1;
end

if ~ready
    reporter.message("ERROR: could not find a free GIF export folder ...", 1);
    folderName = '';
    return
end

reporter.message(strcat("GIF export folder = ",folderName));

% Phase orientation
if obj.phaseOrientation == 1
    reporter.message('INFO: phase orientation = 1');
    gifImages = permute(rot90(permute(gifImages,[2 1 3 4 5 6]),1),[2 1 3 4 5 6]);
end

% Size of the data
dimx = size(gifImages,1);
dimy = size(gifImages,2); %#ok<NASGU>
dimz = size(gifImages,3);
dimd = size(gifImages,4);
NFA = size(gifImages,5);
NE = size(gifImages,6);

% Window, level, and scale between 0 and GIF_MAX_GRAY grayvalues
window = params.window;
level = params.level;
window = window*obj.GIF_MAX_GRAY/max(gifImages(:));
level = level*obj.GIF_MAX_GRAY/max(gifImages(:));
gifImages = gifImages*obj.GIF_MAX_GRAY/max(gifImages(:));
gifImages = (obj.GIF_MAX_GRAY/window)*(gifImages - level + window/2);
gifImages(gifImages < 0) = 0;
gifImages(gifImages > obj.GIF_MAX_GRAY) = obj.GIF_MAX_GRAY;

% Aspect ratio
aspectRatio = (params.fov(1)/params.fov(2)); %*(params.dimX/params.dimY);

% Correct for non-square aspect ratio
gifImageSize = params.gifOversampleFactor*dimx; % size of longest axis
dimy = gifImageSize;
dimx = round(dimy * aspectRatio);
if obj.phaseOrientation
    dimx = gifImageSize;
    dimy = round(dimx * aspectRatio);
end
fct = max([dimx dimy]);
numRows = round(gifImageSize * dimx / fct);
numCols = round(gifImageSize * dimy / fct);

% Export the gif images
try

    for i=1:dimd % loop over all repetitions

        for z=1:dimz    % loop over all slices

            for j=1:NFA      % loop over all flip angles

                cine = false;
                if (obj.frameLoopOn == 1)
                    cine = true;
                end

                if cine

                    % File name
                    fname = strcat(folderName,filesep,'movie_d',num2str(i),'_s',num2str(z),'_fa',num2str(j),'.gif');

                    % Delay time
                    delayTime = 1/NE;

                    for k=1:NE      % loop over all echo times (cine loop)

                        % The image
                        im = rot90(uint8(round(imresize(squeeze(gifImages(:,:,z,i,j,k)),[numRows numCols]))));

                        % Write the gif file
                        if k==1
                            imwrite(im, fname,'DelayTime',delayTime,'LoopCount',inf);
                        else
                            imwrite(im, fname,'DelayTime',delayTime,'WriteMode','append','DelayTime',delayTime);
                        end

                    end

                else

                    % Delay time
                    delayTime = 1/dimd;

                    for k=1:NE      % loop over all echo times, multi-echo

                        % File name
                        fname = strcat(folderName,filesep,'image_s',num2str(z),'_fa',num2str(j),'_te',num2str(k),'.gif');

                        % The image
                        im = rot90(uint8(round(imresize(squeeze(gifImages(:,:,z,i,j,k)),[numRows numCols]))));

                        % Write the gif file
                        if i==1
                            imwrite(im, fname,'DelayTime',delayTime,'LoopCount',inf);
                        else
                            imwrite(im, fname,'DelayTime',delayTime,'WriteMode','append','DelayTime',delayTime);
                        end

                    end

                end

            end

        end

    end

    reporter.message("GIF export completed ...", 1);

catch ME
    reporter.message("ERROR: GIF export failed ...", 1);
    reporter.message(ME.message, 2);
end


end
