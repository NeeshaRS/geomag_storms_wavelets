function data = F_read_Greenland_SEC(path_to_data, fname)
% F_read_Greenland_SEC  Read IAGA-2002 Greenland magnetometer files
%   (.sec 1-second files or .20s 20-second files) and return a structure
%   compatible with the CARISMA reader style.
%
% Output structure fields (per site):
%   data.SITE.datetime  – datetime column vector (UTC)
%   data.SITE.BX        – geographic North (X) component, nT
%   data.SITE.BY        – geographic East  (Y) component, nT
%   data.SITE.BZ        – vertical down    (Z) component, nT
%   data.SITE.BF        – total field F, nT  (NaN where fill, or not reported)
%   data.SITE.lat       – geodetic latitude  (degrees)
%   data.SITE.lon       – geodetic longitude (degrees, 0-360 east)
%   data.SITE.elevation – elevation (m)
%   data.SITE.reported  – original reported component string, e.g. 'XYZF'
%
% Component handling (based on each file's own "Reported" header line):
%   XYZ* : stored directly, no rotation.
%   HEZ* : H and E are already linear local-magnetic components (nT), so
%          X=H, Y=E, Z=Z directly -- no rotation.
%   HDZ* : D is an angle (arcminutes, positive east) and gets rotated:
%       X =  H * cos(D)
%       Y =  H * sin(D)
%       Z =  Z  (unchanged)
%   Fill values become NaN before any rotation so NaN propagates correctly.
%
% Inputs
%   path_to_data – char/string path to folder containing the raw files
%   fname        – output filename, e.g. 'Greenland_2024_05.mat'
%                  The file is saved to path_to_data.
%
% File naming convention expected:
%   {SITE3}{YYYYMMDD}{TYPE}sec.sec   (1-second cadence)
%   {SITE3}{YYYYMMDD}{TYPE}sec.20s   (20-second cadence)
%   where SITE3 is a 3-letter IAGA station code and TYPE is a single
%   data-type letter (p=provisional, v=variation, q=quasi-definitive,
%   d=definitive).
%
% IAGA-2002 format notes:
%   - Header records are distinguished by a trailing '|' character.
%   - The last header line contains the column labels
%     (DATE, TIME, DOY, then three or four component columns).
%   - The fill/invalid-data value is read from each file's own
%     "# Invalid Data Code" header line (defaults to 88888.0 if absent,
%     since not every source station includes that line).
%
% Example:
%   data = F_read_Greenland_SEC('/path/to/Greenland/', 'GL_2024_May.mat');

DEFAULT_FILL_VALUE = 88888.0;  % fallback if a file has no "Invalid Data Code" line

% IAGA-2002 / INTERMAGNET data-type precedence, highest quality wins.
% definitive > quasi-definitive > provisional > variation.
TYPE_PRECEDENCE = 'vpqd';  % index into this string; later letter = better

% ------------------------------------------------------------------ %
%  1.  Collect files, keeping only the best available type per
%      site+date when multiple data-type versions exist (e.g. both a
%      provisional 'psec' and a variation 'vsec' file for the same day).
% ------------------------------------------------------------------ %
% Search both the folder itself and one level of subfolders, since some
% eras store all sites' files together in one flat folder (e.g. 2024) and
% others store one subfolder per site (e.g. 2003, .../Greenland/2003/GDH/).
file_list = [dir(fullfile(path_to_data, '*.sec')); dir(fullfile(path_to_data, '*.20s')); ...
             dir(fullfile(path_to_data, '*', '*.sec')); dir(fullfile(path_to_data, '*', '*.20s'))];
if isempty(file_list)
    error('F_read_Greenland_SEC: no *.sec or *.20s files found in %s (or its immediate subfolders)', path_to_data);
end

% Parse site code, date, and data-type letter from each filename.
% Expected pattern: SSSYYYYMMDD?sec.(sec|20s)  (SSS = site, ? = data-type letter)
n_files = numel(file_list);
f_site = cell(n_files, 1);
f_date = cell(n_files, 1);
f_type = repmat(' ', n_files, 1);
f_keep = true(n_files, 1);
for i = 1:n_files
    fname_i = file_list(i).name;   % e.g. kul20240510psec.sec or GDH20031001vsec.20s
    tok = regexp(fname_i, '^([a-zA-Z]{3})(\d{8})([a-zA-Z])sec\.(sec|20s)$', 'tokens', 'once');
    if isempty(tok)
        warning('F_read_Greenland_SEC: filename %s does not match the expected SSSYYYYMMDD?sec.(sec|20s) pattern -- keeping as-is (no dedup).', fname_i);
        f_site{i} = upper(fname_i(1:3));
        continue
    end
    f_site{i} = upper(tok{1});
    f_date{i} = tok{2};
    f_type(i) = lower(tok{3});
end

% For each (site, date) with more than one type present, keep only the
% highest-precedence type and drop the rest.
key = strcat(f_site, {'_'}, f_date);
[unique_keys, ~, grp] = unique(key);
for g = 1:numel(unique_keys)
    idx = find(grp == g);
    if numel(idx) <= 1
        continue
    end
    precedence = arrayfun(@(t) max([0, strfind(TYPE_PRECEDENCE, t)]), f_type(idx));
    [~, best] = max(precedence);
    dropped = idx(1:end ~= best);
    for d = dropped(:)'
        fprintf('F_read_Greenland_SEC: %s and %s cover the same day -- keeping %s, dropping %s.\n', ...
            file_list(idx(best)).name, file_list(d).name, file_list(idx(best)).name, file_list(d).name);
    end
    f_keep(dropped) = false;
end

file_list  = file_list(f_keep);
site_names = f_site(f_keep);

unique_sites = unique(site_names);
n_sites      = length(unique_sites);
fprintf('F_read_Greenland_SEC: found %d file(s) from %d site(s).\n', ...
        length(file_list), n_sites);

% ------------------------------------------------------------------ %
%  2.  Loop over sites
% ------------------------------------------------------------------ %
data = struct();

for s = 1:n_sites
    tic
    site_id = unique_sites{s};
    fprintf('  Processing site: %s\n', site_id);

    % All files for this site (full paths, since files may live in a
    % per-site subfolder rather than path_to_data itself)
    site_mask  = strcmp(site_names, site_id);
    matched    = file_list(site_mask);
    site_files = arrayfun(@(f) fullfile(f.folder, f.name), matched, 'UniformOutput', false);
    site_files = sort(site_files);           % chronological order (folder prefix is constant per site)

    % Accumulators — must carry TimeZone='UTC' from the start so that
    % vertical concatenation with parsed UTC datetimes does not error.
    all_datetime = datetime.empty(0, 1);
    all_datetime.TimeZone = 'UTC';
    all_BX = [];
    all_BY = [];
    all_BZ = [];
    all_BF = [];

    site_lat       = NaN;
    site_lon       = NaN;
    site_elev      = NaN;
    site_reported  = '';

    % ------------------------------------------------------------ %
    %  2a.  Loop over daily files for this site
    % ------------------------------------------------------------ %
    for f = 1:length(site_files)
        filepath = site_files{f};  % already a full path

        fid = fopen(filepath, 'r');
        if fid == -1
            warning('F_read_Greenland_SEC: cannot open %s — skipping.', filepath);
            continue
        end

        % ........................................................
        %  Parse header  (lines ending with '|')
        % ........................................................
        col_labels = {};   % filled from the last header line
        file_lat   = NaN;
        file_lon   = NaN;
        file_elev  = NaN;
        file_rep   = '';
        file_fill  = DEFAULT_FILL_VALUE;

        while true
            raw = fgetl(fid);
            if ~ischar(raw)
                break          % EOF inside header — malformed file
            end
            line = strtrim(raw);
            if isempty(line)
                continue
            end

            % All IAGA-2002 header lines end with '|'
            if line(end) ~= '|'
                % First data line — put it back by seeking is awkward;
                % instead process it directly below after breaking.
                % We'll re-read it via the data-scan loop.
                break
            end

            % Strip trailing whitespace + '|' to get the content
            content = strtrim(line(1:end-1));

            % ---- key metadata fields --------------------------------
            if startsWith(content, 'Geodetic Latitude', 'IgnoreCase', true)
                tok = regexp(content, '([-\d.]+)\s*$', 'tokens', 'once');
                if ~isempty(tok); file_lat = str2double(tok{1}); end

            elseif startsWith(content, 'Geodetic Longitude', 'IgnoreCase', true)
                tok = regexp(content, '([-\d.]+)\s*$', 'tokens', 'once');
                if ~isempty(tok); file_lon = str2double(tok{1}); end

            elseif startsWith(content, 'Elevation', 'IgnoreCase', true)
                tok = regexp(content, '([-\d.]+)\s*$', 'tokens', 'once');
                if ~isempty(tok); file_elev = str2double(tok{1}); end

            elseif startsWith(content, 'Reported', 'IgnoreCase', true)
                % e.g. "Reported   XYZF" or "Reported   HEZ (local magnetic)"
                % -- take the letters-only token right after 'Reported',
                % ignoring any trailing parenthetical annotation.
                tok = regexp(content, 'Reported\s+([A-Za-z]+)', 'tokens', 'once');
                if ~isempty(tok); file_rep = upper(strtrim(tok{1})); end

            elseif startsWith(content, 'Invalid Data Code', 'IgnoreCase', true)
                tok = regexp(content, '([-\d.]+)\s*$', 'tokens', 'once');
                if ~isempty(tok); file_fill = str2double(tok{1}); end

            elseif startsWith(content, 'DATE', 'IgnoreCase', true)
                % This is the column-label line, e.g.:
                % DATE       TIME         DOY    GDHX      GDHY      GDHZ      GDHF
                col_labels = strsplit(strtrim(content));
                % col_labels{1}='DATE', {2}='TIME', {3}='DOY',
                % {4..7} = component columns (e.g. GDHX GDHY GDHZ GDHF)
            end
        end

        % Store metadata once (use first file's values; they don't change)
        if isnan(site_lat) && ~isnan(file_lat);   site_lat   = file_lat;  end
        if isnan(site_lon) && ~isnan(file_lon);   site_lon   = file_lon;  end
        if isnan(site_elev) && ~isnan(file_elev); site_elev  = file_elev; end
        if isempty(site_reported) && ~isempty(file_rep)
            site_reported = file_rep;
        end

        % ........................................................
        %  Read data records
        % ........................................................
        % Format: DATE(yyyy-MM-dd)  TIME(HH:mm:ss.SSS)  DOY  C1  C2  C3  C4
        raw_data = textscan(fid, '%s %s %d %f %f %f %f', ...
            'Delimiter', ' ', 'MultipleDelimsAsOne', true, ...
            'CommentStyle', '#');
        fclose(fid);

        if isempty(raw_data{1})
            warning('F_read_Greenland_SEC: no data records in %s — skipping.', filepath);
            continue
        end

        % Build datetime from date + time strings
        dt_strings = strcat(raw_data{1}, {' '}, raw_data{2});
        try
            t = datetime(dt_strings, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS', ...
                         'TimeZone', 'UTC');
        catch ME
            warning('F_read_Greenland_SEC: datetime parse failed in %s — skipping.\n  %s', ...
                    filepath, ME.message);
            continue
        end

        c1 = raw_data{4};
        c2 = raw_data{5};
        c3 = raw_data{6};
        c4 = raw_data{7};

        % Replace fill values with NaN (this file's own fill value, from its header)
        c1(abs(c1 - file_fill) < 1) = NaN;
        c2(abs(c2 - file_fill) < 1) = NaN;
        c3(abs(c3 - file_fill) < 1) = NaN;
        c4(abs(c4 - file_fill) < 1) = NaN;

        % Sanity check: reject files with implausibly few valid timestamps
        if sum(~isnat(t)) < 60
            warning('F_read_Greenland_SEC: too few valid timestamps in %s — skipping.', filepath);
            continue
        end

        all_datetime = [all_datetime; t(:)];  %#ok<AGROW>
        all_BX = [all_BX; c1(:)];             %#ok<AGROW>
        all_BY = [all_BY; c2(:)];             %#ok<AGROW>
        all_BZ = [all_BZ; c3(:)];             %#ok<AGROW>
        all_BF = [all_BF; c4(:)];             %#ok<AGROW>
    end  % file loop

    % ------------------------------------------------------------ %
    %  2b.  Sort by time
    % ------------------------------------------------------------ %
    if ~isempty(all_datetime)
        [all_datetime, idx] = sort(all_datetime);
        all_BX = all_BX(idx);
        all_BY = all_BY(idx);
        all_BZ = all_BZ(idx);
        all_BF = all_BF(idx);
    end

    % ------------------------------------------------------------ %
    %  2c.  Rotate HDZ → XYZ if necessary
    %       IAGA-2002 convention for HDZ:
    %         H  = horizontal intensity (nT)
    %         D  = declination angle   (arcminutes, positive east)
    %         Z  = vertical component  (nT, positive down)
    %       Rotation to geographic XYZ:
    %         X =  H * cos(D_rad)
    %         Y =  H * sin(D_rad)
    %         Z =  Z  (unchanged)
    % ------------------------------------------------------------ %
    switch upper(site_reported(1:3))   % inspect first 3 chars (HDZ / XYZ / HEZ)
        case 'HDZ'
            fprintf('    Rotating HDZ → XYZ for site %s\n', site_id);
            H = all_BX;          % stored as BX during read
            D = all_BY;          % stored as BY; units: arcminutes
            D_rad = D * (pi / 180 / 60);   % arcminutes → radians
            all_BX = H .* cos(D_rad);
            all_BY = H .* sin(D_rad);
            % all_BZ unchanged
        case 'XYZ'
            % nothing to do
        case 'HEZ'
            % H and E are already linear local-magnetic nT components
            % (E = eastward variation) -- straight passthrough, X=H, Y=E.
            fprintf('    HEZ reported for site %s -- using H as X, E as Y directly (no rotation).\n', site_id);
        otherwise
            warning('F_read_Greenland_SEC: unrecognised component type "%s" for site %s — storing as-is.', ...
                    site_reported, site_id);
    end

    data.(site_id).datetime  = all_datetime;
    data.(site_id).BX        = all_BX;   % geographic North (X), nT
    data.(site_id).BY        = all_BY;   % geographic East  (Y), nT
    data.(site_id).BZ        = all_BZ;   % vertical down    (Z), nT
    data.(site_id).BF        = all_BF;   % total field F,   nT
    data.(site_id).lat       = site_lat;
    data.(site_id).lon       = site_lon;
    data.(site_id).elevation = site_elev;
    data.(site_id).reported  = site_reported;   % e.g. 'XYZF'

    t_elapsed = toc;
    fprintf('    Done: %d records | reported=%s | lat=%.3f lon=%.3f | %.1f s\n', ...
            length(all_datetime), site_reported, site_lat, site_lon, t_elapsed);
end  % site loop

% ------------------------------------------------------------------ %
%  3.  Save
% ------------------------------------------------------------------ %
output_file = fullfile(path_to_data, fname);
save(output_file, 'data', '-v7.3');
fprintf('F_read_Greenland_SEC: data saved to %s\n', output_file);

end  % function