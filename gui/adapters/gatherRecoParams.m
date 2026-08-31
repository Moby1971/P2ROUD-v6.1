function params = gatherRecoParams(app)

% ---------------------------------------------------------------
%   params = gatherRecoParams(app)
%
%   app      the running P2ROUD app, read but never modified
%   params   the reconstruction parameter struct, every field of
%            proud.defaultRecoParams filled from the widgets and the
%            user's settings file
%
% Read the GUI once and return a plain reconstruction parameter
% struct. This is the ONLY place the reconstruction learns what
% the user asked for.
%
%   params = gatherRecoParams(app);
%   app.pd = app.pd.Reco3DZTE(params);
%
% This is the only place that reads the widgets, so a field renamed in App
% Designer breaks here and nowhere else, and the reconstruction stays runnable
% from a script.
%
% The field list is defined by proud.defaultRecoParams(); this function fills
% it in from the widgets and the user's settings file. Keep the two in step --
% tests/tRecoParams.m checks that in both directions.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026
% ---------------------------------------------------------------

params = proud.defaultRecoParams();

% Compute backend
params.bartDetected  = app.bartDetectedFlag;
params.gpuPresent    = app.GPUpresentFlag;
params.csReco        = app.CSRecoCheckBox.Value;

% Requested output matrix
params.dimX          = app.XEditField.Value;
params.dimY          = app.YEditField.Value;
params.dimZ          = app.ZEditField.Value;
params.dim3          = app.Dim3EditField.Value;
params.dim3Limits    = app.Dim3EditField.Limits;
params.nrDynamics    = app.NREditField.Value;
params.slabOverlap   = app.SlabOverlapEditField.Value;

% Gradient delays: [Gx Gy Gz Sxy Sxz Syz]
params.delays        = [app.GxDelayEditField.Value,  app.GyDelayEditField.Value,  app.GzDelayEditField.Value, ...
                        app.SxyDelayEditField.Value, app.SxzDelayEditField.Value, app.SyzDelayEditField.Value];
params.dataOffset    = app.DataOffsetRadialEditField.Value;
params.gradDelayCalibration = app.GradDelayCalibrationCheckBox.Value;
params.ringMethod    = app.RingMethodCheckBox.Value;

% Radial / UTE / ZTE corrections
params.centerEcho       = app.CenterEchoCheckBox.Value;
params.phaseCorrect     = app.PhaseCorrectCheckBox.Value;
params.amplitudeCorrect = app.AmplitudeCorrectionCheckBox.Value;
params.tukeyFilter      = app.TukeyFilterCheckBox.Value;
params.densityCorrect   = app.DensityCorrectCheckBox.Value;
params.trajectory       = app.TrajectoryViewField.Value;

% CS regularization
params.wvxyz         = app.WVxyzEditField.Value;
params.tvxyz         = app.TVxyzEditField.Value;
params.llrxyz        = app.LLRxyzEditField.Value;
params.tvtime        = app.TVtimeEditField.Value;
params.zteIterations = app.ZTEIterationsEditField.Value;
params.zteDeadTime   = app.ZTEDeadTimeEditField.Value;
params.zteDeadTimeCalibration = app.ZTEDeadTimeCalibrationCheckBox.Value;

% Coils and denoising
params.autoSensitivity   = app.AutoSensitivityCheckBox.Value;
params.pcaDenoise        = app.PCAdeNoiseCheckBox.Value;
params.pcaDenoiseWindow  = app.PCAdeNoiseWindowEditField.Value;
params.bmdDenoise        = app.BMDdeNoiseCheckBox.Value;
params.deRing            = app.DeRingCheckBox.Value;

% Averaging and inclusion
params.sumTypeNr     = app.SumTypeNrDropDown.Value;
params.sumTypeNe     = app.SumTypeNeDropDown.Value;
params.includeNr     = app.IncludeNrEditField.Value;
params.includeNe     = app.IncludeNeEditField.Value;

% Geometry and sequence, as displayed
params.fov           = [app.FOVViewField1.Value, app.FOVViewField2.Value, app.FOVViewField3.Value];
params.kMatrix       = [app.KMatrixViewField1.Value, app.KMatrixViewField2.Value, app.KMatrixViewField3.Value];
params.fillingPercentage = app.FillingViewField.Value;
params.orientation   = app.OrientationSpinner.Value;
params.TE            = app.TEViewField.Value;
params.TR            = app.TRViewField.Value;
params.flipAngle     = app.FAViewField.Value;
params.nrFlipAngles  = app.NFAViewField.Value;
params.nrEchoes      = app.NEViewField.Value;
params.nrAverages    = app.NAViewField.Value;
params.scanTime      = app.ScanTimeViewField.Value;
params.timeDyn       = app.TimeDynViewField.Value;
params.sequence      = app.SequenceViewField.Value;
params.mrdFile       = app.MRDfileViewField.Value;

% Display windowing, used by the GIF export
params.window        = app.WindowEditField.Value;
params.level         = app.LevelEditField.Value;

% Export destinations
params.dicomExportPath = app.dicomExportPath;
params.gifExportPath   = app.gifExportPath;

% Tunable reconstruction settings, from the user's settings file
%
% Start from the compiled-in defaults, then overlay whatever the user's JSON
% carries. readSettingsFile has already merged and validated it, so every field
% below is present and of the right type; this only has to copy across.
params = applySettings(params, app);

% Bookkeeping
params.tag           = app.tag;
params.appVersion    = app.appVersion;
params.mrdImportPath = app.mrdImportPath;
params.rtableFile    = app.rtableFile;

end % gatherRecoParams


% ---------------------------------------------------------------------------------
% Overlay the settings file onto the parameter struct
% ---------------------------------------------------------------------------------
function params = applySettings(params, app)

    if ~isprop(app,'jsonPar') || isempty(app.jsonPar)
        return
    end

    if isfield(app.jsonPar,'reconstruction')
        params = copyFields(params, app.jsonPar.reconstruction);
    end

    if isfield(app.jsonPar,'site')
        params = copyFields(params, app.jsonPar.site);
    end

end % applySettings


function params = copyFields(params, src)

    f = fieldnames(src);
    for k = 1:numel(f)
        % Only fields the parameter struct already declares: a stray key in
        % someone's settings file must not invent a parameter
        if isfield(params, f{k})
            params.(f{k}) = src.(f{k});
        end
    end

end % copyFields
