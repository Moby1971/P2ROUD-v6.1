classdef tReporter < matlab.unittest.TestCase
    % The proud.Reporter interface
    %
    % proud.Reporter is the only channel through which the class talks to the outside
    % world, so its contract is worth pinning down. The source-level checks at
    % the end exist because a mistake here is invisible until the exact path
    % that uses it runs: the calibration used to do
    %
    %     obj.reporter.aborted('gradcal') = false;
    %
    % which is an assignment to the result of a method and errors at runtime,
    % but only once a gradient delay calibration is actually started.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
    end

    methods (Test)

        function baseReporterIsSilentAndSafe(tc)
            r = proud.Reporter();
            tc.verifyWarningFree(@() r.message('hello', 1));
            tc.verifyWarningFree(@() r.status(0));
            tc.verifyWarningFree(@() r.setTotal(10));
            tc.verifyWarningFree(@() r.resetProgress());
            tc.verifyWarningFree(@() r.advance(1));
            tc.verifyWarningFree(@() r.showProgress(50));
            tc.verifyWarningFree(@() r.showImage(zeros(4)));
            tc.verifyWarningFree(@() r.setAborted('gradcal', true));
            tc.verifyFalse(r.aborted());
            tc.verifyFalse(r.aborted('gradcal'));
        end

        function consoleReporterImplementsTheSameInterface(tc)
            % A subclass must be substitutable for the base class
            missing = tReporter.missingInterface('proud.ConsoleReporter');
            tc.verifyEmpty(missing, sprintf( ...
                'ConsoleReporter is missing: %s', strjoin(missing, ', ')));
        end

        function appReporterImplementsTheSameInterface(tc)
            missing = tReporter.missingInterface('AppReporter');
            tc.verifyEmpty(missing, sprintf( ...
                'AppReporter is missing: %s', strjoin(missing, ', ')));
        end

        function abortFlagRoundTrips(tc)
            % setAborted must be readable back through aborted, per kind
            r = tReporter.stubReporter();
            tc.verifyFalse(r.aborted('gradcal'));
            r.setAborted('gradcal', true);
            tc.verifyTrue(r.aborted('gradcal'));
            tc.verifyFalse(r.aborted('reco'), 'the two kinds must be independent');
            r.setAborted('gradcal', false);
            tc.verifyFalse(r.aborted('gradcal'));
        end

        function reporterIsAHandleClass(tc)
            % A long job clears the abort flag on a reporter it was handed. If
            % proud.Reporter were a value class that write would be silently lost.
            tc.verifyTrue(isa(proud.Reporter(), 'handle'));
        end

        % -----------------------------------------------------------------
        % Source-level checks on how the class uses the reporter
        % -----------------------------------------------------------------

        function classOnlyCallsMethodsThatExist(tc)
            src = sourceFiles();
            tc.assumeNotEmpty(src, 'sources not present');

            used = {};
            for k = 1:numel(src)
                txt = regexprep(fileread(src{k}), '^\s*%[^\n]*$', '', 'lineanchors');
                tok = regexp(txt, 'reporter\.([A-Za-z]\w*)', 'tokens');
                used = [used, cellfun(@(c) c{1}, tok, 'UniformOutput', false)]; %#ok<AGROW>
            end
            used = unique(used);

            unknown = setdiff(used, methods('proud.Reporter'));
            tc.verifyEmpty(unknown, sprintf( ...
                'reporter methods called that do not exist: %s', ...
                strjoin(unknown, ', ')));
        end

        function classNeverAssignsToAReporterMethod(tc)
            % obj.reporter.aborted(...) = x parses but fails at runtime, and only
            % on the path that runs it. Catch it statically instead.
            src = sourceFiles();
            tc.assumeNotEmpty(src, 'sources not present');

            bad = strings(0,1);
            for k = 1:numel(src)
                lines = splitlines(string(fileread(src{k})));
                lines = lines(~startsWith(strip(lines), "%"));
                hit = lines(~cellfun(@isempty, ...
                    regexp(cellstr(lines), 'reporter\.[A-Za-z]\w*\s*(\([^)]*\))?\s*=[^=]', 'once')));
                bad = [bad; hit]; %#ok<AGROW>
            end
            tc.verifyEmpty(bad, sprintf( ...
                'assignment to a reporter method: %s', strjoin(cellstr(bad), ' | ')));
        end

    end

    methods (Static)

        function missing = missingInterface(subclass)
            % Interface methods of proud.Reporter that a subclass does not provide.
            % Constructors are excluded: methods() lists the class name itself.
            % methods() lists the constructor under the class's SHORT name, so
            % strip that rather than the package-qualified one
            short = @(n) extractAfter(n, max([0, strfind(n,'.')]));
            base = setdiff(methods('proud.Reporter'), {'Reporter'});
            sub  = setdiff(methods(subclass), {char(short(subclass))});
            missing = setdiff(base, sub);
        end

        function r = stubReporter()
            % A minimal reporter that actually stores the abort flags, standing
            % in for the app without needing one
            r = StubReporter();
        end

    end

end
