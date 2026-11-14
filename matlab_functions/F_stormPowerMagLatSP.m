function [fig] = F_stormPowerMagLatSP(figname, ...
    power_ts, station_mag_lats, station_colors, time_array, target_time, varargin)

% This function creates a video showing the scatter plot of storm power
% versus geomagnetic latitude and the timeseries of a geomagnetic index.

% INPUTS:
% figname- string with the file path and name for the figure file
% power_ts- array with time series of power data
% station_mag_lats- array with the magnetic latitude of each station
% station_colors- array with the color codes for each station
% time_array- Matlab datetime array corresponding to the power data and 
%             index data
% target_time- the specific time to plot
% OPTIONAL NAME-VALUE:
% 'YLim'- [ymin ymax] fixed magnetic latitude limits (degrees). Default
%         [] = derived from ALL of station_mag_lats (rounded outward to
%         the nearest 5 deg), so every snapshot of an event shares the
%         same y-axis even when some stations have NaN power at
%         target_time (MATLAB autoscaling would drop those points and
%         change the axis from snapshot to snapshot).
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

p = inputParser;
addParameter(p, 'YLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
parse(p, varargin{:});
y_lim = p.Results.YLim;

% Find the index of the closest time
[~, idx] = min(abs(datenum(time_array) - datenum(target_time)));

% Initialize figure
fig = figure;
set(gcf, 'Units', 'inches', 'Position', [0,  10, 4, 7]);
set(fig, 'Color', 'w'); % Set the figure background color to white

% Scatter plot for that target time
scatter(power_ts(idx,:), station_mag_lats, 100, ...
    station_colors, 'filled');
grid on; box on;
ax = gca;
ax.GridAlpha = 0.5;        % default 0.15 -- higher = more visible
ax.GridColor = [0.3 0.3 0.3]; % darker gray 
ax.MinorGridLineStyle = '-';
ax.MinorGridAlpha = 0.5;

% Set x-axis to logarithmic scale
set(gca, 'XScale', 'log');
xlim([1 1e6])
if isempty(y_lim)
    lats = station_mag_lats(isfinite(station_mag_lats));
    y_lim = [5*floor(min(lats)/5), 5*ceil(max(lats)/5)];
    if y_lim(1) == y_lim(2), y_lim = y_lim + [-5 5]; end
end
ylim(y_lim)

% Add labels
ylabel('Magnetic Latitude (Degrees)', 'FontSize', 20);
xlabel('Wavelet Power (nT^2)', 'FontSize', 20);

% Change the font size for the tick labels
ax = gca;
ax.FontSize = 15;

% Save plot
saveas(fig,figname)
disp([figname ' saved.'])

end