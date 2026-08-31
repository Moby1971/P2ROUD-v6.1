classdef tOutputMirrors < matlab.unittest.TestCase
    % The output-mirroring invariant
    %
    % The class writes no widgets. It reports results in *Out properties, and the
    % app copies them back with one of two helpers:
    %
    %   MirrorRecoOutputsFcn   after a reconstruction
    %   MirrorDataOutputsFcn   after a load, sort or k-space fill
    %
    % Each helper writes a FIXED set of widgets. So any method whose results one
    % of them mirrors has to leave that whole set consistent -- not just the
    % fields it happens to care about -- or the mirror copies a stale value from
    % a previous run into a widget. The way that is guaranteed is seeding: every
    % such method assigns all the fields in its set from the incoming parameters
    % on entry, before any conditional overwrite.
    %
    % Adding a field to a mirror without adding it to every seed breaks this
    % quietly: no error, just a stale value from a previous dataset appearing in
    % a widget. The two sets overlap but are not the same, so the check is per
    % mirror rather than global.
    %
    % The two sets overlap but differ, so the check is per mirror.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))

        % What MirrorDataOutputsFcn copies
        DataSet = {'dimXOut','dimYOut','dimZOut','nrDynamicsOut', ...
                   'slabOverlapOut','kMatrixXOut','kMatrixYOut','kMatrixZOut', ...
                   'fillingPercentageOut'}

        % The methods it mirrors, by name
        DataMethods = {'setDataParameters','sort3DKspaceMRD','sort3DProudKspaceMRD', ...
                       'sort2DNonRegLUTKspaceMRD','sort3DNonRegLUTKspaceMRD', ...
                       'chopNav','fillKspace','resortKspace'}

        % What MirrorRecoOutputsFcn copies, beyond coilSensitivities
        RecoSet = {'dimXOut','dimYOut','dimZOut','nrDynamicsOut','dataOffsetOut', ...
                   'delaysOut','slabOverlapOut','deadTimeZteOut'}

        RecoMethods = {'csReco2D','fftReco2D','csReco3D','fftReco3D', ...
                       'Reco2DRadialCS','Reco2DRadialNUFFT','Reco3DuteCS', ...
                       'Reco3DuteNUFFT','Reco3DZTE'}
    end

    methods (Static)

        function body = methodBody(src, name)
            L = splitlines(string(fileread(src)));
            i = find(~cellfun(@isempty, regexp(cellstr(L), ...
                sprintf('^\\s*function .*\\<%s\\(obj', name), 'once')), 1);
            if isempty(i); body = ""; return; end
            j = find(strtrim(L) == "end % " + string(name) & (1:numel(L))' > i, 1);
            if isempty(j); j = numel(L); end
            body = strjoin(L(i:j), newline);
        end

    end

    methods (Test)

        function dataMirroredMethodsSeedTheWholeSet(tc)
            src = fullfile(tc.Root, '@proudData', 'proudData.m');
            tc.assumeTrue(isfile(src), 'proudData.m source not present');

            for m = tOutputMirrors.DataMethods
                body = tOutputMirrors.methodBody(src, m{1});
                tc.assertNotEmpty(char(body), sprintf('method %s not found', m{1}));
                missing = {};
                for f = tOutputMirrors.DataSet
                    if isempty(regexp(body, sprintf('obj\\.%s\\s*=\\s*params\\.', f{1}), 'once'))
                        missing{end+1} = f{1}; %#ok<AGROW>
                    end
                end
                tc.verifyEmpty(missing, sprintf( ...
                    '%s writes results MirrorDataOutputsFcn copies but does not seed: %s', ...
                    m{1}, strjoin(missing, ', ')));
            end
        end

        function recoMethodsSeedTheWholeSet(tc)
            src = fullfile(tc.Root, '@proudData', 'proudData.m');
            tc.assumeTrue(isfile(src), 'proudData.m source not present');

            for m = tOutputMirrors.RecoMethods
                body = tOutputMirrors.methodBody(src, m{1});
                tc.assertNotEmpty(char(body), sprintf('method %s not found', m{1}));
                missing = {};
                for f = tOutputMirrors.RecoSet
                    if isempty(regexp(body, sprintf('obj\\.%s\\s*=\\s*params\\.', f{1}), 'once'))
                        missing{end+1} = f{1}; %#ok<AGROW>
                    end
                end
                tc.verifyEmpty(missing, sprintf( ...
                    '%s writes results MirrorRecoOutputsFcn copies but does not seed: %s', ...
                    m{1}, strjoin(missing, ', ')));
            end
        end

        function everyMirroredFieldIsAnActualProperty(tc)
            p = ?proudData;
            names = {p.PropertyList.Name};
            for f = [tOutputMirrors.DataSet, tOutputMirrors.RecoSet]
                tc.verifyTrue(any(strcmp(names, f{1})), ...
                    sprintf('%s is mirrored but is not a proudData property', f{1}));
            end
        end

    end

end
