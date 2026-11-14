function failure_times = F_loadFailureTimes(event_id)
% F_loadFailureTimes  Power-grid failure times (UTC) to mark on an event's
% heatmap, from config/event_landmarks_geo_info_with_cdm.csv (written by
% Calc_IGRF_CDMlatlon.ipynb). Assumes cwd is the repo root, like F_loadPaths.
%
% INPUT
%   event_id      : event id string as in config/events.json (e.g. "2003-10-29")
%
% OUTPUT
%   failure_times : [K x 1] datetime, unique + sorted, from rows of that event
%                   with mark_on_heatmap == 1 (rows sharing a time, e.g. the
%                   two ends of the Hemsjo-Karlshamn line, give one entry).
%                   Empty if none.

lm_path = 'config/event_landmarks_geo_info_with_cdm.csv';
opts = detectImportOptions(lm_path);
opts = setvartype(opts, {'event_id', 'name', 'failure_time_utc'}, 'string');
T = readtable(lm_path, opts);

T = T(T.event_id == string(event_id) & T.mark_on_heatmap == 1, :);
failure_times = unique(datetime(T.failure_time_utc, 'InputFormat', 'yyyy-MM-dd HH:mm:ss'));
failure_times = failure_times(:);

fprintf("\n %d heatmap failure time(s) for %s: %s\n", numel(failure_times), event_id, ...
    strjoin(string(failure_times, 'yyyy-MM-dd HH:mm:ss'), ', '));
end
