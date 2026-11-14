%% Greenland_event_plotting.m
% Consolidates Greenland_variometers_{1989,2003}.m into one registry-driven
% script. Unlike IMAGE, Greenland's BX/BY are already local-magnetic H/D (or
% H/E) components -- H is BX directly, no vector combination needed. Station
% metadata (names, lat/lon/cdm_lat) comes from the data struct, not a
% per-storm hardcoded list.
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

%% 2) SELECT EVENT
event_idx = 3;  % index into `events`; see events(k).id -- 2 = 2003-10-29
E = events(event_idx);
fprintf("\n=== Greenland plotting for event %d/%d: %s ===\n%s\n\n", event_idx, numel(events), E.id, E.description);

%% 3) LOAD DATA (most recent united_data.mat for this event)
[matpath, matfname] = F_findLatestUnitedData(paths.processed_high_frequency_path, E.united_data_fname);
S = load(matpath);
data = S.data;
fprintf("...loaded %s\n", matfname);

%% 4) SELECT + ORDER Greenland/DTU-sourced stations (by decreasing cdm_lat)
sites = fieldnames(data);
is_dtu = false(size(sites));
cdm_lats = nan(size(sites));
for k = 1:numel(sites)
    d = data.(sites{k});
    if isfield(d, 'source') && string(d.source) == "DTU"
        is_dtu(k) = true;
        if isfield(d, 'cdm_lat'); cdm_lats(k) = d.cdm_lat; end
    end
end
gl_sites = sites(is_dtu);
gl_cdm_lats = cdm_lats(is_dtu);

% Defensive filter in case this united_data.mat predates the current
% exclude_sites list in events.json (matches Map_Events.m's same check).
if isfield(E, 'exclude_sites') && ~isempty(E.exclude_sites)
    keep = ~ismember(gl_sites, E.exclude_sites);
    gl_sites = gl_sites(keep);
    gl_cdm_lats = gl_cdm_lats(keep);
end

[~, order] = sort(gl_cdm_lats, 'descend', 'MissingPlacement', 'last');
gl_sites = gl_sites(order);
N = numel(gl_sites);
fprintf("Found %d Greenland/DTU stations: %s\n", N, strjoin(gl_sites, ', '));

station_names = char(gl_sites);
[station_colors, ~] = plasma(N);

%% 5) Clean each station on its OWN timestamps (F_cleanStation)
% Steps, in order: (1) trim to the event window + any station overrides, (2) gap
% check (NaN, filler, timestamp jumps) -- station dropped if an internal gap is
% >= max_gap_minutes, (3) spike removal then the gap check again, (4) interpolate
% the remaining small gaps. Nothing is regridded or compared to another station
% until it has been cleaned.
SPIKE_THRESHOLD = 90000;  % DTU flat threshold; also the filler threshold in the gap check

max_gap_min = Inf;
if isfield(E, 'max_gap_minutes') && ~isempty(E.max_gap_minutes)
    max_gap_min = E.max_gap_minutes;
end

t_cell = cell(N, 1);
y_cell = cell(N, 1);
infos  = cell(N, 1);
for k = 1:N
    d = data.(gl_sites{k});
    [t_cell{k}, y_cell{k}, infos{k}] = F_cleanStation(d.datetime, d.BX, E, gl_sites{k}, ...
        struct('spike_threshold', SPIKE_THRESHOLD));
    if infos{k}.dropped
        fprintf("Dropping %s: %s\n", gl_sites{k}, infos{k}.drop_reason);
    end
end

was_dropped = cellfun(@(s) s.dropped, infos);
log_sites = gl_sites;  log_infos = infos;  log_dropped = was_dropped;  % kept for the station-tracking CSV
gl_sites(was_dropped)        = [];
station_names(was_dropped,:) = [];
station_colors(was_dropped,:) = [];
t_cell(was_dropped)          = [];
y_cell(was_dropped)          = [];
infos(was_dropped)           = [];
N = numel(gl_sites);
fprintf("Kept %d Greenland/DTU station(s) after cleaning: %s\n", N, strjoin(gl_sites, ', '));

%% 6) Place the cleaned stations on the event grid (F_placeOnEventGrid)
% One full-coverage grid from the event config (ingestion.start/end), not from
% any station; each station is NaN wherever it has no data, never extrapolated.
[t_interp, H_interp, grid_info] = F_placeOnEventGrid(t_cell, y_cell, E, "DTU");
t = t_interp;
fprintf("Event grid: %s to %s, %g s cadence, %d points.\n", ...
    datestr(grid_info.grid_start), datestr(grid_info.grid_end), grid_info.cadence_s, grid_info.n_grid);

%% 7) High-pass filter + plot + write CSV
maxT = E.hpf_max_period_s;
dt = seconds(t_interp(2) - t_interp(1));
n = 1;  % Butterworth filter order

% F_HPF (filtfilt) requires finite input throughout -- can't run across
% leading/trailing NaN from a station whose record starts late and/or
% ends early. Filter only each column's valid (non-NaN) span, wherever it
% falls -- NOT assumed to be a prefix starting at position 1 (same fix as
% Network_event_plotting.m, 2026-08-19).
H_hpf = nan(size(H_interp));
for col = 1:N
    first_valid = find(~isnan(H_interp(:,col)), 1, 'first');
    last_valid = find(~isnan(H_interp(:,col)), 1, 'last');
    if isempty(first_valid); continue; end
    H_hpf(first_valid:last_valid, col) = F_HPF(maxT, dt, n, H_interp(first_valid:last_valid, col));
end

out_dir = fullfile(paths.processed_high_frequency_path, "Greenland");
if ~isfolder(out_dir); mkdir(out_dir); end
tag = extractBefore(E.id, 5);
h_csv = fullfile(out_dir, sprintf("%s_Greenland_H.csv", tag));
F_woArrayData(t_interp, H_interp, station_names, char(h_csv));
hhpf_csv = fullfile(out_dir, sprintf("%s_Greenland_Hhpf.csv", tag));
F_woArrayData(t_interp, H_hpf, station_names, char(hhpf_csv));
fprintf("HPF complete: %s, %s\n", h_csv, hhpf_csv);

%% 8) Plot the high-pass-filtered horizontal field for each station
fig_dir = fullfile(paths.figure_root_paper, E.figure_subdir);
if ~isfolder(fig_dir); mkdir(fig_dir); end
figname = char(fullfile(fig_dir, sprintf("Greenland_Hhpf_%s", extractBefore(E.id, 5))));
F_plotH(t_interp, H_hpf, station_colors, station_names, figname);

%% 9) H timeseries plot: single overlay (many stations) or stacked (few
% stations) -- stacked subplots become unreadably small once a network
% has more than a handful of stations, so switch to everything overlaid
% on one set of axes instead once N > 7.
if N > 7
    fname_overlay = char(fullfile(fig_dir, sprintf("Greenland_H_overlay_%s.png", extractBefore(E.id, 5))));
    [~] = F_geomagOverlayPlot(H_interp, t, station_names, station_colors, 'Horizontal Magnetic Field (nT)', fname_overlay);
elseif N > 1
    stack_fname = char(fullfile(fig_dir, sprintf("Greenland_H_stacked_%s.png", extractBefore(E.id, 5))));
    [~] = F_geomagStackedPlot(H_interp, t, station_names, station_colors, stack_fname);
end

%% 10) VERIFY: each kept station's used span vs its cleaned input, and the gap rule
% Per kept station: the span actually placed on the grid, how far that falls short
% of the cleaned record (should be under a cadence or two -- anything bigger means
% the grid truncated the station), the longest internal gap after spike removal
% (must be < max_gap_minutes), samples interpolated, and any NaN inside the span.
fprintf("\n=== VERIFY %s Greenland: %d station(s) kept ===\n", E.id, N);
fprintf("%-6s  %-19s  %-19s  %12s  %10s  %12s\n", "site", "first valid", "last valid", "max gap (min)", "interp'd", "NaN in span");
verify_bad = false(1, N);
for col = 1:N
    fv = grid_info.first_valid(col);
    lv = grid_info.last_valid(col);
    if isnat(fv)
        fprintf("%-6s  (no valid data on grid)\n", gl_sites{col});
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
    fprintf("%-6s  %-19s  %-19s  %12.1f  %10d  %12d%s\n", gl_sites{col}, ...
        datestr(fv, 'yyyy-mm-dd HH:MM:SS'), datestr(lv, 'yyyy-mm-dd HH:MM:SS'), ...
        max_gap_here, infos{col}.n_interpolated, grid_info.n_nan_inside(col), flag);
end
if any(verify_bad)
    warning("VERIFY: %d station(s) truncated, over the gap rule, or with NaN inside their span: %s", ...
        sum(verify_bad), strjoin(gl_sites(verify_bad), ', '));
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
F_updateStationLog(paths, E, "DTU", log_sites, log_infos, ~log_dropped, log_first, log_last);
