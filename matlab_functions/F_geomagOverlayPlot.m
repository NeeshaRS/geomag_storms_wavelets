function [magplot] = F_geomagOverlayPlot(magData, time, station_names, station_colors, ylabel_str, fname)
% F_geomagOverlayPlot  All stations' timeseries overlaid on one set of
% axes, color-coded, with a horizontal legend below the plot.
%
% More readable than F_geomagStackedPlot once a network has many stations
% -- stacked subplots become unreadably small (see Network_event_plotting.m
% / Greenland_event_plotting.m's N>7 threshold for which one gets used).
%
% INPUTS:
% magData = [T x N] array, one column per station
% time = [T x 1] datetime
% station_names = char array or cellstr, one row/name per station
% station_colors = [N x 3] RGB, one row per station
% ylabel_str = y-axis label string (e.g. 'Horizontal Magnetic Field (nT)')
%
% fname (optional) = file path to save the figure to. If omitted, the
% figure is created but not saved -- meant for interactive use; in a
% non-interactive `matlab -batch` run the figure is otherwise lost when
% the session exits.

N = size(magData, 2);

magplot = figure('Units', 'inches', 'Position', [0 10 10 6], 'Color', 'w');
hold on;
for i = 1:N
    plot(time, magData(:,i), 'Color', station_colors(min(i,end),:), ...
        'DisplayName', strtrim(station_names(i,:)), 'LineWidth', 1.5);
end
xlabel('Date', 'FontSize', 20);
ylabel(ylabel_str, 'FontSize', 20);
grid on; box on;
ax = gca; ax.FontSize = 15;

lgd = legend('show');
lgd.FontSize = 10;
lgd.Orientation = 'horizontal';
lgd.Location = 'southoutside';
lgd.NumColumns = min(N, 8);

if nargin >= 6 && ~isempty(fname)
    saveas(magplot, fname);
    disp([char(fname) ' saved.']);
end

end
