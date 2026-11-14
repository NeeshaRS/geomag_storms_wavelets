function [fig] = F_power_vs_Dst(station_mag_lats, ...
    station_colors, power_ts, Dst, figname, showColorbar)
% F_power_vs_Dst  Plot storm power versus the Dst geomagnetic index
%                 with optional colorbar
%
% INPUTS:
%   station_mag_lats : array with the magnetic latitude of each station
%   station_colors   : [N x 3] RGB color codes for each station
%   power_ts         : [T x N] time series of power data interpolated hourly
%   Dst              : [T x 1] array of corresponding hourly Dst values
%   figname          : string with the file path and name for saving figure
%   showColorbar     : (optional, default = false) true to add colorbar

if nargin < 6
    showColorbar = false; % default
end

[maxPower, stationIndices] = max(power_ts, [], 2);
maxLats   = zeros(size(stationIndices));

% Set x, y and color values
xvals = log10(maxPower(:));   % Storm power on log10 scale
yvals = Dst(:);               % Dst
pointColors = station_colors(stationIndices, :);

% Scatter of individual points, colored by station
fig = figure();
set(fig, 'Units', 'inches', 'Position', [0, 10, 6, 4], 'Color','w');
hold on
scatter(xvals, yvals, 50, pointColors, 'filled', ...
    'MarkerFaceAlpha', 0.8, ...
    'MarkerEdgeColor', [0 0 0], ...
    'MarkerEdgeAlpha', 0.4, ...
    'LineWidth', 0.4);

grid on
box on

% Tick label font size
ax = gca;
ax.FontSize = 15;

% Axis labels
xlabel('Storm Power (nT^2)', 'FontSize', 20);
ylabel('Dst (nT)', 'FontSize', 20);

% Move y-axis ticks and labels to the right side
ax.YAxisLocation = 'right';

% X-axis ticks
xlim([3 6])
xticks(3:6)
xticklabels({'10^3','10^{4}','10^{5}','10^{6}'})

% Optional colorbar
if showColorbar
    % Colorbar on the same FIXED 47-90 deg scale used to compute
    % station_colors (F_magLatColors) -- shared across all 3 events, not
    % rebuilt from this event's own min/max, so the colorbar means the
    % same thing (and matches the same colors) on every event's plot.
    colormap(flipud(F_purpleRedColormap(256))); % low value(47)->red, high value(90)->purple
    c = colorbar;
    caxis([47 90]);
    c.Label.String = 'Magnetic Latitude (°)';
    c.Label.FontSize = 20;
end

% Save plot
saveas(fig, figname)
disp([figname ' saved.'])

end