function fig = F_snapshotPowerLatDst(dateRange, Dst, snapshot_times, power_ts, station_mag_lats, station_colors, fname, varargin)
% F_snapshotPowerLatDst  Two-panel snapshot-comparison figure.
%   Top panel: wide Dst timeseries, with a vertical line at each snapshot
%   time. Bottom panel: magnetic latitude vs storm power at each snapshot
%   time, one connector line per snapshot threading through all stations
%   (sorted by latitude), with per-station colored markers on top.
%
%   Snapshot lines (both the Dst vertical lines and the mag-lat-vs-power
%   connector lines) are colored on a black -> light-grey gradient in
%   chronological order (earliest = darkest + thickest), so a given
%   snapshot's Dst marker and its power curve are visually paired without
%   needing a legend.
%
% INPUTS:
%   dateRange       : [T x 1] datetime, Dst's hourly time base
%   Dst             : [T x 1] hourly Dst values, matching dateRange
%   snapshot_times  : struct, field name = label (e.g. 'A', 'onset', ...),
%                     value = datetime scalar. Any number of fields --
%                     sorted chronologically internally, not assumed to be
%                     any fixed count.
%   power_ts        : [T x N] per-station power, rows matching dateRange,
%                     columns matching station_mag_lats/station_colors
%   station_mag_lats: [N x 1] magnetic latitude per station
%   station_colors  : [N x 3] RGB per station (same order as station_mag_lats)
%   fname           : output file path
%
% NAME-VALUE (optional)
%   'StyleOverride' : struct, field name = snapshot label, value = struct
%     with optional .Color ([1x3] RGB), .LineWidth (scalar), and/or
%     .LineStyle (e.g. '--') -- overrides that snapshot's default
%     chronological-gradient style.
%     E.g. to make two out-of-order snapshots share a hue:
%       struct('A', struct('Color',[0.75 0.75 0.75], 'LineWidth',3), ...
%              'D', struct('Color',[0.75 0.75 0.75], 'LineWidth',1.25))

p = inputParser;
p.addParameter('StyleOverride', struct(), @isstruct);
p.parse(varargin{:});
style_override = p.Results.StyleOverride;

% ---- Sort snapshots chronologically (struct field order isn't guaranteed to be)
labels = fieldnames(snapshot_times);
times = NaT(numel(labels), 1);
for i = 1:numel(labels)
    times(i) = snapshot_times.(labels{i});
end
[times, sort_idx] = sort(times);
labels = labels(sort_idx);

% ---- Drop snapshots outside dateRange
in_range = times >= dateRange(1) & times <= dateRange(end);
if any(~in_range)
    warning('%d snapshot time(s) fall outside dateRange (%s to %s) -- skipping: %s', ...
        sum(~in_range), dateRange(1), dateRange(end), strjoin(labels(~in_range), ', '));
end
times = times(in_range);
labels = labels(in_range);
n = numel(labels);

% ---- Per-snapshot line style: black (earliest, thickest) -> grey (latest, thinnest)
grey_start = [0 0 0];
grey_end   = [0.75 0.75 0.75];
if n == 1
    snap_colors = grey_start;
else
    frac = linspace(0, 1, n)';
    snap_colors = grey_start + frac .* (grey_end - grey_start);
end
snap_linewidths = linspace(3, 1.25, n);
snap_linestyles = repmat({'-'}, n, 1);

% ---- Apply any per-label style overrides
for k = 1:n
    if isfield(style_override, labels{k})
        s = style_override.(labels{k});
        if isfield(s, 'Color'),     snap_colors(k,:)   = s.Color;     end
        if isfield(s, 'LineWidth'), snap_linewidths(k)  = s.LineWidth; end
        if isfield(s, 'LineStyle'), snap_linestyles{k}  = s.LineStyle; end
    end
end

% ---- Station order for the connector line (fixed across all snapshots)
[mag_lat_sorted, lat_order] = sort(station_mag_lats(:));
colors_sorted = station_colors(lat_order, :);

% ---- Power at each snapshot (nearest hourly sample), all stations
power_by_snap = nan(n, numel(mag_lat_sorted));
for k = 1:n
    [~, idx] = min(abs(datenum(dateRange) - datenum(times(k))));
    power_by_snap(k, :) = power_ts(idx, lat_order);
end

% ---- Figure: wide Dst panel on top (matches F_plotDst's width), snapshot
% panel below -- 35%/65% height split via a 100-row grid, since
% tiledlayout's tile spans are integer row counts, not percentages.
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [0 10 10 10]);
tlo = tiledlayout(fig, 100, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---- Top panel: Dst, with a vertical line + label per snapshot
ax1 = nexttile(tlo, [35 1]);
plot(ax1, dateRange, Dst, 'k', 'LineWidth', 2);
hold(ax1, 'on');
yl = ylim(ax1);
for k = 1:n
    plot(ax1, [times(k) times(k)], yl, snap_linestyles{k}, 'Color', snap_colors(k,:), 'LineWidth', snap_linewidths(k));
    text(ax1, times(k), yl(2), labels{k}, 'Color', snap_colors(k,:), 'FontWeight', 'bold', ...
        'FontSize', 14, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
end
ylim(ax1, yl);
grid(ax1, 'on'); box(ax1, 'on');
xlabel(ax1, 'Date', 'FontSize', 20);
ylabel(ax1, 'Dst (nT)', 'FontSize', 20);
xlim(ax1, [dateRange(1) dateRange(end)]);
ax1.FontSize = 15;

% ---- Bottom panel: magnetic latitude vs power, one connector line per
% snapshot (drawn first) with per-station markers on top (drawn last, so
% they're never hidden under a later line)
ax2 = nexttile(tlo, [65 1]);
hold(ax2, 'on');
for k = 1:n
    valid = ~isnan(power_by_snap(k,:));
    plot(ax2, power_by_snap(k,valid), mag_lat_sorted(valid), snap_linestyles{k}, 'Color', snap_colors(k,:), 'LineWidth', snap_linewidths(k));
end
[~, top_idx] = max(mag_lat_sorted);
for k = 1:n
    scatter(ax2, power_by_snap(k,:), mag_lat_sorted, 70, colors_sorted, 'filled', 'MarkerEdgeColor', 'k');
    % text(ax2, power_by_snap(k, top_idx), mag_lat_sorted(top_idx) + 2, labels{k}, ...
    %     'Color', snap_colors(k,:), 'FontWeight', 'bold', 'FontSize', 14, 'HorizontalAlignment', 'center');
end
set(ax2, 'XScale', 'log');
grid(ax2, 'on'); box(ax2, 'on');
xlabel(ax2, 'Storm Power (nT^2)', 'FontSize', 20);
ylabel(ax2, 'Magnetic Latitude (Degrees)', 'FontSize', 20);
ax2.FontSize = 15;

% ---- Save
saveas(fig, fname);
disp([fname ' saved.']);

end
