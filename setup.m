% SETUP  Add every script and data folder of this repository to the MATLAB path.
%
%   Run this once from the repository root before running any script:
%
%       >> setup
%
%   Scripts load OSM building files (e.g. "seongnam.osm") by file name only, so
%   the data folder must be on the MATLAB path. Result files (PNG/CSV/MAT) are
%   written to the current folder, so `cd` into the matching results/ subfolder
%   if you want new outputs to land next to the existing ones.

rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootDir, 'scripts')));
addpath(genpath(fullfile(rootDir, 'data')));
fprintf('Added scripts/ and data/ under\n  %s\nto the MATLAB path.\n', rootDir);
