function folderName = exportDicomMRD(obj, params, reporter, tag)

% Export the reconstructed images as DICOM, building the header from scratch
%
%   folderName = proud.io.exportDicomMRD(obj, params, reporter, tag)
%
%   obj          proudData holding the images to export
%   params       reconstruction parameters, for the export path and labels
%   reporter     proud.Reporter; omit or pass empty to run silent
%   tag          text appended to the series description, to tell exports of
%                the same scan apart
%   folderName   folder the DICOM files were written to, '' if none were
%
% The header is built from the MRD parameters, for data that never had DICOM
% files of its own. proud.io.exportDicomDCM is the counterpart for when the
% scanner's DICOM directory is available and should be used as the template.
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

directory = strcat(params.dicomExportPath,filesep,"DICOM",filesep);
image = obj.images;

% dimensions extracted after phase orientation on line 62

% Create new directory
maxAttempts = params.maxDirAttempts;
ready = false;
cnt = 1;
while ~ready && cnt <= maxAttempts
    folderName = strcat(directory,filesep,tag,'P',filesep,num2str(cnt),filesep);
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

% Phase orientation
if obj.phaseOrientation == 1
    reporter.message('INFO: phase orientation = 1');
    image = permute(rot90(permute(image,[2 1 3 4 5 6]),1),[2 1 3 4 5 6]);
end

[dimx,dimy,dimz,NR,NFA,NE] = size(image);

% Export the dicom images
dcmid = dicomuid;   % unique identifier
dcmid = dcmid(1:obj.DICOM_UID_MAX_LENGTH);
seriesInstanceID = dicomuid;

try

    fileCounter = 0;
    reporter.showProgress(0);
    totalNumberofImages = NR*NFA*NE*dimz;

    for dynamic = 1:NR      % loop over all repetitions

        for flipAngle = 1:NFA     % loop over all flip angles

            for echo = 1:NE      % loop over all echo times

                for slice = 1:dimz        % loop over all slices

                    % Counter
                    fileCounter = fileCounter + 1;

                    % File name
                    fn = sprintf('%06d', fileCounter);
                    fname = strcat(folderName,filesep,fn,'.dcm');

                    % Dicom header
                    dcmHeader = generateDicomheaderMRD(fname,fileCounter,dynamic,flipAngle,echo,slice);

                    % The image
                    image1 = rot90(squeeze(cast(round(image(:,:,slice,dynamic,flipAngle,echo)),'uint16')));

                    % Write the dicom file
                    dicomwrite(image1, fname, dcmHeader);

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



reporter.showProgress(100);



% ---------------------
% ---- functions ------
% ---------------------

    function dicomHeader = generateDicomheaderMRD(fname,~,dynamic,flipAngle,echo,slice)

        % GENERATES DICOM HEADER FOR EXPORT

        acq_dur = obj.nrFrames * obj.timeperframe;   % acquisition time in seconds

        if obj.phaseOrientation == 1
            pixelx = obj.aspectratio*obj.FOV/dimx;
            pixely = obj.FOV/dimy;
        else
            pixelx = obj.FOV/dimx;
            pixely = obj.aspectratio*obj.FOV/dimy;
        end

        dt = datetime(obj.date,'InputFormat','dd-MMM-yyyy HH:mm:ss');
        year = num2str(dt.Year);
        month = ['0',num2str(dt.Month)]; month = month(end-1:end);
        day = ['0',num2str(dt.Day)]; day = day(end-1:end);
        date = [year,month,day];

        hour = ['0',num2str(dt.Hour)]; hour = hour(end-1:end);
        minute = ['0',num2str(dt.Minute)]; minute = minute(end-1:end);
        seconds = ['0',num2str(dt.Second)]; seconds = seconds(end-1:end);
        time = [hour,minute,seconds];

        threeDdata = contains(lower(obj.dataType),lower(["3D","3Dp2roud","3Dute","ZTE"]));
        %sliceSep = obj.sliceSeparation + obj.sliceThickness;

        dcmHead.Filename = fname;
        dcmHead.FileModDate = obj.date;
        dcmHead.FileSize = dimy*dimz*2;
        dcmHead.Format = 'DICOM';
        dcmHead.FormatVersion = 3;
        dcmHead.Width = dimx;
        dcmHead.Height = dimy;
        dcmHead.BitDepth = obj.DICOM_BITS_STORED;
        dcmHead.ColorType = 'grayscale';
        dcmHead.FileMetaInformationGroupLength = obj.DICOM_META_GROUP_LENGTH;
        dcmHead.FileMetaInformationVersion = uint8([0, 1])';
        dcmHead.MediaStorageSOPClassUID = obj.DICOM_SOP_CLASS_UID_MR;
        dcmHead.TransferSyntaxUID = obj.DICOM_TRANSFER_SYNTAX_UID;
        dcmHead.ImplementationClassUID = obj.DICOM_IMPL_CLASS_UID;
        dcmHead.ImplementationVersionName = 'OFFIS_DCMTK_360';
        dcmHead.SpecificCharacterSet = 'ISO_IR 100';
        dcmHead.ImageType = 'DERIVED\4D-MRI\';
        dcmHead.SOPClassUID = obj.DICOM_SOP_CLASS_UID_MR;
        dcmHead.StudyDate = date;
        dcmHead.SeriesDate = date;
        dcmHead.AcquisitionDate = date;
        dcmHead.StudyTime = time;
        dcmHead.SeriesTime = time;
        dcmHead.AcquisitionTime = obj.MS_PER_SECOND*(dynamic-1)*obj.timeperframe;
        dcmHead.ContentTime = time;
        dcmHead.Modality = 'MR';
        dcmHead.Manufacturer = 'MR Solutions Ltd';
        dcmHead.InstitutionName = 'Amsterdam UMC';
        dcmHead.InstitutionAddress = 'Amsterdam, Netherlands';
        dcmHead.ReferringPhysicianName.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.ReferringPhysicianName.GivenName = '';
        dcmHead.ReferringPhysicianName.MiddleName = '';
        dcmHead.ReferringPhysicianName.NamePrefix = '';
        dcmHead.ReferringPhysicianName.NameSuffix = '';
        dcmHead.StationName = 'MRI Scanner';
        dcmHead.StudyDescription = 'PROUD-data';
        dcmHead.InstitutionalDepartmentName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PhysicianOfRecord.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PhysicianOfRecord.GivenName = '';
        dcmHead.PhysicianOfRecord.MiddleName = '';
        dcmHead.PhysicianOfRecord.NamePrefix = '';
        dcmHead.PhysicianOfRecord.NameSuffix = '';
        dcmHead.PerformingPhysicianName.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PerformingPhysicianName.GivenName = '';
        dcmHead.PerformingPhysicianName.MiddleName = '';
        dcmHead.PerformingPhysicianName.NamePrefix = '';
        dcmHead.PerformingPhysicianName.NameSuffix = '';
        dcmHead.PhysicianReadingStudy.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PhysicianReadingStudy.GivenName = '';
        dcmHead.PhysicianReadingStudy.MiddleName = '';
        dcmHead.PhysicianReadingStudy.NamePrefix = '';
        dcmHead.PhysicianReadingStudy.NameSuffix = '';
        dcmHead.OperatorName.FamilyName = 'manager';
        dcmHead.AdmittingDiagnosesDescription = '';
        dcmHead.ManufacturerModelName = 'MRS7024';
        dcmHead.ReferencedSOPClassUID = '';
        dcmHead.ReferencedSOPInstanceUID = '';
        dcmHead.ReferencedFrameNumber = [];
        dcmHead.DerivationDescription = '';
        dcmHead.FrameType = '';
        dcmHead.PatientName.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.PatientID = '01';
        dcmHead.PatientBirthDate = date;
        dcmHead.PatientBirthTime = '';
        dcmHead.PatientSex = 'F';
        dcmHead.OtherPatientID = '';
        dcmHead.OtherPatientName.FamilyName = 'Amsterdam UMC preclinical MRI';
        dcmHead.OtherPatientName.GivenName = '';
        dcmHead.OtherPatientName.MiddleName = '';
        dcmHead.OtherPatientName.NamePrefix = '';
        dcmHead.OtherPatientName.NameSuffix = '';
        dcmHead.PatientAge = '1';
        dcmHead.PatientSize = [];
        dcmHead.PatientWeight = params.defaultPatientWeight;
        dcmHead.Occupation = '';
        dcmHead.AdditionalPatientHistory = '';
        dcmHead.PatientComments = '';
        dcmHead.BodyPartExamined = '';
        dcmHead.SequenceName = char(obj.PPL);
        dcmHead.SliceThickness = obj.sliceThickness;
        if threeDdata
            dcmHead.SpacingBetweenSlices = obj.sliceThickness;
        else
            dcmHead.SpacingBetweenSlices = obj.sliceSeparation;
        end

        dcmHead.KVP = 0;
        dcmHead.RepetitionTime = obj.TR;
        dcmHead.EchoTime = obj.TE*echo;                 % ECHO TIME
        dcmHead.InversionTime = 0;
        dcmHead.NumberOfAverages = obj.noAverages;
        dcmHead.ImagedNucleus = '1H';
        dcmHead.MagneticFieldStrength = obj.fieldStrength;
        dcmHead.EchoTrainLength = obj.noEchoes;
        dcmHead.DeviceSerialNumber = '0034';
        dcmHead.PlateID = '';
        dcmHead.SoftwareVersion = '1.0.0.0';
        dcmHead.ProtocolName = '';
        dcmHead.SpatialResolution = [];
        dcmHead.TriggerTime = obj.MS_PER_SECOND*(dynamic-1)*obj.timeperframe;  % trigger time in ms
        dcmHead.DistanceSourceToDetector = [];
        dcmHead.DistanceSourceToPatient = [];
        dcmHead.FieldofViewDimensions = [obj.FOV obj.aspectratio*obj.FOV obj.sliceThickness];
        dcmHead.ExposureTime = [];
        dcmHead.XrayTubeCurrent = [];
        dcmHead.Exposure = [];
        dcmHead.ExposureInuAs = [];
        dcmHead.FilterType = '';
        dcmHead.GeneratorPower = [];
        dcmHead.CollimatorGridName = '';
        dcmHead.FocalSpot = [];
        dcmHead.DateOfLastCalibration = '';
        dcmHead.TimeOfLastCalibration = '';
        dcmHead.PlateType = '';
        dcmHead.PhosphorType = '';
        dcmHead.AcquisitionMatrix = uint16([dimx 0 0 dimy])';
        dcmHead.FlipAngle = obj.flipAngleArray(flipAngle);           % FLIP ANGLES
        dcmHead.AcquisitionDeviceProcessingDescription = '';
        dcmHead.CassetteOrientation = 'PORTRAIT';
        dcmHead.CassetteSize = '25CMX25CM';
        dcmHead.ExposuresOnPlate = 0;
        dcmHead.RelativeXrayExposure = [];
        dcmHead.AcquisitionComments = '';
        dcmHead.PatientPosition = 'HFS';
        dcmHead.Sensitivity = [];
        dcmHead.FieldOfViewOrigin = [];
        dcmHead.FieldOfViewRotation = [];
        dcmHead.AcquisitionDuration = acq_dur;
        dcmHead.StudyInstanceUID = dcmid(1:obj.DICOM_STUDY_UID_LENGTH);
        dcmHead.StudyID = '01';
        dcmHead.SeriesNumber = obj.filename;
        dcmHead.AcquisitionNumber = 1;

        dcmHead.InstanceNumber = (dynamic-1)*dimz*NE + (echo-1)*dimz + slice;     % instance number
        dcmHead.NumberOfTemporalPositions = NR*NE;
        dcmHead.TemporalPositionIndex = (dynamic-1)*NE + echo;
        dcmHead.TemporalPositionIdentifier = (dynamic-1)*NE + echo;

        dcmHead.ImagePositionPatient = [-obj.FOV/2 -(obj.aspectratio*obj.FOV/2) (slice-round(obj.noSlicesDcm/2))*dcmHead.SpacingBetweenSlices]';
        dcmHead.ImageOrientationPatient = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]';
        dcmHead.FrameOfReferenceUID = '';

        dcmHead.TemporalResolution = obj.timeperframe;
        dcmHead.ImagesInAcquisition = obj.noSlicesDcm;
        dcmHead.SliceLocation = (slice-round(obj.noSlicesDcm/2))*dcmHead.SpacingBetweenSlices;
        dcmHead.ImageComments = '';
        dcmHead.SamplesPerPixel = 1;
        dcmHead.PhotometricInterpretation = 'MONOCHROME2';
        dcmHead.PlanarConfiguration = 0;
        dcmHead.Rows = dimy;
        dcmHead.Columns = dimx;
        dcmHead.PixelSpacing = [pixely pixelx]';
        dcmHead.PixelAspectRatio = obj.aspectratio;
        dcmHead.BitsAllocated = obj.DICOM_BITS_ALLOCATED;
        dcmHead.BitsStored = obj.DICOM_BITS_STORED;
        dcmHead.HighBit = obj.DICOM_HIGH_BIT;
        dcmHead.PixelRepresentation = 0;
        dcmHead.PixelPaddingValue = 0;
        dcmHead.RescaleIntercept = 0;
        dcmHead.RescaleSlope = 1;
        dcmHead.HeartRate = 0;
        dcmHead.NumberOfSlices = obj.noSlicesDcm;
        dcmHead.CardiacNumberOfImages = 1;
        dcmHead.MRAcquisitionType = convertStringsToChars(obj.dataType);
        dcmHead.BodyPartExamined = '';

        dcmHead.SeriesDescription = params.mrdFile;
        dcmHead.SeriesInstanceUID = seriesInstanceID;
        dcmHead.SequenceVariant = 'NONE';
        dcmHead.ScanOptions = 'CG';
        dcmHead.ProtocolName = convertStringsToChars(strcat("TR",num2str(dcmHead.RepetitionTime),"_TE",num2str(dcmHead.EchoTime)));

        dicomHeader = dcmHead;

    end % Generate dicom header


   



% ---------- END OF FUNCTIONS ----------------

end % exportDicomMRD
