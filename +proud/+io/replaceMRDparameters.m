function par = replaceMRDparameters(obj, params)

% MRD parameter struct describing the reconstructed data
%
%   par = proud.io.replaceMRDparameters(obj, params)
%
%   obj      proudData holding the reconstructed k-space in obj.mrdKspace
%   params   reconstruction parameters, for averages and similar counts
%   par      parameter struct to write into the exported MRD file
%
% Exporting to MRD writes the reconstructed data back out, and its dimensions
% and sampling no longer match the parameters that came in with the scan. This
% builds the parameter set that describes what is actually being written: the
% sizes are taken from obj.mrdKspace, and the flags for the sampling schemes
% the reconstruction has already undone -- centric ordering, navigators, radial
% -- are cleared, so the file reads back as plain Cartesian data.
%
% Flip angles are folded into the experiment count, because MRD has no separate
% dimension for them.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    [par.NoSamples,par.NoViews,par.NoViews2,par.NoSlices,par.NoEchoes,par.NoExperiments,par.NoFlipAngles] = size(obj.mrdKspace);
    if par.NoFlipAngles > 1
        par.NoExperiments = par.NoExperiments * par.NoFlipAngles;
    end
    par.peorder = 0;
    par.pe2_centric_on = 0;
    par.slice_nav = 0;
    par.ext_nav_on = 0;
    par.ext_nav_fid_on = 0;
    par.ext_nav_echo_on = 0;
    par.navon = 0;
    par.radialon = 0;
    par.NoAverages = params.nrAverages;
    par.batchslices = 1;
    par.frameloopon = 0;
    par.viewspersegment = 1;
    par.nodiscard = 0;
    par.View1order = "SEQUENTIAL";
    par.View2order = "SEQUENTIAL";
    par.reconmethod = "FFT";
    if obj.frameLoopOn == 1
        par.frameloopon = 1;
    end
    par.tr = floor(params.TR);
    par.tr_extra_us = (obj.TR - par.tr)*1000;
    par.te = floor(params.TE);
    if obj.frameLoopOn == 1
        par.te = 0;  % set to zero, because no_echoes dimension is used for (cardiac) frames
    end
    par.te_us = (obj.TE - par.te)*1000;
    par.SLICE_THICKNESS = params.fov(3);
    par.channelCount = 1;
    par.channelWeights = 1;
    par.PPL = "p2roudReco";
    par.alt_dir = """""";

end % replaceMRDparameters
