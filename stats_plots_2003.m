%% stats_plots_2003.m
% Loads the 2003 storm wavelet power stats/timeseries written by
% Run_Wavelet_Analysis.py, plus the Dst index, and produces the storm's
% power-vs-latitude / power-vs-time / power-vs-Dst plots. Mirrors
% stats_plots_2024.m's structure and reuses the same event-agnostic
% helper functions. Two real differences from 2024:
%   - Dst source is Dst_2000-2024.txt (era '2000s'), not a cached
%     Dst2024.mat -- matches Dst_check.m's year-based routing (2003
%     falls in the 2000-2024 file, same text-file pattern as 1989's
%     1982-2000 file, just a different era/filename).
%   - Six snapshot times instead of four -- 2003 was a double-dip storm
%     (two separate main-phase minima, Oct 30 00:00 and Oct 30 22:00),
%     unlike 2024's single Gannon-storm minimum.
clc; clear all; close all;
addpath matlab_functions/
paths = F_loadPaths();
E = F_loadEvents('2003-10-29');
tag = '2003';
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

%% Load Dst (2003 falls in the 2000-2024 text file, era '2000s')
dst_file = fullfile(paths.processed_dst_index_path, 'Dst_2000-2024.txt');
[dst_ts_raw, dst_obs] = F_readDstdata(dst_file, '2000s');
if isnumeric(dst_ts_raw)
    dst_time_all = datetime(dst_ts_raw, 'ConvertFrom', 'datenum');
else
    dst_time_all = dst_ts_raw;
end

% Display window is intentionally wider than E.dst_window (which stays
% narrow -- Oct 29 to Nov 1 -- since Run_Wavelet_Analysis.py uses it as
% the actual integrated-power/peak analysis window and that shouldn't
% change). This script's dateRange is just for context/display across
% every plot below, so it uses its own explicit range instead, as wide as
% the ingestion window allows (2003-10-24 to 2003-11-02).
display_window_start = datetime(2003, 10, 24, 0, 0, 0);
display_window_end   = datetime(2003, 11, 2,  0, 0, 0);
dwin_mask = (dst_time_all >= display_window_start) & (dst_time_all <= display_window_end);
dateRange = dst_time_all(dwin_mask);
Dst = dst_obs(dwin_mask);
fprintf('Loaded Dst: %d hourly points, %s to %s\n', numel(Dst), dateRange(1), dateRange(end));

%% ---- USER SETTINGS: snapshot times ----
% Edit these to explore different points in the storm. Starting proposal
% based on the actual Dst curve (double-dip structure -- two separate
% main-phase minima, not one): A=quiet baseline, B=sudden commencement,
% C=first main-phase minimum (-353nT @ Oct 30 00:00), D=brief inter-dip
% recovery (-97nT @ Oct 30 17:00), E=second, deeper main-phase minimum
% (-383nT @ Oct 30 22:00), F=late recovery. Must fall within the display
% window (2003-10-24 to 2003-11-02) to land inside dateRange above.
snapshot_times = struct( ...
    'A',    datetime(2003, 10, 26, 10,  0, 0), ...
    'B',    datetime(2003, 10, 29, 9,  0, 0), ...
    'C',    datetime(2003, 10, 30, 0,  0, 0), ...
    'D',    datetime(2003, 10, 30, 17, 0, 0), ...
    'E',    datetime(2003, 10, 30, 22, 0, 0), ...
    'F',    datetime(2003, 11, 1, 23, 0, 0) ...
);

% Magnetic latitude y-axis limits [min max] (deg) for the power vs MLat
% snapshot plots -- the same limits are used for every snapshot so they are
% directly comparable. Leave [] to derive them from this event's station
% latitudes (rounded outward to 5 deg).
snapshot_mlat_ylim = [];

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
% this script's own convention positive, matching stats_plots_1989.m /
% stats_plots_2024.m (higher value = more poleward).
station_mag_lats = zeros(N,1);
for i = 1:N
    station_mag_lats(i) = -data.(stations{i}).cdm_lat;
end

% Purple(high lat)->red(low lat) on the FIXED 47-90 deg scale shared
% across all 3 events (F_magLatColors) -- matches Map_Events.m/
% F_StationStereoMap.m exactly, station by station, not just the same
% palette. Replaces the old per-event rank-based assignment.
station_colors = F_magLatColors(station_mag_lats);

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
% -- see F_snapshotPowerLatDst.
% Extends stats_plots_2024.m's A/D-grey, B/C-black pattern to the six
% snapshots above: A/F bookend the storm (grey, baseline/late-recovery);
% B/D are the two transition points (black dashed, thinner); C/E are the
% two main-phase minima (black solid, E thicker since it's the deeper of
% the two dips). Any label not listed keeps the default gradient
% color/width -- adjust freely once you've picked your own snapshot times.
snapshot_style_override = struct( ...
    'A', struct('Color', [0.75 0.75 0.75], 'LineWidth', 3), ...
    'B', struct('Color', [0 0 0],          'LineWidth', 1.5,  'LineStyle', '--'), ...
    'C', struct('Color', [0 0 0],          'LineWidth', 2), ...
    'D', struct('Color', [0 0 0],          'LineWidth', 1.5,  'LineStyle', '--'), ...
    'E', struct('Color', [0 0 0],          'LineWidth', 2.5), ...
    'F', struct('Color', [0.75 0.75 0.75], 'LineWidth', 1.25) ...
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
    'YTickEvery', 5, ...
    'DstOverlay', Dst, ...
    'DstYLim', [-600 70], ...
    'XTickVals', xticks_dst, ...
    'EventTimes', failure_times);

%% Movie: Dst & power timeseries versus mag latitude
vidname = fullfile(out_dir, sprintf('%s_power_maglat_time.mp4', tag));
F_stormPowerIndexMovie(vidname, power_ts_Dstinterp, station_mag_lats, station_colors, dateRange, Dst, 'Dst');

%% Plot: max power vs Dst, colored by station
figname = fullfile(out_dir, sprintf('%s_dst_vs_power.png', tag));
F_power_vs_Dst(station_mag_lats, station_colors, power_ts_Dstinterp, Dst, figname, true)

close all
disp('Done.')
