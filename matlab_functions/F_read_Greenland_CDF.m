function data = F_read_Greenland_CDF(path_to_data, fname)
% F_read_Greenland_CDF  Read 1989-era Greenland magnetometer CDF files and
%   return a structure compatible with the CARISMA/F_read_Greenland_SEC style.
%
% Output structure fields (per site):
%   data.SITE.datetime  – datetime column vector (UTC)
%   data.SITE.BX        – local-magnetic H (north) variation, nT
%   data.SITE.BY        – local-magnetic D (east) variation, nT
%   data.SITE.BZ        – vertical (Z) variation, nT
%
% Component handling:
%   The CDF variables Hvar20sec/Dvar20sec/Zvar20sec are already linear
%   local-magnetic nT components (same convention as the 'HEZ' case in
%   F_read_Greenland_SEC -- despite the "D" name, this is not an angle),
%   so X=Hvar, Y=Dvar, Z=Zvar directly, no rotation. Missing samples are
%   already NaN in the source CDF.
%
% Inputs
%   path_to_data – char/string path to the folder containing one
%                  subfolder per site (e.g. path_to_data/GDH/GDH_19890301.cdf)
%   fname        – output filename, e.g. 'Greenland_1989_03.mat'
%                  The file is saved to path_to_data.
%
% File naming convention expected:
%   {path_to_data}/{SITE}/{SITE}_{YYYYMMDD}.cdf
%
% Example:
%   data = F_read_Greenland_CDF('/path/to/Greenland/1989/', 'GL_1989_03.mat');

% ------------------------------------------------------------------ %
%  1.  Discover site subfolders
% ------------------------------------------------------------------ %
d = dir(path_to_data);
d = d([d.isdir] & ~startsWith({d.name}, '.'));
site_ids = {d.name};

if isempty(site_ids)
    error('F_read_Greenland_CDF: no site subfolders found in %s', path_to_data);
end

fprintf('F_read_Greenland_CDF: found %d site folder(s) in %s.\n', numel(site_ids), path_to_data);

data = struct();

for s = 1:numel(site_ids)
    tic
    site_id = upper(site_ids{s});
    site_dir = fullfile(path_to_data, site_ids{s});

    cdf_files = dir(fullfile(site_dir, '*.cdf'));
    if isempty(cdf_files)
        fprintf('  %s: no .cdf files found -- skipping.\n', site_id);
        continue
    end
    cdf_names = sort({cdf_files.name});  % chronological (YYYYMMDD in filename)

    fprintf('  Processing site: %s (%d files)\n', site_id, numel(cdf_names));

    all_datetime = datetime.empty(0, 1);
    all_datetime.TimeZone = 'UTC';
    all_H = [];
    all_D = [];
    all_Z = [];

    for f = 1:numel(cdf_names)
        filepath = fullfile(site_dir, cdf_names{f});

        try
            info = cdfinfo(filepath);
            raw  = cdfread(filepath, 'CombineRecords', 1);
        catch ME
            warning('F_read_Greenland_CDF: could not read %s -- skipping.\n  %s', filepath, ME.message);
            continue
        end

        fdata = struct();
        for k = 1:size(info.Variables, 1)
            fdata.(char(info.Variables(k))) = raw{k};
        end

        required = {'time', 'Hvar20sec', 'Dvar20sec', 'Zvar20sec'};
        if ~all(isfield(fdata, required))
            warning('F_read_Greenland_CDF: %s missing expected variables -- skipping.', filepath);
            continue
        end

        % CDF_EPOCH convention: milliseconds since 0000-01-01T00:00:00,
        % which aligns with MATLAB's datenum(0) reference point.
        cdf_epoch = datetime(0, 'ConvertFrom', 'datenum');
        t = cdf_epoch + seconds(double(fdata.time) / 1000);
        t.TimeZone = 'UTC';

        if sum(~isnan(fdata.Hvar20sec)) < 60
            warning('F_read_Greenland_CDF: too few valid samples in %s -- skipping.', filepath);
            continue
        end

        all_datetime = [all_datetime; t(:)];              %#ok<AGROW>
        all_H        = [all_H; fdata.Hvar20sec(:)];        %#ok<AGROW>
        all_D        = [all_D; fdata.Dvar20sec(:)];        %#ok<AGROW>
        all_Z        = [all_Z; fdata.Zvar20sec(:)];        %#ok<AGROW>
    end

    if ~isempty(all_datetime)
        [all_datetime, idx] = sort(all_datetime);
        all_H = all_H(idx);
        all_D = all_D(idx);
        all_Z = all_Z(idx);
    end

    data.(site_id).datetime = all_datetime;
    data.(site_id).BX       = all_H;   % local-magnetic H (north) variation, nT
    data.(site_id).BY       = all_D;   % local-magnetic D (east) variation, nT
    data.(site_id).BZ       = all_Z;   % vertical variation, nT
    data.(site_id).reported = 'HEZ-CDF';

    t_elapsed = toc;
    fprintf('    Done: %d records | %.1f s\n', numel(all_datetime), t_elapsed);
end

% ------------------------------------------------------------------ %
%  2.  Save
% ------------------------------------------------------------------ %
output_file = fullfile(path_to_data, fname);
save(output_file, 'data', '-v7.3');
fprintf('F_read_Greenland_CDF: data saved to %s\n', output_file);

end
