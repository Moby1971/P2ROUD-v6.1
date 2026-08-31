function params = defaultRecoParams()

% The reconstruction parameter struct, with defaults
%
%   params = proud.defaultRecoParams()
%
%   params   struct with every field the reconstruction reads, set to its
%            default value
%
% This is the single definition of what a reconstruction needs to
% know. gatherRecoParams(app) fills the same struct from the GUI;
% a script fills it by hand:
%
%   params = proud.defaultRecoParams();
%   params.dimX = 256; params.dimY = 256; params.dimZ = 256;
%   pd = pd.Reco3DZTE(params);
%
% Keep the two files in step: a field added here must be gathered there.
% tests/tRecoParams.m checks that in both directions.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026
%

% Compute backend ---------------------------------------------------------
params.bartDetected  = false;       % BART available
params.gpuPresent    = false;       % BART compiled with GPU support
params.csReco        = false;       % compressed sensing rather than gridding/NUFFT

% Requested output matrix -------------------------------------------------
params.dimX          = 128;
params.dimY          = 128;
params.dimZ          = 128;
params.dim3          = 1;           % third dimension for 2D multi-slab data
params.dim3Limits    = [1 1];       % third dimension selector limits
params.nrDynamics    = 1;           % NREditField, the requested number of dynamics
params.slabOverlap   = 0;

% Gradient delays, in samples ---------------------------------------------
% [Gx Gy Gz Sxy Sxz Syz], the six terms of the symmetric delay matrix S.
params.delays        = zeros(1,6);
params.dataOffset    = 0;           % junk samples at the start of the readout
params.gradDelayCalibration = false;
params.ringMethod    = false;

% Radial / UTE / ZTE corrections ------------------------------------------
params.centerEcho    = false;
params.phaseCorrect  = false;
params.amplitudeCorrect = false;
params.tukeyFilter   = false;
params.densityCorrect = false;
params.trajectory    = '';          % TrajectoryViewField

% CS regularization -------------------------------------------------------
params.wvxyz         = 0;           % wavelet, spatial
params.tvxyz         = 0;           % total variation, spatial
params.llrxyz        = 0;           % locally low rank, spatial
params.tvtime        = 0;           % total variation, dynamics
params.zteIterations = 1;
params.zteDeadTime   = 14;          % ZTE receiver dead time, us
params.zteDeadTimeCalibration = 0;  % calibrate the dead time on the image
params.zteCalibrationSpokes = 1000; % spokes used for the dead time calibration

% Coils and denoising -----------------------------------------------------
params.autoSensitivity = false;
params.pcaDenoise    = false;
params.pcaDenoiseWindow = 0;
params.bmdDenoise    = false;
params.deRing        = false;

% Averaging and inclusion -------------------------------------------------
params.sumTypeNr     = '';
params.sumTypeNe     = '';
params.includeNr     = 0;
params.includeNe     = 0;

% Geometry and sequence, as displayed -------------------------------------
params.fov           = [0 0 0];     % FOVViewField1..3
params.kMatrix       = [0 0 0];     % KMatrixViewField1..3
params.fillingPercentage = 0;      % k-space filling percentage, as displayed
params.orientation   = 0;
params.TE            = 0;
params.TR            = 0;
params.flipAngle     = 0;
params.nrFlipAngles  = 1;
params.nrEchoes      = 1;
params.nrAverages    = 1;
params.scanTime      = 0;
params.timeDyn       = 0;
params.sequence      = '';
params.mrdFile       = '';

% Display windowing, used by the GIF export ------------------------------
params.window        = 0;           % display window
params.level         = 0;           % display level

% Export destinations ----------------------------------------------------
params.dicomExportPath = '';        % where DICOM and NIfTI exports are written
params.gifExportPath   = '';        % where GIF exports are written

% Tunable reconstruction settings ------------------------------------------
%
% These mirror the "reconstruction" and "site" blocks of the settings JSON, and
% default to the compiled-in values in proud.Constants so there is one
% definition. gatherRecoParams overlays the user's settings file on top; a test
% checks the JSON defaults and these agree.
params.sdcNumThreads        = proud.Constants.SDC_NUM_THREADS;
params.sdcIterInitial       = proud.Constants.SDC_ITER_INITIAL;
params.sdcIterFinal         = proud.Constants.SDC_ITER_FINAL;
params.sdcOsfInitial        = proud.Constants.SDC_OSF_INITIAL;
params.sdcOsfFinal          = proud.Constants.SDC_OSF_FINAL;
params.csInnerIterations    = proud.Constants.CS_INNER_ITERATIONS;
params.csOuterIterations2D  = proud.Constants.CS_OUTER_ITERATIONS_2D;
params.csOuterIterations3D  = proud.Constants.CS_OUTER_ITERATIONS_3D;
params.csNoiseScale         = proud.Constants.CS_NOISE_SCALE;
params.nufftMaxIterations   = proud.Constants.NUFFT_MAX_ITERATIONS;
params.nufftTikhonovPenalty = proud.Constants.NUFFT_TIKHONOV_PENALTY;
params.llrBlockDivisor      = proud.Constants.LLR_BLOCK_DIVISOR;
params.llrBlockMin          = proud.Constants.LLR_BLOCK_MIN;
params.llrRankWeight2D      = proud.Constants.LLR_RANK_WEIGHT_2D;
params.llrRankWeight3D      = proud.Constants.LLR_RANK_WEIGHT_3D;
params.minCalibSize         = proud.Constants.MIN_CALIB_SIZE;
params.maxGradDelay         = proud.Constants.MAX_GRAD_DELAY;
params.tukeyFilterWidth     = 0.1;
params.coilSensitivityCalibSize = 8;
params.slabRatio            = 80;
params.defaultPatientWeight = proud.Constants.DEFAULT_PATIENT_WEIGHT;
params.maxDirAttempts       = proud.Constants.MAX_DIR_ATTEMPTS;
params.gifOversampleFactor  = proud.Constants.GIF_OVERSAMPLE_FACTOR;

% Bookkeeping -------------------------------------------------------------
params.tag           = '';
params.appVersion    = '';
params.mrdImportPath = '';
params.rtableFile    = '';          % scanner k-space reordering table, if one is used

end % defaultRecoParams
