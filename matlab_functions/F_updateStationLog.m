function out_path = F_updateStationLog(paths, E, network, sites, infos, kept, grid_first, grid_last)
% F_updateStationLog  Write/refresh this event's station-tracking CSV: one row per
% station the cleaning pipeline looked at (kept AND dropped, with the reason).
% Called by Network_event_plotting.m and Greenland_event_plotting.m after
% cleaning, so the same file accumulates every network of an event. Rows for
% `network` are replaced on each call (re-running one network never touches the
% others); all timestamps are written as text "yyyy-MM-dd HH:mm:ss".
%
% Output: <processed_data_root>/WO_data/station_tracking/<year>_station_tracking.csv
%
% INPUTS:
%   paths       struct from F_loadPaths (uses .processed_data_root)
%   E           event struct
%   network     network label for these rows ("IMAGE", "CARISMA", "OTT", "DTU")
%   sites       cellstr, every station that went through F_cleanStation
%   infos       cell of the `info` structs F_cleanStation returned (same order)
%   kept        logical, true where the station was kept
%   grid_first, grid_last   datetime vectors (NaT for dropped stations): the
%               first/last valid time of each kept station on the event grid
%
% Columns: Event, Network, Site, Status (kept/dropped), Reason, Note (start/end
% overrides applied), InputStart/InputEnd (the station's span in united_data),
% UsedStart/UsedEnd (span on the grid), CadenceSec, LongestGapMin (longest
% internal gap, after spike removal for kept stations), NInterpolated,
% NSpikesRemoved (flat threshold + Hampel).

n = numel(sites);
fmt = 'yyyy-MM-dd HH:mm:ss';
txt = @(d) string(d, fmt);

Event = repmat(string(E.id), n, 1);
Network = repmat(string(network), n, 1);
Site = string(sites(:));
Status = repmat("kept", n, 1);
Reason = strings(n, 1);
Note = strings(n, 1);
InputStart = strings(n, 1);
InputEnd = strings(n, 1);
UsedStart = strings(n, 1);
UsedEnd = strings(n, 1);
CadenceSec = nan(n, 1);
LongestGapMin = nan(n, 1);
NInterpolated = nan(n, 1);
NSpikesRemoved = nan(n, 1);

for k = 1:n
    s = infos{k};
    if ~kept(k); Status(k) = "dropped"; end
    Reason(k) = string(s.drop_reason);
    InputStart(k) = txt(s.first_in);
    InputEnd(k)   = txt(s.last_in);
    if ~isnat(grid_first(k)); UsedStart(k) = txt(grid_first(k)); end
    if ~isnat(grid_last(k));  UsedEnd(k)   = txt(grid_last(k));  end
    CadenceSec(k) = s.cadence_s;
    if ~isnan(s.max_gap_min_post); LongestGapMin(k) = s.max_gap_min_post; else; LongestGapMin(k) = s.max_gap_min; end
    NInterpolated(k)  = s.n_interpolated;
    NSpikesRemoved(k) = s.n_spikes_flat + s.n_spikes_hampel;

    notes = strings(0, 1);
    if isfield(E, 'station_start_overrides') && isstruct(E.station_start_overrides) && isfield(E.station_start_overrides, sites{k})
        notes(end+1) = "start trimmed to " + string(datetime(E.station_start_overrides.(sites{k})), fmt); %#ok<AGROW>
    end
    if isfield(E, 'station_end_overrides') && isstruct(E.station_end_overrides) && isfield(E.station_end_overrides, sites{k})
        notes(end+1) = "end trimmed to " + string(datetime(E.station_end_overrides.(sites{k})), fmt); %#ok<AGROW>
    end
    Note(k) = strjoin(notes, "; ");
end

T = table(Event, Network, Site, Status, Reason, Note, InputStart, InputEnd, UsedStart, UsedEnd, ...
    CadenceSec, LongestGapMin, NInterpolated, NSpikesRemoved);

out_dir = fullfile(paths.processed_data_root, 'WO_data', 'station_tracking');
if ~isfolder(out_dir); mkdir(out_dir); end
out_path = fullfile(out_dir, sprintf('%s_station_tracking.csv', extractBefore(E.id, 5)));

% Merge with whatever other networks are already in the file.
if isfile(out_path)
    old = readtable(out_path, 'TextType', 'string', 'DatetimeType', 'text');
    for v = {'Reason', 'Note', 'UsedStart', 'UsedEnd'}
        old.(v{1}) = string(old.(v{1}));
        old.(v{1})(ismissing(old.(v{1}))) = "";
    end
    old = old(old.Network ~= string(network), :);
    T = [old(:, T.Properties.VariableNames); T];
end

% Keep networks in the event's own order (E.networks), stations in cleaning order.
net_order = string(cellstr(E.networks));
net_order = net_order(:);
[~, net_rank] = ismember(T.Network, net_order);
net_rank(net_rank == 0) = numel(net_order) + 1;
[~, ix] = sort(net_rank);   % MATLAB's sort is stable, so cleaning order is kept within a network
T = T(ix, :);

writetable(T, out_path);
fprintf("Station tracking CSV updated (%s, %d stations): %s\n", network, n, out_path);

end
