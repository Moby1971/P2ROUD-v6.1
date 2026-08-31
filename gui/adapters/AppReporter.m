classdef AppReporter < proud.Reporter

    % AppReporter — a proud.Reporter that forwards to the P2ROUD app.
    %
    % It deliberately touches exactly the same app members the
    % reconstruction code used to touch itself, in the same way, so that
    % swapping the direct calls for this class does not change what the GUI
    % does:
    %
    %   message      -> app.TextMessage(txt, level)
    %   status       -> app.SetStatus(code)
    %   setTotal     -> app.totalCounter
    %   resetProgress/advance -> app.progressCounter
    %   showProgress -> app.RecoProgressGauge.Value  (or ExportProgressGauge)
    %   aborted      -> app.stopRecoFlag / app.stopGradCalFlag
    %
    % The counters stay on the app because other app code reads them.
    %
    % Usage, from the app:
    %
    %   app.pd = proudData(AppReporter(app));
    %
    % Gustav Strijkers
    % g.j.strijkers@amsterdamumc.nl
    % August 2026


    properties (Access = private)
        App                             % handle to the P2ROUD app
        Gauge char = 'reco'             % which progress gauge, 'reco' or 'export'
    end


    methods

        function obj = AppReporter(app, gauge)

            obj.App = app;
            if nargin > 1
                obj.Gauge = gauge;
            end

        end % AppReporter


        function message(obj, txt, level)

            if nargin < 3
                obj.App.TextMessage(txt);
            else
                obj.App.TextMessage(txt, level);
            end

        end % message


        function status(obj, code)

            obj.App.SetStatus(code);

        end % status


        function setTotal(obj, total)

            obj.App.totalCounter = total;

        end % setTotal


        function resetProgress(obj)

            obj.App.progressCounter = 0;

        end % resetProgress


        function advance(obj, n)

            if nargin < 2
                n = 1;
            end
            obj.App.progressCounter = obj.App.progressCounter + n;

        end % advance


        function showProgress(obj, percent)

            if nargin < 2
                % The former inline expression, with a guard against a total
                % of zero, which would have put NaN or Inf into the gauge
                if obj.App.totalCounter > 0
                    percent = round(100*obj.App.progressCounter/obj.App.totalCounter);
                else
                    percent = 0;
                end
            end

            percent = max(0, min(100, percent));

            switch obj.Gauge
                case 'export'
                    obj.App.ExportProgressGauge.Value = percent;
                otherwise
                    obj.App.RecoProgressGauge.Value = percent;
            end

        end % showProgress


        function showImage(obj, img)

            % The four calls the reconstruction used to make on app.RecoFig itself
            ax = obj.App.RecoFig;
            xlim(ax, [0 size(img,2)+1]);
            ylim(ax, [0 size(img,1)+1]);
            daspect(ax, [1 1 1]);
            imshow(img, [], 'Parent', ax);

        end % showImage


        function tf = aborted(obj, kind)

            if nargin < 2
                kind = 'reco';
            end

            switch kind
                case 'gradcal'
                    tf = obj.App.stopGradCalFlag;
                otherwise
                    tf = obj.App.stopRecoFlag;
            end

        end % aborted


        % ---------------------------------------------------------------------------------
        % Set or clear the abort flag -> app.stopGradCalFlag / app.stopRecoFlag
        % ---------------------------------------------------------------------------------
        function setAborted(obj, kind, tf)

            if nargin < 3
                tf = true;
            end
            if nargin < 2
                kind = 'reco';
            end

            switch kind
                case 'gradcal'
                    obj.App.stopGradCalFlag = tf;
                otherwise
                    obj.App.stopRecoFlag = tf;
            end

        end % setAborted

    end % methods

end % AppReporter
