function data = F_read_CARISMA_F01(path_to_data,fname)
% READ_MAGNETIC_DATA Reads CARISMA magnetic field  F01 data files and 
% organizes by site.
%
% Input:
%   path_to_data - string or char array with path to data folder
%   fname - string for saving the data to the folder
%
% Output:
%   data - structure array with fields: site, datetime, BX, BY, BZ
%
% File format assumed: YEARMMDDSITE.F01
% Example: 20240101ABCD.F01

% Get all .F01 files in directory
file_list = dir(fullfile(path_to_data, '*.F01'));

if isempty(file_list)
    error('No .F01 files found in %s', path_to_data);
end

% Extract site names from filenames
% Assuming format YEARMMDDSITE.F01 where SITE is remaining chars after date
site_names = cell(length(file_list), 1);
for i = 1:length(file_list)
    this_file = file_list(i).name;
    % Remove extension
    this_file_no_ext = this_file(1:end-4);
    % Extract site (characters after position 9, which is after YYYYMMDD)
    site_names{i} = this_file_no_ext(9:end);
end

% Get unique sites
unique_sites = unique(site_names);
n_sites = length(unique_sites);
fprintf('Found %d files from %d sites.\n', length(file_list), n_sites);

% Initialize structure array
data = struct();

for s = 1:n_sites
    tic
    site_id = unique_sites{s};
    fprintf('Processing site: %s\n', site_id);
    
    % Find all files for this site
    site_files = {};
    for i = 1:length(file_list)
        if strcmp(site_names{i}, site_id)
            site_files{end+1} = file_list(i).name;
        end
    end
    
    % Sort files chronologically
    site_files = sort(site_files);
    
    % Initialize arrays for concatenation
    all_datetime = [];
    all_BX = [];
    all_BY = [];
    all_BZ = [];
    
    % Read each file for this site
    for f = 1:length(site_files)
        filepath = fullfile(path_to_data, site_files{f});
        
        % Read the data file (tab-delimited with 1 header line)
        opts = delimitedTextImportOptions('Delimiter', ' ', 'NumVariables', 5);
        opts.DataLines = [2, Inf];
        opts.VariableTypes = {'double', 'double', 'double', 'double', 'char'};
        opts.ConsecutiveDelimitersRule = 'join';
        opts = setvaropts(opts, 5, 'WhitespaceRule', 'preserve');
        file_table = readtable(filepath, opts);

        % Quick doublecheck to ignore corrupt file
        ts = file_table{:,1};
        is_plausible_ts = isfinite(ts) & ts >= 19500101000000 & ts <= 21000101000000;

        if nnz(is_plausible_ts) < 60
            warning('Skipping suspicious file (too few plausible timestamps): %s', filepath);
            continue
        end

        % Extract datetime from first column (format: YYYYMMDDHHMMSS)
        timestamp_num = file_table{:, 1};
        timestamp_str = num2str(timestamp_num, '%.0f');
        day_datetime = datetime(timestamp_str,'InputFormat','yyyyMMddHHmmss');
        
        % Concatenate data
        all_datetime = [all_datetime; day_datetime];
        all_BX = [all_BX; file_table{:, 2}];
        all_BY = [all_BY; file_table{:, 3}];
        all_BZ = [all_BZ; file_table{:, 4}];
    end
    
    % Store in structure using site name as field
    data.(site_id).datetime = all_datetime;
    data.(site_id).BX = all_BX;
    data.(site_id).BY = all_BY;
    data.(site_id).BZ = all_BZ;

    toc
end

% Save to .mat file
output_file = fullfile(path_to_data, fname);
save(output_file, 'data');
fprintf('Data saved to: %s\n', output_file);

end