function data = F_read_CARISMA_MAG(path_to_data, fname)
% F_read_CARISMA_MAG Reads CARISMA .MAG files and organizes by site.
%
% Input:
%   path_to_data - string/char path to folder containing *.MAG
%   fname        - filename to save (e.g., 'Carisma_2003_10-11.mat')
%
% Output:
%   data - structure with fields per site:
%          data.SITE.datetime (datetime)
%          data.SITE.BX, data.SITE.BY, data.SITE.BZ (double)
%          data.SITE.lat, data.SITE.lon (double)  [from metadata line]
%
% Assumes file format like:
%   20031024CONT.MAG  (YYYYMMDD + SITE + .MAG)
% Inside file:
%   # ... (39-ish comment lines)
%   SITE  lat  lon  YYYYMMDD  GEODETIC  nT#####
%   YYYYMMDDhhmmss  BX  BY  BZ  flag
%
% Example data line:
%   20031024000001  7930.500  3768.700 59572.176 .

% Get all .MAG files in directory
file_list = dir(fullfile(path_to_data, '*.MAG'));
if isempty(file_list)
    error('No .MAG files found in %s', path_to_data);
end

% Extract site names from filenames (assume YYYYMMDD + SITE + .MAG)
site_names = cell(length(file_list), 1);
for i = 1:length(file_list)
    this_file = file_list(i).name;
    this_no_ext = this_file(1:end-4);          % drop ".MAG"
    if length(this_no_ext) < 9
        error('Unexpected filename format: %s', this_file);
    end
    site_names{i} = this_no_ext(9:end);        % chars after YYYYMMDD
end

unique_sites = unique(site_names);
n_sites = length(unique_sites);
fprintf('Found %d files from %d sites.\n', length(file_list), n_sites);

% Initialize structure array
data = struct();

for s = 1:n_sites
    tic
    site_id = unique_sites{s};
    fprintf('Processing site: %s\n', site_id);

    % files for this site
    site_files = {file_list(strcmp(site_names, site_id)).name};

    all_datetime = datetime.empty(0,1);
    all_BX = [];
    all_BY = [];
    all_BZ = [];

    site_lat = NaN;
    site_lon = NaN;

    for f = 1:length(site_files)
        filepath = fullfile(path_to_data, site_files{f});

        fid = fopen(filepath, 'r');
        if fid == -1
            warning('Could not open: %s (skipping)', filepath);
            continue
        end

        % --- 1) Skip comment lines beginning with '#', then read metadata line
        meta_line = '';
        while true
            this_line = fgetl(fid);
            if ~ischar(this_line)
                break
            end
            this_line = strtrim(this_line);
            if isempty(this_line)
                continue
            end
            if startsWith(this_line, '#')
                continue
            end
            meta_line = this_line;  % first non-comment line
            break
        end

        if isempty(meta_line)
            fclose(fid);
            warning('No metadata line found in %s (skipping)', filepath);
            continue
        end

        % Parse metadata line:
        % Example: CONT  65.754 248.750 20031024 GEODETIC nT17239
        mtok = textscan(meta_line, '%s %f %f %s %s %s', ...
            'Delimiter', ' ', 'MultipleDelimsAsOne', true);

        file_site = mtok{1}{1};
        lat = mtok{2};
        lon = mtok{3};

        % sanity: if filename site differs from file line, trust file line
        if ~strcmp(file_site, site_id)
            % If this happens, we still append into the filename-grouped site,
            % but you can change to re-route if you prefer.
            warning('Filename site (%s) != file site (%s) in %s', site_id, file_site, site_files{f});
        end

        % store lat/lon once (or overwrite with same values)
        if isnan(site_lat); site_lat = lat; end
        if isnan(site_lon); site_lon = lon; end

        % --- 2) Read data rows to EOF
        % Format: YYYYMMDDhhmmss  BX  BY  BZ  flag
        dt = textscan(fid, '%14s %f %f %f %s', ...
            'Delimiter', ' ', 'MultipleDelimsAsOne', true);

        fclose(fid);

        if isempty(dt{1})
            continue
        end

        t = datetime(dt{1}, 'InputFormat', 'yyyyMMddHHmmss');  % naive datetime
        bx = dt{2};
        by = dt{3};
        bz = dt{4};
        % flag = dt{5};  % available if you later want to QC using '.' etc.

        all_datetime = [all_datetime; t(:)];
        all_BX = [all_BX; bx(:)];
        all_BY = [all_BY; by(:)];
        all_BZ = [all_BZ; bz(:)];
    end

    % Sort by time (important after concatenating many daily files)
    if ~isempty(all_datetime)
        [all_datetime, idx] = sort(all_datetime);
        all_BX = all_BX(idx);
        all_BY = all_BY(idx);
        all_BZ = all_BZ(idx);
    end

    % Store in structure
    data.(site_id).datetime = all_datetime;
    data.(site_id).BX = all_BX;
    data.(site_id).BY = all_BY;
    data.(site_id).BZ = all_BZ;
    data.(site_id).lat = site_lat;
    data.(site_id).lon = site_lon;

    toc
end

% Save to .mat file
output_file = fullfile(path_to_data, fname);
save(output_file, 'data');
fprintf('Data saved to: %s\n', output_file);

end