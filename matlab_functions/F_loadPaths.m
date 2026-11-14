function paths = F_loadPaths()
% F_loadPaths  Load config/paths.json (assumes cwd is the repo root, matching
% the existing 'addpath matlab_functions/' convention used throughout this repo).
%
% OUTPUT:
%   paths  struct with fields from paths.json, plus convenience fields
%          dst_index_path and high_frequency_path (data_root joined with
%          the relevant subdir), and processed_high_frequency_path /
%          processed_dst_index_path (processed_data_root joined with the
%          same subdirs -- local, machine-resident caches of drive-based
%          data, so scripts can run without an external drive plugged in;
%          see Cache_Dst_Locally.m for what populates the latter).

if ~isfile('config/paths.json')
    error("config/paths.json not found -- copy config/paths.example.json to config/paths.json and set the paths for your machine.");
end
paths = jsondecode(fileread('config/paths.json'));
paths.dst_index_path = fullfile(paths.data_root, paths.dst_index_dir);
paths.high_frequency_path = fullfile(paths.data_root, paths.high_frequency_dir);
paths.processed_high_frequency_path = fullfile(paths.processed_data_root, paths.high_frequency_dir);
paths.processed_dst_index_path = fullfile(paths.processed_data_root, paths.dst_index_dir);

end
