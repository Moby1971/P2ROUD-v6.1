function files = sourceFiles()
% Every .m source that project code is made of
%
% The source-level tests scan these: the class, the +proud package, the project
% code under functions/, and the app adapters under gui/. It is a function
% rather than a constant so that a file moved between those areas stays in the
% scan; tRecoParams asserts that each area is represented.
%
% The two files that PRODUCE the parameter struct are excluded by name, wherever
% they live: defaultRecoParams and gatherRecoParams. Counting their assignments
% as reads would make every gathered field look used and defeat the dead-field
% test in tRecoParams.
%
% third_party/ and tools/ are excluded: not ours, and not called by the
% reconstruction.
%
% Returns empty when the sources are absent, the case in a P-coded release; the
% tests that use it skip themselves then.

PRODUCERS = {'defaultRecoParams.m', 'gatherRecoParams.m'};

root = fileparts(fileparts(mfilename('fullpath')));
files = {};

cls = fullfile(root, '@proudData', 'proudData.m');
if isfile(cls); files{end+1} = cls; end

% '**' so the +proud subpackages and their private/ folder are included --
% scanning only '+proud/*.m' silently dropped 33 files when the package was
% split into +io, +reco, +traj and +util.
d = [dir(fullfile(root, '+proud', '**', '*.m')); ...
     dir(fullfile(root, 'functions', '**', '*.m')); ...
     dir(fullfile(root, 'gui', '**', '*.m'))];
for k = 1:numel(d)
    if any(strcmp(d(k).name, PRODUCERS)); continue; end
    files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
end
end
