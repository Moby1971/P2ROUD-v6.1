classdef tPfiles < matlab.unittest.TestCase
    % P-files must not shadow newer sources
    %
    % MATLAB prefers a .p over the .m beside it. This project ships .p files and
    % gitignores the .m, so an edited source is INVISIBLE until it is re-pcoded:
    % the app keeps running the old compiled version, silently, and every test
    % that exercises it passes against stale code.
    %
    % The failure mode is silent: the app and the tests both keep running, and
    % they run the compiled version, so an edit appears to have no effect and
    % nothing reports an error. Comparing timestamps is the only cheap way to
    % catch it.
    %
    % Skipped when the .m sources are absent, which is a released P-coded copy.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
    end

    methods (Test)

        function noPfileIsOlderThanItsSource(tc)
            d = dir(fullfile(tc.Root, '**', '*.p'));
            if ~isempty(d)
                d = d(~contains({d.folder}, [filesep 'backup']));
            end
            % No P-files at all is a pass, not a skip: nothing can be shadowed

            stale = {};
            for k = 1:numel(d)
                pFile = fullfile(d(k).folder, d(k).name);
                mFile = [pFile(1:end-2) '.m'];
                if ~isfile(mFile)
                    continue    % shipped without its source, which is the point of P-code
                end
                mInfo = dir(mFile);
                if mInfo.datenum > d(k).datenum
                    stale{end+1} = strrep(mFile, [tc.Root filesep], ''); %#ok<AGROW>
                end
            end

            tc.verifyEmpty(stale, sprintf(['these sources are newer than the ' ...
                'P-files shadowing them, so MATLAB is running the old code -- ' ...
                'regenerate with pcode: %s'], strjoin(stale, ', ')));
        end

    end

end
