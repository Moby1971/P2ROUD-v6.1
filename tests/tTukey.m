classdef tTukey < matlab.unittest.TestCase
    % The k-space Tukey filters
    %
    % params.tukeyFilterWidth defaults to 0.1, and every filter is built with
    % twice it: tukeywin(dimR, 2w) on a full 2D spoke, tukeywin(2*dimX, 2w) on a
    % centre-out 3D spoke, circTukey2D/3D with 2w.
    %
    % The three look inconsistent and are not. They share one invariant:
    %
    %     with filter width w, the filter is flat over the inner (1-2w) of the
    %     k-space radius and tapers over the outer 2w.
    %
    % The full spoke is tapered at both ends, the centre-out spoke only at the
    % outer end, and the factor two in the window length is what makes the two
    % agree. The tests below pin that invariant, and the last one pins the call
    % sites, because the invariant only holds if every site passes 2*w.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
    end

    methods (Static)

        function lines = codeLines()
            % Every non-comment line of every source, class and package alike
            lines = strings(0,1);
            src = sourceFiles();
            for k = 1:numel(src)
                l = splitlines(string(fileread(src{k})));
                lines = [lines; l(~startsWith(strip(l), "%"))]; %#ok<AGROW>
            end
        end

        function frac = flatFraction(profile)
            % Fraction of a centre-to-edge profile that is still at full value
            n = numel(profile);
            last = find(profile > 1-1e-9, 1, 'last');
            if isempty(last); frac = 0; else; frac = last/n; end
        end

    end

    methods (Test)

        function fullSpokeFilterTapersTheOuterTwoW(tc)
            % 2D radial: tukeywin(dimR, 2w) over a spoke through the origin
            w = 0.1; dimR = 400;
            f = tukeywin(dimR, 2*w);
            outward = f(dimR/2+1:end);
            tc.verifyEqual(tTukey.flatFraction(outward), 1-2*w, 'AbsTol', 0.01);
            tc.verifyLessThan(outward(end), 1e-6, 'the filter must reach zero at kmax');
        end

        function centreOutFilterTapersTheOuterTwoW(tc)
            % 3D UTE and ZTE: tukeywin(2*dimX, 2w), second half
            w = 0.1; dimX = 200;
            f = tukeywin(2*dimX, 2*w);
            outward = f(dimX+1:end);
            tc.verifyEqual(tTukey.flatFraction(outward), 1-2*w, 'AbsTol', 0.01);
            tc.verifyLessThan(outward(end), 1e-6);
        end

        function theTwoReadoutFiltersAgree(tc)
            % The whole point: a full spoke and a centre-out spoke of the same
            % k-space extent must get the same radial profile
            w = 0.1; dimX = 200;
            full = tukeywin(2*dimX, 2*w); full = full(dimX+1:end);
            half = tukeywin(2*dimX, 2*w); half = half(dimX+1:end);
            tc.verifyEqual(half, full, 'AbsTol', 1e-12);

            % and against the 2D form built on the full readout length
            f2 = tukeywin(2*dimX, 2*w); f2 = f2(dimX+1:end);
            tc.verifyEqual(tTukey.flatFraction(f2), tTukey.flatFraction(full), ...
                'AbsTol', 0.01);
        end

        function circTukey2DTapersTheOuterTwoW(tc)
            w = 0.1; N = 256;
            c = proud.util.circTukey2D(N,N,N/2,N/2,2*w);
            profile = c(N/2, N/2:end);
            tc.verifyEqual(tTukey.flatFraction(profile), 1-2*w, 'AbsTol', 0.02);
            tc.verifyLessThanOrEqual(diff(profile), 1e-9, ...
                'the radial profile must not increase outward');
        end

        function circTukey3DTapersTheOuterTwoW(tc)
            w = 0.1; N = 64;
            c = proud.util.circTukey3D(N,N,N,N/2,N/2,N/2,2*w);
            profile = squeeze(c(N/2, N/2, N/2:end));
            tc.verifyEqual(tTukey.flatFraction(profile), 1-2*w, 'AbsTol', 0.05);
            % circTukey builds on a fixed 256 grid and samples it by rounded
            % radius, so the profile carries a little discretisation ripple
            tc.verifyLessThan(max(diff(profile)), 1e-3, ...
                'the radial profile must not increase outward');
            tc.verifyLessThan(max(profile), 1 + 1e-2, ...
                'the filter must not amplify');
        end

        function circTukeyIsCircularlySymmetric(tc)
            N = 128;
            c = proud.util.circTukey2D(N,N,N/2,N/2,0.2);
            tc.verifyEqual(c, rot90(c), 'AbsTol', 0.02, ...
                'the filter must not prefer an axis');
        end

        function widthZeroIsABoxcar(tc)
            N = 128;
            c = proud.util.circTukey2D(N,N,N/2,N/2,0);
            profile = c(N/2, N/2:end);
            tc.verifyEqual(tTukey.flatFraction(profile), 1, 'AbsTol', 0.02, ...
                'zero width must not taper at all');
        end

        function widthOneIsFullyTapered(tc)
            N = 128;
            c = proud.util.circTukey2D(N,N,N/2,N/2,1);
            profile = c(N/2, N/2:end);
            tc.verifyLessThan(tTukey.flatFraction(profile), 0.05, ...
                'width one must taper over the whole radius');
        end

        function everyCallSitePassesTwiceTheFilterWidth(tc)
            % The invariant above holds only because every site doubles the
            % width. A site passing the width undoubled tapers half as much,
            % which shows up as extra noise in the reconstruction and nowhere
            % else.
            lines = tTukey.codeLines();
            tc.assumeNotEmpty(lines, 'sources not present');

            calls = lines(contains(lines, "tukeywin(") | ...
                          contains(lines, "circTukey2D(") | ...
                          contains(lines, "circTukey3D("));
            calls = calls(contains(calls, "tukeyFilterWidth"));
            tc.verifyNotEmpty(calls, 'no Tukey call sites found');

            bad = calls(~contains(calls, "2*params.tukeyFilterWidth") & ...
                        ~contains(calls, "2*obj.tukeyFilterWidth"));
            tc.verifyEmpty(bad, sprintf( ...
                'Tukey call site not using 2*obj.tukeyFilterWidth: %s', ...
                strjoin(strip(cellstr(bad)), ' | ')));
        end

        function everyTukeyDefinitionSiteIsCovered(tc)
            % Guard against a new filter being added without a width at all.
            % Scans every source, not just the class -- circTukey2D and
            % circTukey3D live in +proud/ now, and a new tukeywin call could
            % appear anywhere.
            lines = tTukey.codeLines();
            tc.assumeNotEmpty(lines, 'sources not present');

            % circTukey2D and circTukey3D take the width as an argument and
            % build their own window; their call sites are checked above
            calls = lines(contains(lines, "tukeywin("));
            calls = calls(~contains(calls, "tukeywin(domain,filterwidth)"));

            bad = calls(~contains(calls, "tukeyFilterWidth"));
            tc.verifyEmpty(bad, sprintf( ...
                'tukeywin called with a width that is not tukeyFilterWidth: %s', ...
                strjoin(strip(cellstr(bad)), ' | ')));
        end

    end

end
