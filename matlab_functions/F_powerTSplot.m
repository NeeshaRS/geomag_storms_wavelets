function F_powerTSplot(time, powertimeseries_bystation, station_colors, fname)
% F_powerTSplot  Plot power time series per station, color-coded by station
%
% INPUTS
%   time        : datetime (recommended) or datenum vector, length T
%   powertimeseries_bystation : [T x N] numeric, one column per station
%   station_colors            : [3 x N] or [N x 3] RGB; values in 0–1 or 0–255
%   fname       : string/char, filename to save the figure (extension included)
%
% This makes a standalone figure with the same width as F_plotDst (8 in).

% ---- Normalize time
if ~isdatetime(time)
    time = datetime(time, 'ConvertFrom', 'datenum');
end

[T, N] = size(powertimeseries_bystation);

% ---- Validate sizes
if size(station_colors,1) ~= 3 && size(station_colors,2) ~= 3
    error('station_colors must be 3xN or Nx3 RGB.');
end
% Orient to 3 x N
if size(station_colors,2) == 3 && size(station_colors,1) == N
    station_colors = station_colors.'; % make 3 x N
elseif size(station_colors,1) ~= 3
    error('station_colors must have one color per station (N columns).');
end
if size(station_colors,2) ~= N
    error('station_colors must have one color per station (N columns).');
end

if length(time) ~= T
    error('Length of time (%d) must match rows in powertimeseries_bystation (%d).', ...
        length(time), T);
end

% ---- Normalize color scale to 0–1 if needed
if max(station_colors, [], 'all') > 1
    station_colors = station_colors / 255;
end

% ---- Figure: same width as F_plotDst (8 in)
fig = figure;
set(fig, 'Units','inches', 'Position',[0,10,8,3], 'Color','w');
ax = axes('Parent', fig);

hold(ax, 'on');
for k = 1:N
    plot(ax, time, powertimeseries_bystation(:,k), '-', ...
        'LineWidth', 2, 'Color', station_colors(:,k).');
end
hold(ax, 'off');

grid(ax, 'on'); box(ax, 'on');
xlabel(ax, 'Date', 'FontSize', 20);
ylabel(ax, 'Power (nT^2)', 'FontSize', 20);
xlim(ax, [time(1), time(end)]);
ax.FontSize = 15;

% ---- Save plot
saveas(fig, fname);
disp([fname ' saved.'])

end
