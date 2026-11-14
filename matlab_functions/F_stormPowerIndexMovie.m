function [v] = F_stormPowerIndexMovie(vidname, ...
    power_ts, station_mag_lats, station_colors, time, index_array, index)
% This function creates a video showing the scatter plot of storm power
% versus geomagnetic latitude and the timeseries of a geomagnetic index.

% INPUTS:
% vidname- string with the file path and name for the video file
% power_ts- array with time series of power data
% station_mag_lats- array with the magnetic latitude of each station
% station_colors- array with the color codes for each station
% time- Matlab datetime array corresponding to the power data and index data
% index_array- array with the data points for the index
% index- string specifying the index. Options are 'Dst' or 'SYM'.
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

% Total figure dimensions
figWidth = 10; % Inches
figHeight = 13; % Inches -- taller than before, more room for both subplots

% Initialize figure
fig = figure;
set(gcf, 'Units', 'inches', 'Position', [0, 10, figWidth, figHeight]);
set(fig, 'Color', 'w'); % Set the figure background color to white

% Margins and spacing
topMargin = 0.05; % Space at the top (normalized units)
bottomMargin = 0.1 + 0.3937 / figHeight; % Space at the bottom (normalized units)
verticalSpacing = 0.13; % Space between the two subplots (normalized units) -- was 0.08, more breathing room between subplot 1's x-label and subplot 2

% Subplot heights (adjusted for margins and spacing)
subplot1Height = (2/3) * (1 - topMargin - bottomMargin - verticalSpacing);
subplot2Height = (1/3) * (1 - topMargin - bottomMargin - verticalSpacing);

% Subplot positions
subplot1Pos = [0.1, bottomMargin + subplot2Height + verticalSpacing, 0.8, subplot1Height];
subplot2Pos = [0.1, bottomMargin, 0.8, subplot2Height];

% Set up the video writer
v = VideoWriter(vidname, 'MPEG-4'); 
% Set frames per second
if index == 'Dst'
    v.FrameRate = 5;
elseif index == 'SYM'
    v.FrameRate = 120;
end

open(v);

% Stop once no station has any data left rather than animating blank
% frames through the rest of `time` -- a station's valid power range can
% end before the full time array does (e.g. its own record legitimately
% stops early), so the movie shouldn't keep running past that point.
last_valid_t = find(any(~isnan(power_ts), 2), 1, 'last');
if isempty(last_valid_t)
    error('power_ts is entirely NaN -- nothing to animate.');
end

% Loop through time to update the scatter plot
for t = 1:last_valid_t
    clf; % Clear figure for new frame

    % Subplot 1: Scatter plot
    axes('Position', subplot1Pos);
    scatter(power_ts(t,:), station_mag_lats, 100, ...
        station_colors, 'filled');
    grid on; box on;
    
    % Set y-axis
    ylim([45 90]) % covers every station in all three events (highest: THL, ~88 deg in 2003)

    % Set x-axis to logarithmic scale
    set(gca, 'XScale', 'log');
    xlim([1 1e6])

    % Add labels
    ylabel('Magnetic Latitude (Degrees)', 'FontSize', 20);
    xlabel('Wavelet Power (nT^2)', 'FontSize', 20);

    % Change the font size for the tick labels
    ax = gca;
    ax.FontSize = 15;

    % Subplot 2: Dst / SYM time series with moving vertical line
    axes('Position', subplot2Pos);
    plot(time, index_array, 'k','LineWidth', 2); % Full time series in black
    hold on;
    ylim([-600 70]); % Fixed across all events, so storms are visually comparable
    yLimits = ylim;
    plot([time(t), time(t)], yLimits, 'Color','#808080', ...
        'LineWidth', 2); % Moving vertical line
    grid on; box on;
    hold off;

    % Add labels and formatting
    xlabel('Date (UT)', 'FontSize', 20);
    if index == 'Dst'
        ylabel('Dst (nT)', 'FontSize', 20);
    elseif index == 'SYM'
        ylabel('SYM (nT)', 'FontSize', 20);
    end
    xlim([time(1), time(end)]);

    % Specify the x-ticks
    % numTicks = 6; % Number of ticks you want
    % xtickPositions = linspace(time(1), time(end), numTicks); % Evenly spaced ticks
    % xticks(xtickPositions); % Set the tick positions
    % datetick('x', 'mm/dd/yyyy HH:MM', 'keepticks');

    % Format font
    ax2 = gca;
    ax2.FontSize = 15;

    % Capture the frame
    frame = getframe(fig);
    writeVideo(v, frame);
end

% Close the video writer
close(v);
close(fig);

disp([vidname ' has been saved.'])
end