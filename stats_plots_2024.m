%% stats_plots_2024.m
% Loads the 2024 storm wavelet power stats/timeseries written by
% Run_Wavelet_Analysis.py, plus the Dst index, and produces the storm's
% power-vs-latitude / power-vs-time / power-vs-Dst plots. Mirrors
% stats_plots_1989.m's structure and reuses its shared helper functions
% (F_purpleRedColormap, F_snapshotPowerLatDst, F_powerTimeLatHeatmap,
% etc. -- all event-agnostic already). Two real differences from 1989:
%   - 77 stations (vs 13) -- station geo/mag latitude is pulled
%     programmatically from united_data.mat (same file Map_Events.m
%     uses) for whichever stations survived cleaning, rather than
%     hardcoded.
%   - Dst source is Dst2024.mat (cached locally), not the 1982-2000 text
%     file -- matches Dst_check.m's year-based routing.
clc; clear all; close all;
addpath matlab_functions/
paths = F_loadPaths();
E = F_loadEvents('2024-05-11');
tag = '2024';
fprintf('Paths and event loaded: %s\n', E.description);

%% Station metadata (geo/mag latitude), pulled from united_data.mat for
% whichever stations actually survived cleaning (determined below, once
% the power stats CSV is loaded -- that CSV's row names are the
% definitive final station list, since some sites present in
% united_data.mat were dropped for gaps/exclusion during cleaning).
[matpath, matfname] = F_findLatestUnitedData(paths.processed_high_frequency_path, E.united_data_fname);
S = load(matpath);
data = S.data;
fprintf('...loaded %s (station metadata source)\n', matfname);

%% Load Dst (2024 uses the cached Dst2024.mat, not the 1982-2000 text file)
dst_matfile = fullfile(paths.processed_dst_index_path, 'Dst2024.mat');
Sd = load(dst_matfile);
dst_time_all = Sd.dst_time;
if ~isdatetime(dst_time_all)
    dst_time_all = datetime(dst_time_all);
end
dst_obs = Sd.Dst;

dst_window = E.dst_window;
dwin_mask = (dst_time_all >= datetime(dst_window.start)) & (dst_time_all <= datetime(dst_window.end));
dateRange = dst_time_all(dwin_mask);
Dst = dst_obs(dwin_mask);
fprintf('Loaded Dst: %d hourly points, %s to %s\n', numel(Dst), dateRange(1), dateRange(end));

%% ---- USER SETTINGS: snapshot times ----
% Edit these to explore different points in the storm. First guess based
% on the Dst curve: A=quiet baseline, B=sudden commencement, C=main-phase
% minimum (-406nT @ 2024-05-11 02:00, the "Gannon storm"), D=recovery
% (still not fully recovered by window's end). Must fall within
% dst_window (2024-05-06 to 2024-05-16) to land inside dateRange below.
snapshot_times = struct( ...
    'A',    datetime(2024, 5, 7,  7, 0, 0), ...
    'B',    datetime(2024, 5, 10, 20, 0, 0), ...
    'C',    datetime(2024, 5, 11, 2,  0, 0), ...
    'D',    datetime(2024, 5, 15, 12, 0, 0) ...
);

% Magnetic latitude y-axis limits [min max] (deg) for the power vs MLat
% snapshot plots -- the same limits are used for every snapshot so they are
% directly comparable. Leave [] to derive them from this event's station
% latitudes (rounded outward to 5 deg).
snapshot_mlat_ylim = [45 90];

%% Dst timeseries plot (doesn't depend on period_tag -- made once)
dst_out_dir = fullfile(paths.figure_root_paper, E.figure_subdir, 'stats_plots');
if ~isfolder(dst_out_dir), mkdir(dst_out_dir); end
[~, xticks_dst] = F_plotDst(dateRange, Dst, fullfile(dst_out_dir, sprintf('%s_Dst_timeseries.png', tag)));

%% period_tag, matching Run_Wavelet_Analysis.py's naming convention
max_period_s = E.wavelet.max_period_s;
if max_period_s >= 3600
    period_tag = sprintf('maxT%ghr', max_period_s/3600);
else
    period_tag = sprintf('maxT%gmin', max_period_s/60);
end
fprintf('\n=== %s ===\n', period_tag);

out_dir = fullfile(paths.figure_root_paper, E.figure_subdir, 'stats_plots', period_tag);
if ~isfolder(out_dir), mkdir(out_dir); end

%% Load power stats (integrated power + top-3 peaks per station)
stats_path = fullfile(paths.processed_data_root, 'WO_data', 'power_stats', ...
    sprintf('%s_storm_power_stats_%s.csv', tag, period_tag));
stats_tbl = readtable(stats_path, 'ReadRowNames', true);
stations = stats_tbl.Properties.RowNames;
N = numel(stations);
fprintf('Loaded power stats for %d stations.\n', N);

integrated_power = stats_tbl.integrated_power;
max_value_1 = stats_tbl.max_value_1; max_value_2 = stats_tbl.max_value_2; max_value_3 = stats_tbl.max_value_3;
max_time_1  = stats_tbl.max_time_1;  max_time_2  = stats_tbl.max_time_2;  max_time_3  = stats_tbl.max_time_3;

% mag_lat = -cdm_lat: `data` stores cdm_lat negative (matches
% Map_Events.m/F_StationStereoMap's convention); flip sign here to keep
% this script's own convention positive, matching stats_plots_1989.m
% (higher value = more poleward).
station_mag_lats = zeros(N,1);
for i = 1:N
    station_mag_lats(i) = -data.(stations{i}).cdm_lat;
end

% Dark purple -> hot red colormap, assigned by magnetic latitude rank
% (same F_purpleRedColormap used by the station map, F_StationStereoMap,
% so station colors match across the map and every stats plot)
[~, lat_order] = sort(station_mag_lats, 'descend');
colors_by_lat_rank = F_purpleRedColormap(N);
station_colors = zeros(N, 3);
station_colors(lat_order, :) = colors_by_lat_rank;

%% Plot: integrated storm power vs magnetic latitude
fig1 = figure;
hold on
for i = 1:N
    plot(integrated_power(i), station_mag_lats(i), 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', station_colors(i,:), 'MarkerEdgeColor', station_colors(i,:))
end
grid on
set(gca, 'XScale', 'log');
ax = gca; ax.FontSize = 15;
ylabel('Magnetic Latitude (Degrees)', 'FontSize', 20);
xlabel('Storm-window Integrated Power (s nT^2)', 'FontSize', 20);
fname = fullfile(out_dir, sprintf('%s_lat_vs_energy.png', tag));
saveas(fig1, fname); disp([fname ' saved.']);

%% Load per-station power timeseries and interpolate each directly to
% Dst's hourly time base (skips the old two-stage "common high-res grid
% then Dst grid" interpolation -- unnecessary now that every plot below
% is made at Dst's hourly cadence anyway). Moved ahead of the snapshot
% plot below since it needs power_ts_Dstinterp.
ts_dir = fullfile(paths.processed_data_root, 'WO_data', 'power_timeseries');
ts_files = dir(fullfile(ts_dir, sprintf('%s_*_storm_power_timeseries_%s.csv', tag, period_tag)));

station_power_lookup = struct();
for f = 1:numel(ts_files)
    ts_tbl = readtable(fullfile(ts_files(f).folder, ts_files(f).name));
    ts_time = datetime(ts_tbl.time);
    col_names = ts_tbl.Properties.VariableNames;
    for c = 1:numel(col_names)
        cn = col_names{c};
        if endsWith(cn, '_scale_avg_power')
            station_code = erase(cn, '_scale_avg_power');
            station_power_lookup.(station_code) = struct('time', ts_time, 'power', ts_tbl.(cn));
        end
    end
end

power_ts_Dstinterp = nan(numel(dateRange), N);
for i = 1:N
    s = stations{i};
    if ~isfield(station_power_lookup, s)
        warning('No power timeseries found for station %s (%s) -- leaving NaN.', s, period_tag);
        continue
    end
    sp = station_power_lookup.(s);
    power_ts_Dstinterp(:,i) = interp1(sp.time, sp.power, dateRange, 'linear');
end
disp('Interpolated all stations'' power timeseries to Dst''s hourly time base.')

%% Plot: times of top-3 power peaks vs magnitude, per station
% Combined snapshot comparison: wide Dst timeline (top) + magnetic
% latitude vs storm power at each snapshot (bottom), one connector line
% per snapshot. Loops over however many snapshot_times are defined above
% (not fixed at 3) -- see F_snapshotPowerLatDst.
% A/D share a hue (light grey) with A fatter, D thinner; B/C share a hue
% (black) with C fatter -- overrides the default per-snapshot chronological
% gradient. Add/remove entries here to restyle; any label not listed keeps
% its default gradient color/width. (Same override as stats_plots_1989.m.)
snapshot_style_override = struct( ...
    'A', struct('Color', [0.75 0.75 0.75], 'LineWidth', 3), ...
    'B', struct('Color', [0 0 0],          'LineWidth', 1.75, 'LineStyle', '--'), ...
    'C', struct('Color', [0 0 0],          'LineWidth', 2.5), ...
    'D', struct('Color', [0.75 0.75 0.75], 'LineWidth', 1.25, 'LineStyle', '--') ...
);

snapshot_fname = fullfile(out_dir, sprintf('%s_snapshot_power_vs_maglat_dst.png', tag));
F_snapshotPowerLatDst(dateRange, Dst, snapshot_times, power_ts_Dstinterp, station_mag_lats, station_colors, snapshot_fname, ...
    'StyleOverride', snapshot_style_override);

%% Plot: power vs magnetic latitude snapshots (see snapshot_times above)
% Dst timeseries with a plain grey vertical line at each snapshot time --
% see F_plotDstSnapshotLines.
dst_snapshot_fname = fullfile(out_dir, sprintf('%s_Dst_snapshot_lines.png', tag));
F_plotDstSnapshotLines(dateRange, Dst, snapshot_times, dst_snapshot_fname);

snapshot_labels = fieldnames(snapshot_times);
for k = 1:numel(snapshot_labels)
    lbl = snapshot_labels{k};
    t_k = snapshot_times.(lbl);
    if t_k < dateRange(1) || t_k > dateRange(end)
        warning('snapshot_times.%s (%s) falls outside dateRange (%s to %s) -- skipping.', ...
            lbl, t_k, dateRange(1), dateRange(end));
        continue
    end
    figname = fullfile(out_dir, sprintf('%s_power_vs_maglat_%s.png', tag, lbl));
    F_stormPowerMagLatSP(figname, power_ts_Dstinterp, station_mag_lats, station_colors, dateRange, t_k, ...
        'YLim', snapshot_mlat_ylim);
end

%% Plot: storm power timeseries, all stations
fname = fullfile(out_dir, sprintf('%s_Bpower_timeseries.png', tag));
F_powerTSplot(dateRange, power_ts_Dstinterp, station_colors, fname)

%% Plot: heatmap of storm power vs latitude vs time
fname2 = fullfile(out_dir, sprintf('%s_BpowerTimeLatHeatmap.png', tag));
failure_times = F_loadFailureTimes(E.id); % grid-failure markers (config/event_landmarks_geo_info_with_cdm.csv)
F_powerTimeLatHeatmap(dateRange, power_ts_Dstinterp, station_mag_lats, fname2, ...
    'Colormap', @F_whiteYellowRedColormap, ...
    'CLim', [-0.01, 5], ...
    'YTickEvery', 10, ...
    'DstOverlay', Dst, ...
    'DstYLim', [-600 70], ...
    'XTickVals', xticks_dst, ...
    'EventTimes', failure_times);

%% Movie: Dst & power timeseries versus mag latitude
vidname = fullfile(out_dir, sprintf('%s_power_maglat_time.mp4', tag));
F_stormPowerIndexMovie(vidname, power_ts_Dstinterp, station_mag_lats, ...
    station_colors, dateRange, Dst, 'Dst');

%% Plot: max power vs Dst, colored by station
figname = fullfile(out_dir, sprintf('%s_dst_vs_power.png', tag));
F_power_vs_Dst(station_mag_lats, station_colors, power_ts_Dstinterp, Dst, figname, true)

close all
disp('Done.')
