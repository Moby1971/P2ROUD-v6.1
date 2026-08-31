function folderName = exportDicomDCM(obj, params, reporter, dcmdir)

% Export the reconstructed images as DICOM, reusing an existing DICOM header
%
%   folderName = proud.io.exportDicomDCM(obj, params, reporter, dcmdir)
%
%   obj          proudData holding the images to export
%   params       reconstruction parameters, for the export path and labels
%   reporter     proud.Reporter; omit or pass empty to run silent
%   dcmdir       folder of DICOM files from the scanner, used as the header
%                template so patient and study identity are carried over
%   folderName   folder the DICOM files were written to, '' if none were
%
% The scanner's own DICOM files supply the header, and only the fields that the
% reconstruction changes -- geometry, sizes, series description and the UIDs
% that must be unique per series -- are overwritten. Use proud.io.exportDicomMRD
% instead when there is no DICOM directory and the header has to be built from
% the MRD parameters alone.
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
    reporter.message("ERROR: no image data available for DICOM export ...", 1);
    return
end

% Check that DICOM source folder exists
if isempty(dcmdir) || ~exist(dcmdir, 'dir')
    reporter.message("ERROR: DICOM source folder not found ...", 1);
    return
end

directory = params.dicomExportPath;
image = obj.images;

% Phase orientation
if obj.phaseOrientation == 1
    reporter.message('INFO: phase orientation = 1');
    image = permute(rot90(permute(image,[2 1 3 4 5 6]),1),[2 1 3 4 5 6]);
end

% size of the data
dimX = size(image,1);
dimY = size(image,2);
dimZ = size(image,3);
dimD = size(image,4);
dimFA = size(image,5);
dimE = size(image,6);
threeDdata = contains(lower(obj.dataType),lower(["3D","3Dp2roud","3Dute","ZTE"]));
seriesInstanceID = dicomuid;

% Reading in the DICOM header information
listing = dir(fullfile(dcmdir, '*.dcm'));
try
    dcmFilename = [listing(1).folder,filesep,listing(1).name];
    baseHeader = dicominfo(dcmFilename);
    reporter.message(strcat('Reading DICOM info from',{' '},dcmFilename));
catch ME
    reporter.message("ERROR: could not read DICOM header ...", 1);
    reporter.message(ME.message, 2);
    return
end

% Spatial z positions for 3D data
if threeDdata
    try
        [~,spatial,~] = dicomreadVolume(listing(1).folder);
        spatialPos = unique(spatial.PatientPositions,'rows');

        dimzOrg = size(spatialPos,1);
        dimzRange = 1:(dimzOrg-1)/(dimZ-1):dimzOrg;

        v1 = interp1(spatialPos(:,1),dimzRange);
        v2 = interp1(spatialPos(:,2),dimzRange);
        v3 = interp1(spatialPos(:,3),dimzRange);

        spatialPositions = [v1',v2',v3'];
    catch ME
        reporter.message("ERROR: could not read 3D spatial positions ...", 1);
        reporter.message(ME.message, 2);
        return
    end
end

if baseHeader.SeriesNumber == 0
    baseHeader.SeriesNumber = str2double(strrep(params.tag,'_',''));
    reporter.message("WARNING: Missing Dicom SeriesNumber ...",2);
end

if isempty(baseHeader.SOPClassUID)
    baseHeader.SOPClassUID = obj.DICOM_SOP_CLASS_UID_MR;
    reporter.message("WARNING: Missing Dicom SOPClassUID ...",2);
end

% Create new directory
maxAttempts = params.maxDirAttempts;
ready = false;
cnt = 1;
while ~ready && cnt <= maxAttempts
    folderName = strcat(directory,filesep,"DICOM",filesep,num2str(baseHeader.SeriesNumber),'P',filesep,num2str(cnt),filesep);
    if ~exist(folderName, 'dir')
        try
            mkdir(folderName);
            ready = true;
        catch ME
            reporter.message("ERROR: could not create DICOM export folder ...", 1);
            reporter.message(ME.message, 2);
            folderName = '';
            return
        end
    end
    cnt = cnt + 1;
end

if ~ready
    reporter.message("ERROR: could not find a free DICOM export folder ...", 1);
    folderName = '';
    return
end

reporter.message(strcat("DICOM export folder = ", folderName));

% export the dicom images
try

    fileCounter = 0;
    reporter.showProgress(0);
    totalNumberofImages = dimD*dimFA*dimE*dimZ;

    for dynamic = 1:dimD                    % loop over all repetitions

        for flipAngle = 1:dimFA             % loop over all flip angles

            for echo = 1:dimE               % loop over all echo times

                for slice = 1:dimZ          % loop over all slices

                    % Counter
                    fileCounter = fileCounter + 1;

                    % Read dicom header
                    if ~threeDdata
                        loc = dimZ+1-slice;
                        dcmFilename = strcat(listing(loc).folder,filesep,listing(loc).name);
                        baseHeader = dicominfo(dcmFilename);
                    end

                    % File name
                    fn = sprintf('%06d', fileCounter);
                    fname = strcat(folderName,filesep,fn,'.dcm');

                    % Generate dicom header
                    dcmHeader = generateDicomheaderDCM(baseHeader,fname,fileCounter,dynamic,flipAngle,echo,slice);

                    % The image
                    im = rot90(squeeze(cast(round(image(:,:,slice,dynamic,flipAngle,echo)),'uint16')));

                    % Write the dicom file
                    dicomwrite(im, fname, dcmHeader);

                    % Update progress bar
                    reporter.showProgress(round(100*fileCounter/totalNumberofImages));
                    drawnow;

                end

            end

        end

    end

    reporter.message("DICOM export completed ...", 1);

catch ME
    reporter.message("ERROR: DICOM export failed ...", 1);
    reporter.message(ME.message, 2);
end





% ----------------------
% --- FUNCTIONS --------
% ----------------------

    function dicomHeader = generateDicomheaderDCM(dcmHead,fname,~,dynamic,flipAngle,echo,slice)

        % GENERATES DICOM HEADER FOR EXPORT
        %
        % dcmHead = dicom info from scanner generated dicom

        frametime = obj.MS_PER_SECOND*obj.acqdur/dimD;    % time between frames in ms

        if obj.phaseOrientation == 1
            pixely = params.fov(1)/dimY;
            pixelx = params.fov(2)/dimX;
        else
            pixely = params.fov(2)/dimY;
            pixelx = params.fov(1)/dimX;
        end

        sliceSep = obj.sliceSeparation + obj.sliceThickness;

        dcmHead.RepetitionTime = obj.TR;
        dcmHead.Filename = fname;
        dcmHead.FileModDate = obj.date;
        dcmHead.FileSize = dimY*dimX*2;
        dcmHead.Width = dimY;
        dcmHead.Height = dimX;
        dcmHead.BitDepth = obj.DICOM_BITS_STORED;
        dcmHead.InstitutionName = 'Amsterdam UMC';
        dcmHead.ReferringPhysicianName.FamilyName = 'AMC preclinical MRI';
        dcmHead.InstitutionalDepartmentName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PhysicianOfRecord.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PerformingPhysicianName.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PhysicianReadingStudy.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.OperatorName.FamilyName = 'manager';
        dcmHead.ManufacturerModelName = 'MRS7024';
        dcmHead.ReferencedFrameNumber = [];
        dcmHead.NumberOfAverages = obj.noAverages;
        dcmHead.InversionTime = 0;
        dcmHead.ImagedNucleus = '1H';
        dcmHead.MagneticFieldStrength = obj.fieldStrength;
        dcmHead.TriggerTime = (dynamic-1)*frametime;    % frame time (ms)
        dcmHead.AcquisitionMatrix = uint16([dimX 0 0 dimY])';
        dcmHead.AcquisitionDeviceProcessingDescription = '';
        dcmHead.AcquisitionDuration = obj.acqdur;

        % dcmHead.InstanceNumber = fileCounter;
        dcmHead.InstanceNumber = (dynamic-1)*dimZ*dimE + (echo-1)*dimZ + slice;     % instance number

        dcmHead.TemporalPositionIdentifier = dynamic;

        dcmHead.NumberOfTemporalPositions = dimD*dimE;

        dcmHead.ImagesInAcquisition = dimD*dimZ*dimE;

        % dcmHead.TemporalPositionIndex = dynamic;
        dcmHead.TemporalPositionIndex = (dynamic-1)*dimE + echo;

        dcmHead.Rows = dimY;
        dcmHead.Columns = dimX;
        dcmHead.PixelSpacing = [pixely pixelx]';
        dcmHead.PixelAspectRatio = [1 pixely/pixelx]';
        dcmHead.BitsAllocated = obj.DICOM_BITS_ALLOCATED;
        dcmHead.BitsStored = obj.DICOM_BITS_STORED;
        dcmHead.HighBit = obj.DICOM_HIGH_BIT;
        dcmHead.PixelRepresentation = 0;
        dcmHead.PixelPaddingValue = 0;
        dcmHead.RescaleIntercept = 0;
        dcmHead.RescaleSlope = 1;
        dcmHead.NumberOfSlices = dimZ;

        dcmHead.SliceThickness = obj.sliceThickness;
        if threeDdata
            dcmHead.SpacingBetweenSlices = obj.sliceThickness;
        else
            dcmHead.SpacingBetweenSlices = sliceSep/obj.sliceInterleave;
        end

        dcmHead.EchoTrainLength = obj.noEchoes;
        dcmHead.EchoTime = obj.TE*echo;                         % ECHO TIME
        dcmHead.FlipAngle = obj.flipAngleArray(flipAngle);           % FLIP ANGLES

        if threeDdata

            dcmHead.ImagePositionPatient(1) = spatialPositions(slice,1);
            dcmHead.ImagePositionPatient(2) = spatialPositions(slice,2);
            dcmHead.ImagePositionPatient(3) = spatialPositions(slice,3);

        else

           startslice = 0;
           if isfield(dcmHead, 'SliceLocation')
               startslice = dcmHead.SliceLocation;
           end
           dcmHead.SliceLocation = startslice+(slice-1)*(sliceSep/obj.sliceInterleave);

        end

        dcmHead.SeriesInstanceUID = seriesInstanceID;

        dicomHeader = dcmHead;

    end % Generate dicom header


    

% ---- END OF FUNCTIONS ------


end % exportDicomDCM
