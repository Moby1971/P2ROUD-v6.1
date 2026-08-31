classdef tWindowLevel < matlab.unittest.TestCase
    % Display window and level
    %
    % Two small algorithms that were inline in the app's SetImageWLFcn and
    % SetKspaceWLFcn. They are worth having out here not because they are long
    % but because their edge cases -- a blank slice, a constant image, a single
    % bright pixel -- are exactly where a display scaling goes wrong, and while
    % they lived in a GUI callback nothing could reach them to check.

    methods (Test)

        function levelIsTheForegroundMean(tc)
            % A bright square on a dark background: the level should be the mean
            % of the square, not of the whole image, which background would drag
            % down badly. Here the square IS the maximum, so the window clamps to
            % it rather than reaching 2*level -- see windowIsTwiceTheLevelUnclamped.
            im = zeros(64); im(20:44,20:44) = 800;
            [window, level] = proud.util.imageWindowLevel(im);
            tc.verifyEqual(level, 800, 'RelTol', 0.01, ...
                'level must follow the foreground, not the whole image');
            tc.verifyEqual(window, 800, 'RelTol', 1e-9, ...
                'window must clamp to the maximum present');
        end

        function windowIsTwiceTheLevelOrTheMaximum(tc)
            % The specification, over a range of images rather than one contrived
            % case: window = min(2*level, maxScale).
            %
            % Worth knowing: the clamp bites on nearly every real image. Otsu's
            % threshold tends to land above the bulk of the foreground, so the
            % mean of what is left sits close to the maximum and 2*level
            % overshoots. The doubling is real but rarely visible.
            rng(11);
            cases = { zeros(64) + 100, ...
                      [zeros(32,64); 500*ones(32,64)], ...
                      abs(randn(48)*300), ...
                      reshape(linspace(0,1000,64*64),64,64) };
            for k = 1:numel(cases)
                im = cases{k};
                [window, level] = proud.util.imageWindowLevel(im);
                maxScale = double(round(max(im(:))));
                tc.verifyEqual(window, min(2*level, maxScale), 'RelTol', 1e-9, ...
                    sprintf('case %d violates window = min(2*level, maxScale)', k));
                tc.verifyLessThanOrEqual(level, maxScale);
            end
        end

        function windowNeverExceedsWhatTheDataHas(tc)
            % window is 2*level, but must clamp: asking for more range than the
            % image contains just darkens it
            im = zeros(32); im(10:20,10:20) = 100;
            [window, ~] = proud.util.imageWindowLevel(im);
            tc.verifyLessThanOrEqual(window, double(round(max(im(:)))));
        end

        function blankImageGivesNoNaN(tc)
            % mean(nonzeros(...)) of nothing is NaN; a NaN reaching a slider
            % throws deep inside the GUI, a long way from the cause
            [window, level] = proud.util.imageWindowLevel(zeros(16));
            tc.verifyFalse(any(isnan([window level])));
            tc.verifyEqual([window level], [0 0]);
        end

        function constantImageIsHandled(tc)
            [window, level] = proud.util.imageWindowLevel(500*ones(16));
            tc.verifyFalse(any(isnan([window level])));
            tc.verifyLessThanOrEqual(window, 500);
        end

        function kspaceScalesToTheMaximumPresent(tc)
            im = abs(randn(32)*100);
            [window, level] = proud.util.kspaceWindowLevel(im, false);
            tc.verifyEqual(window, double(round(0.8*max(im(:)))), 'AbsTol', 1e-9);
            tc.verifyEqual(level, double(round(0.4*window)), 'AbsTol', 1e-9);
        end

        function sensitivityMapsScaleByTheKspaceRange(tc)
            % sensitivity values are relative, around 1, so they scale by the
            % constant rather than by their own maximum
            im = ones(8);
            [window, level] = proud.util.kspaceWindowLevel(im, true);
            tc.verifyEqual(window, double(proud.Constants.MAX_KSPACE), 'AbsTol', 1e-9);
            tc.verifyEqual(level, double(round(0.75*proud.Constants.MAX_KSPACE)), 'AbsTol', 1e-9);
        end

        function allZeroKspaceUsesTheFullRange(tc)
            [window, level] = proud.util.kspaceWindowLevel(zeros(8), false);
            tc.verifyEqual(window, proud.Constants.MAX_KSPACE);
            tc.verifyEqual(level, 0.5*proud.Constants.MAX_KSPACE);
        end

        function senseMapFlagDefaultsToFalse(tc)
            im = abs(randn(16)*10);
            [w1, l1] = proud.util.kspaceWindowLevel(im);
            [w2, l2] = proud.util.kspaceWindowLevel(im, false);
            tc.verifyEqual([w1 l1], [w2 l2]);
        end

    end

end
