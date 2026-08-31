classdef ConsoleReporter < proud.Reporter

    % proud.ConsoleReporter — a proud.Reporter for running the reconstruction without a
    % GUI: from a script, over a folder of scans, or in a test.
    %
    %   pd = proudData(proud.ConsoleReporter());
    %
    % Messages go to the command window, filtered by MessageLevel in the
    % same way app.TextMessage filters on the MessageLevelSpinner. Progress
    % is printed as a percentage, but only when it changes by at least
    % ProgressStep percent, so a long reconstruction does not scroll the
    % window away.
    %
    % Abort always returns false: there is no button to press. A script that
    % wants to interrupt the reconstruction can subclass this and override
    % aborted, for example to watch for a sentinel file.
    %
    % Gustav Strijkers
    % g.j.strijkers@amsterdamumc.nl
    % August 2026


    properties
        MessageLevel double = 1         % show messages with level <= this
        ProgressStep double = 5         % minimum percent change worth printing
        Quiet logical = false           % suppress everything
    end

    properties (Access = private)
        Total double = 0
        Counter double = 0
        LastShown double = -Inf
    end


    methods

        function obj = proud.ConsoleReporter(messageLevel)

            if nargin > 0
                obj.MessageLevel = messageLevel;
            end

        end % ConsoleReporter


        function message(obj, txt, level)

            if nargin < 3
                level = 1;
            end
            if obj.Quiet || level > obj.MessageLevel
                return;
            end

            txt = string(txt);
            txt = strjoin(txt, " ");
            if ~endsWith(txt, "...")
                txt = txt + " ...";
            end
            fprintf('%s\n', txt);

        end % message


        function status(obj, code)

            if obj.Quiet
                return;
            end

            switch code
                case 1
                    fprintf('[status] warning\n');
                case 2
                    fprintf('[status] error\n');
                case 3
                    fprintf('[status] busy\n');
                otherwise
                    % 0 = OK, not worth a line of its own
            end

        end % status


        function setTotal(obj, total)

            obj.Total = total;
            obj.LastShown = -Inf;

        end % setTotal


        function resetProgress(obj)

            obj.Counter = 0;
            obj.LastShown = -Inf;

        end % resetProgress


        function advance(obj, n)

            if nargin < 2
                n = 1;
            end
            obj.Counter = obj.Counter + n;

        end % advance


        function showProgress(obj, percent)

            if nargin < 2
                if obj.Total > 0
                    percent = round(100*obj.Counter/obj.Total);
                else
                    percent = 0;
                end
            end
            percent = max(0, min(100, percent));

            if obj.Quiet
                return;
            end

            % Only print when it has moved far enough to be worth a line
            if percent >= obj.LastShown + obj.ProgressStep || percent >= 100
                fprintf('  progress %3d%%\n', percent);
                obj.LastShown = percent;
            end

        end % showProgress

    end % methods

end % ConsoleReporter
