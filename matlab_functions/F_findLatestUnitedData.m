function [fpath, fname] = F_findLatestUnitedData(dirpath, united_data_fname)
% F_findLatestUnitedData  Find the most recently written united_data.mat
% for an event, whether it's the plain undated name or a dated snapshot.
%
% Data_processing.m writes dated snapshots (e.g. 198903_united_data_
% 20260813.mat) rather than overwriting a fixed filename, so consumers
% (Map_Events.m, etc.) need to pick "the current one" by recency rather
% than assuming a single fixed name. This picks by file modification
% time, not by parsing the date out of the filename, so it's robust to
% naming quirks and also still works if only the original undated file
% exists (e.g. before Data_processing.m has been rerun since this
% dated-snapshot convention was introduced).
%
% INPUTS:
%   dirpath             folder to search (e.g. paths.processed_high_frequency_path)
%   united_data_fname   the event's base filename from events.json,
%                        e.g. '198903_united_data.mat'
%
% OUTPUTS:
%   fpath   full path to the most recently modified match
%   fname   just the filename

[~, base_name, ext] = fileparts(united_data_fname);
pattern = base_name + "*" + ext;

d = dir(fullfile(dirpath, pattern));
if isempty(d)
    error("F_findLatestUnitedData: no files matching %s found in %s", pattern, dirpath);
end

[~, idx] = max([d.datenum]);
fname = d(idx).name;
fpath = fullfile(dirpath, fname);

end
