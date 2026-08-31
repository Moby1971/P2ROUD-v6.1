classdef tRecoParams < matlab.unittest.TestCase
    % The parameter-struct contract between the app and the class
    %
    % The class takes its settings as a plain struct and reports its results in
    % properties, so it runs headless. Two things have to stay true for that to
    % hold, and both are easy to break by editing one file and not the other:
    %
    %   * every params field the class reads must be defined by
    %     proud.defaultRecoParams (or a script run fails) and produced by
    %     gatherRecoParams (or a GUI run fails);
    %   * the output properties the app mirrors must all exist.
    %
    % These are source-level checks. They are skipped when proudData.m is not
    % present, which is the case in a P-coded release.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
    end

    methods (Static)

        function names = paramFieldsIn(files)
            % Every distinct params.<field> read across the given sources
            if ischar(files) || isstring(files); files = cellstr(files); end
            names = {};
            for k = 1:numel(files)
                tok = regexp(fileread(files{k}), 'params\.([A-Za-z]\w*)', 'tokens');
                names = [names, cellfun(@(c) c{1}, tok, 'UniformOutput', false)]; %#ok<AGROW>
            end
            names = unique(names);
        end

        function f = gatherFile()
            % Located by name, not by folder: gatherRecoParams has already moved
            % once (functions/params -> functions/appAdapters) and a hardcoded
            % path turns these tests into silent skips rather than failures.
            root = fileparts(fileparts(mfilename('fullpath')));
            d = dir(fullfile(root, '**', 'gatherRecoParams.m'));
            if isempty(d); f = ''; else; f = fullfile(d(1).folder, d(1).name); end
        end

        function names = settingsFields()
            % Fields gatherRecoParams fills from the settings JSON rather than
            % by a literal assignment, so a source scan cannot see them. The
            % JSON is the definition, so read it.
            f = which('defaultP2ROUDSettings.json');
            if isempty(f); names = {}; return; end
            j = jsondecode(fileread(f));
            names = {};
            for blk = ["reconstruction","site"]
                if isfield(j, blk)
                    names = [names; fieldnames(j.(blk))]; %#ok<AGROW>
                end
            end
            names = names(:)';
        end

        function names = paramFieldsAssignedIn(file)
            % Every distinct params.<field> assigned in a source file
            txt = fileread(file);
            tok = regexp(txt, 'params\.([A-Za-z]\w*)\s*=', 'tokens');
            names = unique(cellfun(@(c) c{1}, tok, 'UniformOutput', false));
        end

    end

    methods (Test)

        function sourceScanCoversClassAndPackage(tc)
            % The source-level tests are only worth anything if they look at all
            % the sources. When 29 statics moved into +proud they silently fell
            % out of that scan until this was noticed; this test makes the same
            % mistake fail loudly next time.
            src = sourceFiles();
            tc.assumeNotEmpty(src, 'sources not present');
            tc.verifyTrue(any(contains(src, fullfile('@proudData','proudData.m'))), ...
                'the class itself is not scanned');
            tc.verifyGreaterThan(sum(contains(src, [filesep '+proud' filesep])), 20, ...
                'the +proud package is not scanned');
            tc.verifyTrue(any(contains(src, ['+reco' filesep])), ...
                'the +proud subpackages are not scanned');
            tc.verifyTrue(any(contains(src, ['private' filesep])), ...
                'the package private/ folder is not scanned');
            tc.verifyTrue(any(contains(src, 'exportDicomDCM.m')), ...
                'the +proud subpackages are not scanned');
            tc.verifyTrue(any(contains(src, 'AppReporter.m')), ...
                'the app adapters under gui/ are not scanned');
        end

        function defaultsAreAStructWithFields(tc)
            p = proud.defaultRecoParams();
            tc.verifyClass(p, 'struct');
            tc.verifyGreaterThan(numel(fieldnames(p)), 40);
        end

        function delaysHaveSixComponents(tc)
            % [Gx Gy Gz Sxy Sxz Syz]
            p = proud.defaultRecoParams();
            tc.verifySize(p.delays, [1 6]);
            tc.verifyEqual(p.delays, zeros(1,6), ...
                'a fresh parameter set must carry no gradient delays');
        end

        function everyFieldTheClassReadsIsDefaulted(tc)
            % Otherwise a scripted run errors on a missing field
            src = sourceFiles();
            tc.assumeNotEmpty(src, 'sources not present');

            used = tRecoParams.paramFieldsIn(src);
            have = fieldnames(proud.defaultRecoParams());
            missing = setdiff(used, have);
            tc.verifyEmpty(missing, sprintf( ...
                'params fields read but not defined by proud.defaultRecoParams: %s', ...
                strjoin(missing, ', ')));
        end

        function everyFieldTheClassReadsIsGathered(tc)
            % Otherwise a GUI run errors on a missing field
            src = sourceFiles();
            gat = tRecoParams.gatherFile();
            tc.assumeTrue(~isempty(src) && ~isempty(gat), 'sources not present');

            used = tRecoParams.paramFieldsIn(src);
            have = [tRecoParams.paramFieldsAssignedIn(gat), tRecoParams.settingsFields()];
            missing = setdiff(used, have);
            tc.verifyEmpty(missing, sprintf( ...
                'params fields read but not set by gatherRecoParams: %s', ...
                strjoin(missing, ', ')));
        end

        function gatheredAndDefaultedSetsMatch(tc)
            % The two producers must stay in step, in both directions. A field
            % gathered but never defaulted breaks scripts; a field defaulted but
            % never gathered silently does nothing in the GUI.
            gat = tRecoParams.gatherFile();
            tc.assumeNotEmpty(gat, 'gatherRecoParams.m not present');

            gathered = [tRecoParams.paramFieldsAssignedIn(gat), tRecoParams.settingsFields()];
            defaulted = fieldnames(proud.defaultRecoParams());

            tc.verifyEmpty(setdiff(gathered, defaulted), sprintf( ...
                'gathered but not defaulted: %s', ...
                strjoin(setdiff(gathered, defaulted), ', ')));
            tc.verifyEmpty(setdiff(defaulted, gathered), sprintf( ...
                'defaulted but not gathered: %s', ...
                strjoin(setdiff(defaulted, gathered), ', ')));
        end

        function noFieldIsGatheredButUnusedByTheClass(tc)
            % A parameter nothing reads is a lie: a script setting it would have
            % no effect. params.coilSensitivities was removed for exactly this.
            src = sourceFiles();
            gat = tRecoParams.gatherFile();
            tc.assumeTrue(~isempty(src) && ~isempty(gat), 'sources not present');

            dead = setdiff([tRecoParams.paramFieldsAssignedIn(gat), tRecoParams.settingsFields()], ...
                           tRecoParams.paramFieldsIn(src));
            tc.verifyEmpty(dead, sprintf( ...
                'gathered but read nowhere in the class: %s', strjoin(dead, ', ')));
        end

        function settingsJsonMatchesTheCodeDefaults(tc)
            % The settings file ships the same values the code compiles in. If
            % they drift, a user who never edits their settings still gets
            % different behaviour from a script, which is the worst kind of
            % difference to debug.
            f = which('defaultP2ROUDSettings.json');
            tc.assumeNotEmpty(f, 'defaultP2ROUDSettings.json not on the path');

            j = jsondecode(fileread(f));
            p = proud.defaultRecoParams();

            for blk = ["reconstruction","site"]
                tc.assertTrue(isfield(j, blk), "settings JSON has no '" + blk + "' block");
                names = fieldnames(j.(blk));
                for k = 1:numel(names)
                    n = names{k};
                    tc.verifyTrue(isfield(p, n), sprintf( ...
                        'settings key %s.%s names no parameter', blk, n));
                    if isfield(p, n)
                        tc.verifyEqual(j.(blk).(n), p.(n), 'AbsTol', 1e-12, sprintf( ...
                            'settings default %s.%s disagrees with the code default', blk, n));
                    end
                end
            end
        end

        function csDefaultsJsonMatchesTheCodeDefaults(tc)
            % Same contract as the reconstruction block, for the per-data-type
            % CS starting values: defaultCsSettings is the definition,
            % makeDefaultSettings writes it into the JSON, and the app reads the
            % JSON with defaultCsSettings as its fallback. All three must agree.
            f = which('defaultP2ROUDSettings.json');
            tc.assumeNotEmpty(f, 'defaultP2ROUDSettings.json not on the path');
            tc.assumeNotEmpty(which('proud.defaultCsSettings'), 'defaultCsSettings not on the path');

            j = jsondecode(fileread(f));
            tc.assertTrue(isfield(j,'csDefaults'), 'settings JSON has no csDefaults block');

            d = proud.defaultCsSettings();
            keys = fieldnames(d);
            for k = 1:numel(keys)
                tc.verifyTrue(isfield(j.csDefaults, keys{k}), ...
                    sprintf('csDefaults has no entry for %s', keys{k}));
                if isfield(j.csDefaults, keys{k})
                    tc.verifyEqual(j.csDefaults.(keys{k}), d.(keys{k}), 'AbsTol', 1e-12, ...
                        sprintf('csDefaults.%s disagrees with defaultCsSettings', keys{k}));
                end
            end
        end

        function everyCsDefaultSetIsComplete(tc)
            % Every set needs the four the app always reads; zteIterations is
            % optional and only the ZTE-style paths carry it
            tc.assumeNotEmpty(which('proud.defaultCsSettings'), 'defaultCsSettings not on the path');
            d = proud.defaultCsSettings();
            keys = fieldnames(d);
            for k = 1:numel(keys)
                for f = {'wvxyz','tvxyz','llrxyz','llrxyzGpu','tvtime'}
                    tc.verifyTrue(isfield(d.(keys{k}), f{1}), ...
                        sprintf('%s is missing %s', keys{k}, f{1}));
                end
            end
        end

        function outputPropertiesExistWithSaneDefaults(tc)
            % What MirrorRecoOutputsFcn and MirrorDataOutputsFcn copy back
            o = proudData(proud.Reporter());
            tc.verifyEqual(o.dimXOut, 1);
            tc.verifyEqual(o.dimYOut, 1);
            tc.verifyEqual(o.dimZOut, 1);
            tc.verifyEqual(o.nrDynamicsOut, 1);
            tc.verifyEqual(o.dataOffsetOut, 0);
            tc.verifyEqual(o.delaysOut, zeros(1,6));
            tc.verifyEqual(o.slabOverlapOut, 0);
            tc.verifyEqual(o.kMatrixXOut, 1);
        end

        function classIsConstructibleWithoutAReporter(tc)
            % Headless use must not require the caller to build one
            o = proudData();
            tc.verifyClass(o.reporter, 'proud.Reporter');
            tc.verifyWarningFree(@() o.reporter.message('silent', 1));
        end

    end

end
