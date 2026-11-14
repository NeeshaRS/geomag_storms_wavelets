function data = F_read_CARISMA(path_to_data, fname, ftype)
% F_read_CARISMA Dispatch helper for CARISMA file readers
%
% Inputs:
%   path_to_data - path to CARISMA data directory
%   fname        - output .mat filename
%   ftype        - file type ('mag' or 'f01', case-insensitive)
%
% Output:
%   data - CARISMA data structure
%
% Example:
%   data = F_read_CARISMA(path, 'Carisma_2003.mat', 'MAG');
%   data = F_read_CARISMA(path, 'Carisma_2003.mat', 'f01');

% ---- input checks
if nargin < 3
    error('F_read_CARISMA requires path_to_data, fname, and ftype.');
end

if ~ischar(ftype) && ~isstring(ftype)
    error('ftype must be a string or char array.');
end

% Normalize ftype (case-insensitive)
ftype = lower(strtrim(ftype));

% ---- dispatch
switch ftype
    case 'mag'
        fprintf('Reading CARISMA MAG files...\n');
        data = F_read_CARISMA_MAG(path_to_data, fname);

    case 'f01'
        fprintf('Reading CARISMA F01 files...\n');
        data = F_read_CARISMA_F01(path_to_data, fname);

    otherwise
        error('Unsupported ftype "%s". Use "mag" or "f01".', ftype);
end

end
