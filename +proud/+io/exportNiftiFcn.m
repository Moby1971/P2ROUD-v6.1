function niftiExportPath = exportNiftiFcn(obj, params, reporter)

% Export the reconstructed images as NIfTI files
%
%   niftiExportPath = proud.io.exportNiftiFcn(obj, params, reporter)
%
%   obj              proudData holding the images to export
%   params           reconstruction parameters, for the export path and the
%                    orientation and voxel size written into the header
%   reporter         proud.Reporter; omit or pass empty to run silent
%   niftiExportPath  folder the files were written to, '' if nothing was
%
% The geometry in the NIfTI header comes from the scan parameters, so the
% images land in the right orientation in a viewer rather than needing to be
% flipped by hand afterwards.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

% Without a reporter this function is silent, so it runs headless
if nargin < 3 || isempty(reporter)
    reporter = proud.Reporter();
end

niftiExportPath = '';

% Get parameters from the app
tag = params.tag;
exportFolder = params.dicomExportPath;
dicomFolder = obj.exportPath;

% Check that DICOM source folder exists and contains files
if isempty(dicomFolder) || ~exist(dicomFolder, 'dir')
    reporter.message("ERROR: DICOM source folder not found ...", 1);
    return
end

dcmFiles = dir(fullfile(dicomFolder, '*.dcm'));
if isempty(dcmFiles)
    reporter.message("ERROR: no DICOM files found in source folder ...", 1);
    return
end

% Create new directory
maxAttempts = params.maxDirAttempts;
ready = false;
cnt = 1;
while ~ready && cnt <= maxAttempts
    niftiExportPath = strcat(exportFolder, filesep, "Nifti", filesep, tag, "P", filesep, num2str(cnt), filesep);
    if ~exist(niftiExportPath, 'dir')
        try
            mkdir(niftiExportPath);
            ready = true;
        catch ME
            reporter.message("ERROR: could not create NIfTI export folder ...", 1);
            reporter.message(ME.message, 2);
            niftiExportPath = '';
            return
        end
    end
    cnt = cnt + 1;
end

if ~ready
    reporter.message("ERROR: could not find a free NIfTI export folder ...", 1);
    niftiExportPath = '';
    return
end

% Export NIfTI
reporter.message(strcat("NIfTI export folder = ", niftiExportPath));
try
    dicm2nii(dicomFolder, niftiExportPath, 0);
    reporter.message("NIfTI export completed ...", 1);
catch ME
    reporter.message("ERROR: NIfTI export failed ...", 1);
    reporter.message(ME.message, 2);
end

end
