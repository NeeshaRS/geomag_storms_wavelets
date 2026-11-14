function fig = F_plotDstSnapshotLines(dateRange, Dst, snapshot_times, fname)
% F_plotDstSnapshotLines  Dst timeseries with a plain grey vertical line
%   at each snapshot time. Same width/height proportions as
%   F_snapshotPowerLatDst's top Dst panel (10in wide, 3.5in tall -- that
%   function's 10x10in figure with the Dst panel spanning 35/100 rows),
%   but simplified: every snapshot line is a plain grey (0.5 0.5 0.5),
%   LineWidth 1 line, no per-snapshot chronological gradient or
%   per-label style overrides.
%
% INPUTS:
%   dateRange       : [T x 1] datetime, Dst's hourly time base
%   Dst             : [T x 1] hourly Dst values, matching dateRange
%   snapshot_times  : struct, field name = label (e.g. 'A', 'onset', ...),
%                     value = datetime scalar. Any number of fields --
%                     sorted chronologically internally.
%   fname           : output file path
%
% OUTPUT:
%   fig             : figure handle
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

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

% ---- Figure: same width/height as F_snapshotPowerLatDst's Dst panel
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [0 10 10 3.5]);
ax = axes(fig);
plot(ax, dateRange, Dst, 'k', 'LineWidth', 2);
hold(ax, 'on');
yl = ylim(ax);
for k = 1:numel(labels)
    plot(ax, [times(k) times(k)], yl, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    text(ax, times(k), yl(2), labels{k}, 'Color', [0.5 0.5 0.5], 'FontWeight', 'bold', ...
        'FontSize', 14, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
end
ylim(ax, yl);
grid(ax, 'on'); box(ax, 'on');
xlabel(ax, 'Date', 'FontSize', 20);
ylabel(ax, 'Dst (nT)', 'FontSize', 20);
xlim(ax, [dateRange(1) dateRange(end)]);
ax.FontSize = 15;

saveas(fig, fname);
disp([fname ' saved.']);

end
