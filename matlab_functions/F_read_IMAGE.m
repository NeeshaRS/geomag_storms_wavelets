function image = F_read_IMAGE(path_to_data, fname)
% F_read_IMAGE  Parse a raw IMAGE array .txt export into a flat struct.
%
% Expected format: 2 header lines (column-name line, then a dashed
% separator), then whitespace-delimited data rows of
%   YYYY MM DD HH MM SS  <STA1 X> <STA1 Y> <STA1 Z>  <STA2 X> <STA2 Y> <STA2 Z> ...
% Fill values (99999.9) are left as-is -- this function does raw I/O only,
% no cleaning.
%
% INPUTS:
%   path_to_data  folder containing the file
%   fname         filename, e.g. 'image_1989_03_08-18.txt'
%
% OUTPUT:
%   image  struct with one [Nx1] double field per '<STA><AXIS>' (e.g.
%          'SORX', 'SORY', 'SORZ', ...) plus a [Nx1] datetime field
%          'datetime_vector'. Same shape as the legacy hand-saved
%          image_*.mat files this replaces.

fpath = fullfile(path_to_data, fname);

fid = fopen(fpath, 'r');
assert(fid ~= -1, "Could not open %s", fpath);
header_line = fgetl(fid);
fgetl(fid);  % discard the dashed separator line
fclose(fid);

% ---- Parse station/axis order from the header line
tokens = strsplit(strtrim(header_line));
% first 6 tokens are the time columns (YYYY MM DD HH MM SS); the rest
% come in (station, axis) pairs, e.g. 'SOR','X','SOR','Y','SOR','Z',...
station_tokens = tokens(7:end);
assert(mod(numel(station_tokens), 2) == 0, ...
    "Unexpected header format in %s: station/axis tokens don't pair up.", fpath);
stations = station_tokens(1:2:end);
axes_    = station_tokens(2:2:end);
field_names = strcat(stations, axes_);

% ---- Read the numeric data block (time columns + all station columns)
M = readmatrix(fpath, 'NumHeaderLines', 2, 'FileType', 'text');
n_expected_cols = 6 + numel(field_names);
assert(size(M,2) == n_expected_cols, ...
    "%s: expected %d columns from header, found %d in data.", ...
    fpath, n_expected_cols, size(M,2));

% ---- Build datetime vector from the first 6 columns
image = struct();
image.datetime_vector = datetime(M(:,1), M(:,2), M(:,3), M(:,4), M(:,5), M(:,6));

% ---- One field per station/axis, in header order
data_cols = M(:, 7:end);
for k = 1:numel(field_names)
    image.(field_names{k}) = data_cols(:,k);
end

end
