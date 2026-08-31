classdef StubReporter < proud.Reporter
    % A proud.Reporter that stores what it is told, for tests
    %
    % The base proud.Reporter is silent and AppReporter needs a live app, so neither
    % can show that setAborted and aborted agree. This one can.

    properties
        StopReco (1,1) logical = false
        StopGradCal (1,1) logical = false
        Messages cell = {}
    end

    methods

        function message(obj, txt, ~)
            obj.Messages{end+1} = char(txt);
        end

        function tf = aborted(obj, kind)
            if nargin < 2; kind = 'reco'; end
            switch kind
                case 'gradcal'; tf = obj.StopGradCal;
                otherwise;      tf = obj.StopReco;
            end
        end

        function setAborted(obj, kind, tf)
            if nargin < 3; tf = true; end
            if nargin < 2; kind = 'reco'; end
            switch kind
                case 'gradcal'; obj.StopGradCal = tf;
                otherwise;      obj.StopReco = tf;
            end
        end

    end

end
