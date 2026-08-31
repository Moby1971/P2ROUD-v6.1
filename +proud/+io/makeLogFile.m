function logFileName = makeLogFile(versionTag)

% Full path of the log file for this app version, creating its folder
%
%   logFileName = proud.io.makeLogFile(versionTag)
%
%   versionTag   app version, used as the per-version subfolder name
%   logFileName  full path to p2roud-log-<yyyy-MM-dd-HH-mm-ss>.txt
%
% The log lives beside the settings file, per user and per version, under the
% per-user configuration directory the platform provides:
%
%   macOS    ~/Library/Application Support/P2ROUD/<version>/
%   Windows  %APPDATA%\P2ROUD\<version>\
%   Linux    ~/.config/P2ROUD/<version>/
%
% The name carries a timestamp, so every call names a new file rather than
% appending to one. The folder is created if it does not exist, and if the
% platform directory cannot be read the system temporary folder is used
% instead, so this never stops the app from starting.

% Application name (for subfolder in user config dir)
appName = 'P2ROUD';

% --- Get per-user base directory ---
try
    if ispc % Windows
        baseDir = getenv('APPDATA');  % C:\Users\<user>\AppData\Roaming
    elseif ismac % macOS
        baseDir = fullfile(getenv('HOME'), 'Library', 'Application Support');
    else % Linux / Unix
        baseDir = fullfile(getenv('HOME'), '.config');
    end
catch
    baseDir = tempdir;
end

% Destination folder = baseDir/appName/versionTag
logFolder = fullfile(baseDir, appName, versionTag);

% Make sure the folder exists
if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end

% Date and time tag (safe for filenames)
logTag = string(datetime('now','Format','yyyy-MM-dd-HH-mm-ss'));

% Log file path
logFileName = fullfile(logFolder, strcat("p2roud-log-", logTag, ".txt"));

end