function s = defaultCsSettings()

% The CS regularisation values the GUI starts from, per data type
%
%   s = proud.defaultCsSettings()
%
%   s   struct of regularisation weights, one field per data type
%
% Settings rather than constants: a starting point the user is expected to
% change, and different sites reconstruct different subjects.
%
% This function is the single definition. makeDefaultSettings writes it into the
% csDefaults block of defaultP2ROUDSettings.json, and the app reads it from the
% user's settings file, falling back here when that block or a key is absent.
%
% llrxyzGpu is applied instead of llrxyz when a GPU is present; it replaces an
% "if app.GPUpresentFlag" inside each of the five blocks.
%
% Keys are the app's dataType values, with the dots and digits MATLAB will not
% accept in a field name removed: 3Dute -> ute3D, 2Dradial -> radial2D.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    s.ute3D       = block(0.01,  0, 0, 0,      0,    30);
    s.cartesian3D = block(0.01,  0, 0, 0.005,  0.05, []);
    s.cartesian2D = block(0.001, 0, 0, 0.0005, 0,    []);
    s.radial2D    = block(0.01,  0, 0, 0.005,  0,    30);
    s.zte         = block(0.01,  0, 0, 0.005,  0,    30);

end % defaultCsSettings


function b = block(wvxyz, tvxyz, llrxyz, llrxyzGpu, tvtime, zteIterations)

    b.wvxyz     = wvxyz;
    b.tvxyz     = tvxyz;
    b.llrxyz    = llrxyz;
    b.llrxyzGpu = llrxyzGpu;
    b.tvtime    = tvtime;

    % Only the paths that run ZTE-style iterations carry this
    if ~isempty(zteIterations)
        b.zteIterations = zteIterations;
    end

end % block
