function results = runTests(varargin)
% Runs the P2ROUD test suite
%
%   runTests              everything
%   runTests('fast')      skip the tests tagged Slow (the iterative
%                         calibrations and the offset search)
%   runTests('Traj')      only tests whose name contains 'Traj'
%
% The suite is self-contained. It builds its own synthetic data, so it needs no
% MRD file, no GUI and no Bart: the tests that reconstruct force
% params.bartDetected = false, both so they run anywhere and so a change in the
% Bart install cannot move the numbers underneath them.
%
% Layout:
%
%   tTrajectory       the two delay models and the conversion between them
%   tRecoParams       the parameter-struct and output-property contract
%   tReporter         the proud.Reporter interface, including source-level checks
%   tGradientDelays   end-to-end delay recovery, 2D and 3D            (Slow)
%   tDataOffset       automatic data offset estimation                (Slow)

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(root, here, genpath(fullfile(root,'functions')), ...
        genpath(fullfile(root,'gui')));   % gui/adapters holds AppReporter and gatherRecoParams

import matlab.unittest.TestSuite
import matlab.unittest.selectors.HasName
import matlab.unittest.selectors.HasTag
import matlab.unittest.constraints.ContainsSubstring

suite = TestSuite.fromFolder(here);

if nargin > 0
    if strcmpi(varargin{1}, 'fast')
        suite = suite.selectIf(~HasTag('Slow'));
    else
        suite = suite.selectIf(HasName(ContainsSubstring(varargin{1})));
    end
end

results = suite.run();

fprintf('\n%d passed, %d failed, %d incomplete, %.1f s\n', ...
    nnz([results.Passed]), nnz([results.Failed]), ...
    nnz([results.Incomplete]), sum([results.Duration]));
end
