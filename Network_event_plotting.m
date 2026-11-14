%% Network_event_plotting.m
% Consolidates IMAGE_event_plotting_{1989,2003,2008}.m and
% Ottawa_event_plotting.m into one registry- and network-driven script.
% IMAGE, CARISMA, and OTT all share the same raw convention (geographic
% X/Y/Z; H = sqrt(X^2+Y^2), Z = raw Z) -- they only differ in which
% source tag to filter on and the Z spike threshold. (Greenland is
% handled separately in Greenland_event_plotting.m: its BX/BY are
% already local-magnetic H/D, not geographic X/Y needing combination.)
clc; clear all; close all;
dbstop if error

%% 0) Paths + config
addpath matlab_functions/
paths = F_loadPaths();
fprintf("Paths set.")

%% 1) EVENT REGISTRY -- mappable events only (i.e. have a united dataset)
all_events = F_loadEvents();
mappable = arrayfun(@(e) ~isempty(e.united_data_fname), all_events);
events = all_events(mappable);
fprintf("\nLoaded %d mappable events from config/events.json.", numel(events));

%% 2) SELECT EVENT + NETWORK
event_idx = 3;  % index into `events`; see events(k).id -- 2 = 2003-10-29
network = "IMAGE";  % "IMAGE" | "CARISMA" | "OTT"

Z_THRESHOLDS = struct('IMAGE', 80000, 'CARISMA', 80000, 'OTT', 80000);
z_threshold = Z_THRESHOLDS.(char(network));

E = events(event_idx);
fprintf("\n=== %s plotting for event %d/%d: %s ===\n%s\n\n", network, event_idx, numel(events), E.id, E.description);

%% 3) LOAD DATA (most recent united_data.mat for this event)
[matpath, matfname] = F_findLatestUnitedData(paths.processed_high_frequency_path, E.united_data_fname);
S = load(matpath);
data = S.data;
fprintf("...loaded %s\n", matfname);

%% 4) SELECT + ORDER this network's stations (by decreasing cdm_lat)
sites = fieldnames(data);
net_sites = {};
net_cdm_lats = [];
for k = 1:numel(sites)
    d = data.(sites{k});
    if isfield(d, 'source') && string(d.source) == network
        net_sites{end+1} = sites{k}; %#ok<AGROW>
        if isfield(d, 'cdm_lat'); net_cdm_lats(end+1) = d.cdm_lat; else; net_cdm_lats(end+1) = NaN; end %#ok<AGROW>
    end
end
net_sites = net_sites(:);

% Defensive filter in case this united_data.mat predates the current
% exclude_sites list in events.json (matches Map_Events.m's same check).
if isfield(E, 'exclude_sites') && ~isempty(E.exclude_sites)
    dropped = intersect(net_sites, E.exclude_sites);
    if ~isempty(dropped)
        fprintf("Excluding %s (config/events.json exclude_sites).\n", strjoin(dropped, ', '));
    end
    keep = ~ismember(net_sites, E.exclude_sites);
    net_sites = net_sites(keep);
    net_cdm_lats = net_cdm_lats(keep);
end

if isempty(net_sites)
    error("No stations with source=='%s' found in %s for event %s.", network, matfname, E.id);
end
[~, order] = sort(net_cdm_lats, 'descend', 'MissingPlacement', 'last');
net_sites = net_sites(order);
N = numel(net_sites);
fprintf("Found %d %s station(s): %s\n", N, network, strjoin(net_sites, ', '));

station_names = char(net_sites);
if N > 1
    [station_colors, ~] = plasma(N);
else
    station_colors = [1.0000 0.9176 0.5882];  % matches the old single-station OTT color
end

%% 5) Clean each station on its OWN timestamps (F_cleanStation)
% Steps, in order: (1) trim to the event window + any station overrides, (2) gap
% check (NaN, filler, timestamp jumps) -- station dropped if an internal gap is
% >= max_gap_minutes, (3) spike removal then the gap check again, (4) interpolate
% the remaining small gaps. Nothing is regridded or compared to another station
% until it has been cleaned. H decides keep/drop; Z follows H's decision.
SPIKE_THRESHOLD = 80000;  % flat threshold for H; also the filler threshold in the gap check

max_gap_min = Inf;
if isfield(E, 'max_gap_minutes') && ~isempty(E.max_gap_minutes)
    max_gap_min = E.max_gap_minutes;
end

t_cell = cell(N, 1);
H_cell = cell(N, 1);
infos  = cell(N, 1);
for k = 1:N
    d = data.(net_sites{k});
    h_k = sqrt(d.BX.^2 + d.BY.^2);
    [t_cell{k}, H_cell{k}, infos{k}] = F_cleanStation(d.datetime, h_k, E, net_sites{k}, ...
        struct('spike_threshold', SPIKE_THRESHOLD));
    if infos{k}.dropped
        fprintf("Dropping %s: %s\n", net_sites{k}, infos{k}.drop_reason);
    end
end

was_dropped = cellfun(@(s) s.dropped, infos);
log_sites = net_sites;  log_infos = infos;  log_dropped = was_dropped;  % kept for the station-tracking CSV
net_sites(was_dropped)        = [];
station_names(was_dropped, :) = [];
if N > 1; station_colors(was_dropped, :) = []; end
t_cell(was_dropped) = [];
H_cell(was_dropped) = [];
infos(was_dropped)  = [];
N = numel(net_sites);
if N == 0
    error("All %s stations were dropped for event %s.", network, E.id);
end
fprintf("Kept %d %s station(s) after cleaning: %s\n", N, network, strjoin(net_sites, ', '));

% Z: same trim, spike and interpolation steps, but no Hampel pass, and a gap in Z
% never drops a station (H decides that) -- Z gaps >= max_gap_minutes stay NaN.
tz_cell = cell(N, 1);
Z_cell  = cell(N, 1);
for k = 1:N
    d = data.(net_sites{k});
    [tz_cell{k}, Z_cell{k}] = F_cleanStation(d.datetime, d.BZ, E, net_sites{k}, ...
        struct('spike_threshold', z_threshold, 'hampel', false, 'keep_gappy', true));
end

%% 6) Place the cleaned stations on the event grid (F_placeOnEventGrid)
% One full-coverage grid from the event config (ingestion.start/end), not from
% any station; each station is NaN wherever it has no data, never extrapolated.
% Z is placed on exactly H's grid, leaving its long gaps NaN.
[t_interp, H_interp, grid_info] = F_placeOnEventGrid(t_cell, H_cell, E, network);
[~, Z_interp] = F_placeOnEventGrid(tz_cell, Z_cell, E, network, struct('t_grid', t_interp, 'limit_min', max_gap_min));
t = t_interp;
fprintf("Event grid: %s to %s, %g s cadence, %d points.\n", ...
    datestr(grid_info.grid_start), datestr(grid_info.grid_end), grid_info.cadence_s, grid_info.n_grid);

%% 7) Write horizontal + vertical field to CSV (processed output -> Data_local)
% Both written (not just H) so section 9's plots below -- and the
% standalone reload-from-CSV section at the end of this script -- can be
% regenerated without rerunning the cleaning pipeline above.
out_dir = fullfile(paths.processed_high_frequency_path, network);
if ~isfolder(out_dir); mkdir(out_dir); end
tag = extractBefore(E.id, 5);
tic
h_csv = fullfile(out_dir, sprintf("%s_%s_H.csv", tag, network));
F_woArrayData(t_interp, H_interp, station_names, char(h_csv)); toc
tic
z_csv = fullfile(out_dir, sprintf("%s_%s_Z.csv", tag, network));
F_woArrayData(t_interp, Z_interp, station_names, char(z_csv)); toc

%% 8) High-pass filter + plot + write CSV
maxT = E.hpf_max_period_s;
dt = seconds(t_interp(2) - t_interp(1));
n = 1;  % Butterworth filter order

% F_HPF (filtfilt) requires finite input throughout -- can't run across
% leading/trailing NaN from a station whose record starts late and/or
% ends early. Filter only each column's valid (non-NaN) span, wherever it
% falls -- NOT assumed to be a prefix starting at position 1 (that
% assumption silently corrupted late-starting stations the same way the
% H_interp/Z_interp placement bug above did; fixed alongside it
% 2026-08-19).
H_hpf = nan(size(H_interp));
for col = 1:N
    first_valid = find(~isnan(H_interp(:,col)), 1, 'first');
    last_valid = find(~isnan(H_interp(:,col)), 1, 'last');
    if isempty(first_valid); continue; end
    H_hpf(first_valid:last_valid, col) = F_HPF(maxT, dt, n, H_interp(first_valid:last_valid, col));
end

fig_dir = fullfile(paths.figure_root_paper, E.figure_subdir);
if ~isfolder(fig_dir); mkdir(fig_dir); end
figname = char(fullfile(fig_dir, sprintf("%s_Hhpf_%s", network, tag)));
F_plotH(t, H_hpf, station_colors, station_names, figname);

hhpf_csv = fullfile(out_dir, sprintf("%s_%s_Hhpf.csv", tag, network));
F_woArrayData(t_interp, H_hpf, station_names, char(hhpf_csv));
fprintf("HPF complete: %s, %s\n", h_csv, hhpf_csv);

%% 9) H and Z timeseries plot: single overlay (many stations) or stacked
% (few stations) -- stacked subplots become unreadably small once a
% network has more than a handful of stations, so switch to everything
% overlaid on one set of axes instead once N > 7.
close all;
if N > 7
    h_fname = char(fullfile(fig_dir, sprintf("%s_H_overlay_%s.png", network, tag)));
    z_fname = char(fullfile(fig_dir, sprintf("%s_Z_overlay_%s.png", network, tag)));
    [~] = F_geomagOverlayPlot(H_interp, t, station_names, station_colors, 'Horizontal Magnetic Field (nT)', h_fname);
    [~] = F_geomagOverlayPlot(Z_interp, t, station_names, station_colors, 'Vertical Magnetic Field (nT)', z_fname);
elseif N > 1
    h_stack_fname = char(fullfile(fig_dir, sprintf("%s_H_stacked_%s.png", network, tag)));
    z_stack_fname = char(fullfile(fig_dir, sprintf("%s_Z_stacked_%s.png", network, tag)));
    [~] = F_geomagStackedPlot(H_interp, t, station_names, station_colors, h_stack_fname);
    [~] = F_geomagStackedPlot(Z_interp, t, station_names, station_colors, z_stack_fname);
end

%% 10) VERIFY: each kept station's used span vs its cleaned input, and the gap rule
% Per kept station: the span actually placed on the grid, how far that falls short
% of the cleaned record (should be under a cadence or two -- anything bigger means
% the grid truncated the station), the longest internal gap after spike removal
% (must be < max_gap_minutes), samples interpolated, and any NaN inside the span.
% (H only; Z follows H's keep/drop and may legitimately keep long NaN gaps.)
fprintf("\n=== VERIFY %s %s: %d station(s) kept ===\n", E.id, network, N);
fprintf("%-6s  %-19s  %-19s  %12s  %10s  %12s\n", "site", "first valid", "last valid", "max gap (min)", "interp'd", "NaN in span");
verify_bad = false(1, N);
for col = 1:N
    fv = grid_info.first_valid(col);
    lv = grid_info.last_valid(col);
    if isnat(fv)
        fprintf("%-6s  (no valid data on grid)\n", net_sites{col});
        verify_bad(col) = true;
        continue
    end
    short_start = seconds(fv - t_cell{col}(1));      % cleaned record starts before its grid span?
    short_end   = seconds(t_cell{col}(end) - lv);    % cleaned record ends after its grid span?
    truncated = short_start > 2*grid_info.cadence_s || short_end > 2*grid_info.cadence_s;
    max_gap_here = infos{col}.max_gap_min_post;
    verify_bad(col) = truncated || (isfinite(max_gap_min) && max_gap_here >= max_gap_min) ...
        || grid_info.n_nan_inside(col) > 0;
    flag = ""; if verify_bad(col); flag = "  <-- CHECK"; end
    fprintf("%-6s  %-19s  %-19s  %12.1f  %10d  %12d%s\n", net_sites{col}, ...
        datestr(fv, 'yyyy-mm-dd HH:MM:SS'), datestr(lv, 'yyyy-mm-dd HH:MM:SS'), ...
        max_gap_here, infos{col}.n_interpolated, grid_info.n_nan_inside(col), flag);
end
if any(verify_bad)
    warning("VERIFY: %d station(s) truncated, over the gap rule, or with NaN inside their span: %s", ...
        sum(verify_bad), strjoin(net_sites(verify_bad), ', '));
else
    fprintf("VERIFY OK: no station truncated, every max internal gap < %g min, no NaN inside any span.\n", max_gap_min);
end

%% 11) STATION TRACKING CSV (kept + dropped stations for this event/network)
% One row per station that went through cleaning, with the reason for any drop;
% rows for this network are refreshed, other networks' rows are left alone.
log_first = NaT(numel(log_sites), 1);
log_last  = NaT(numel(log_sites), 1);
log_first(~log_dropped) = grid_info.first_valid;
log_last(~log_dropped)  = grid_info.last_valid;
F_updateStationLog(paths, E, string(network), log_sites, log_infos, ~log_dropped, log_first, log_last);
