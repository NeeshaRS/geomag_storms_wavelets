%% Cache_Dst_Locally.m
% Copies the Dst index files (the year-range files Dst_check.m routes
% between by era, covering all events) from the currently-mounted raw
% data drive into processed_data_root, so stats_plots_1989.m (and any
% future event's stats script) can load Dst without needing a drive
% plugged in. Run this any time you're at a machine with a drive mounted,
% to refresh the local cache.
clc;
addpath matlab_functions/
paths = F_loadPaths();

if ~isfolder(paths.dst_index_path)
    error("Dst index source not found at %s -- is a data drive mounted, and does config/paths.json's data_root match it?", paths.dst_index_path);
end

if ~isfolder(paths.processed_dst_index_path)
    mkdir(paths.processed_dst_index_path);
end

files_to_cache = {'Dst_1982-2000.txt', 'Dst_2000-2024.txt', 'Dst2024.mat', 'Dst_description.txt'};

for k = 1:numel(files_to_cache)
    src = fullfile(paths.dst_index_path, files_to_cache{k});
    dst = fullfile(paths.processed_dst_index_path, files_to_cache{k});
    if ~isfile(src)
        warning('Source file not found, skipping: %s', src);
        continue
    end
    copyfile(src, dst);
    fprintf('Cached: %s\n', files_to_cache{k});
end

fprintf('Done -- Dst index cached to %s\n', paths.processed_dst_index_path);
