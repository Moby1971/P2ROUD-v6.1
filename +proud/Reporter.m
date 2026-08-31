classdef Reporter < handle

    % proud.Reporter — the narrow interface through which the reconstruction code
    % talks to the outside world: log messages, a status icon, a progress
    % gauge, and an abort flag. Nothing else.
    %
    % This class is the *silent* implementation: every method does nothing.
    % It is deliberately concrete rather than abstract, so that
    %
    %   - a proudData object constructed without a reporter still runs, and
    %   - a subclass only has to override the few methods it cares about.
    %
    % Subclasses shipped with P2ROUD:
    %
    %   AppReporter      forwards to the P2ROUD app (the GUI)
    %   proud.ConsoleReporter  prints to the command window, for scripts and tests
    %
    % Keeping this narrow is what lets proudData run without a GUI: under the
    % app it reports through AppReporter, in a script or a test through
    % proud.ConsoleReporter or this silent base class.
    %
    % Gustav Strijkers
    % g.j.strijkers@amsterdamumc.nl
    % August 2026


    methods

        % ---------------------------------------------------------------------------------
        % Log a message
        %   txt    text, char or string
        %   level  message level, 1 = always shown, higher = more verbose.
        %          Optional, defaults to 1, matching app.TextMessage.
        % ---------------------------------------------------------------------------------
        function message(~, ~, ~)
        end


        % ---------------------------------------------------------------------------------
        % Set the status indicator
        %   code   0 = OK, 1 = warning, 2 = error, 3 = busy
        % ---------------------------------------------------------------------------------
        function status(~, ~)
        end


        % ---------------------------------------------------------------------------------
        % Progress reporting.
        %
        % The protocol mirrors what the code did with app.totalCounter and
        % app.progressCounter, one call per former assignment:
        %
        %   setTotal(n)        the job consists of n steps
        %   resetProgress()    counter back to zero
        %   advance(n)         counter = counter + n   (n optional, default 1)
        %   showProgress(p)    display p percent, or, with no argument,
        %                      round(100*counter/total)
        % ---------------------------------------------------------------------------------
        function setTotal(~, ~)
        end

        function resetProgress(~)
        end

        function advance(~, ~)
        end

        function showProgress(~, ~)
        end


        % ---------------------------------------------------------------------------------
        % Show a preview image, e.g. the gradient delay calibration as it iterates.
        %   img   a real image, already oriented the way it should appear
        % A reconstruction that wants to show its progress visually calls this
        % instead of drawing into a GUI axes, so it still runs headless.
        % ---------------------------------------------------------------------------------
        function showImage(~, ~)
        end


        % ---------------------------------------------------------------------------------
        % Has the user asked to stop?
        %   kind   'reco' (default) or 'gradcal'
        % ---------------------------------------------------------------------------------
        function tf = aborted(~, ~)
            tf = false;
        end


        % ---------------------------------------------------------------------------------
        % Set or clear the abort flag.
        %   kind   'reco' or 'gradcal'
        %   tf     true to request a stop, false to clear
        % A long job clears the flag before it starts and sets it when it gives
        % up, so the caller can tell a finished run from an abandoned one.
        % ---------------------------------------------------------------------------------
        function setAborted(~, ~, ~)
        end

    end % methods

end % Reporter
