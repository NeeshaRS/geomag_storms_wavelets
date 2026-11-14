function [magplot] = F_geomagStackedPlot(magData, time, station_names, station_colors, fname)
% This function creates a stacked plot of geomagnetic time series, color
% coded by the specific stations.
%
% INPUTS:
% magData = array where each column is data from a different station and
% each row is an observation at a different time
%
% station_names = array of strings with each station's name code
%
% station_colors = array of the RBG colors for each station
%
% fname (optional) = file path to save the figure to. If omitted, the
% figure is created but not saved -- meant for interactive use; in a
% non-interactive `matlab -batch` run the figure is otherwise lost when
% the session exits.
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

% Create a table with datetime and station data
data_table = array2table(magData, 'VariableNames', cellstr(station_names));
data_table.Time = time;

N = length(station_names);

% Initialize figure
magplot= figure();

% Set the figure size
set(gcf, 'Units', 'inches', 'Position', [0,  10, 8, 11]);

% Set y-axis ticks, limits and line color
% Round each to one sig-fig at its own order of magnitude. Use abs() for
% the log10 -- log10 of a negative value returns a complex number in
% MATLAB, which would otherwise silently propagate into ylim() and error.
minData= min(min(magData));
maxData= max(max(magData));
if minData == 0; minD_rounded = 0; else
    minD_rounded = round(minData / 10^floor(log10(abs(minData))), 1) * 10^floor(log10(abs(minData)));
end
if maxData == 0; maxD_rounded = 0; else
    maxD_rounded = round(maxData / 10^floor(log10(abs(maxData))), 1) * 10^floor(log10(abs(maxData)));
end
y_ticks= linspace(minD_rounded, maxD_rounded, 3);

% Generate x-ticks at the start of each day
x_ticks = datetime(year(time(1)), month(time(1)), ...
    day(time(1))):caldays(1):datetime(year(time(end)), month(time(end)), ...
    day(time(end)));

% Plot each subplot
for i = 1:N
    subplot(N, 1, i); % Create a subplot
    plot(time, magData(:,i), 'Color', station_colors(i,:)); % Plot data in the subplot
    grid on;
    
    ylim([y_ticks(1) y_ticks(end)]) % set y axis limits
    yticks(y_ticks); % Set y-ticks for the subplot
    ylabel(station_names(i,:)); % Label for each subplot

    % Customize the axes
    ax = gca;
    ax.FontSize = 15; % Set font size for axis tick marks

    % Set x-ticks to the start of each day
    xticks(x_ticks);
    
    % Remove x-axis ticks and labels for all but the last subplot
    if i < N
        set(ax, 'XTickLabel', []); % Remove x-axis labels
    else
        ax.XTickLabelRotation = 45; % Rotate x-axis labels for better readability
    end
end
xlabel('Date');

if nargin >= 5 && ~isempty(fname)
    saveas(magplot, fname);
    disp([char(fname) ' saved.']);
end

end