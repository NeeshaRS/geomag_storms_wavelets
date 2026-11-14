function [fig, xticks_dst] = F_plotDst(time, index_array, fname)
% F_plotDst  Plot a Dst time series (standalone figure)
%
% INPUTS:
%   time        - datetime array corresponding to index data
%   index_array - numeric array of index values
%   fname       - string for saving the plot
%
% This replicates the 2nd subplot in F_stormPowerIndexMovie,
% using the same figure width/height and formatting.

% Initialize figure
fig = figure;
set(fig, 'Units', 'inches', 'Position', [0, 10, 10, 4], 'Color', 'w');

% Do the plot
plot(time, index_array, 'k','LineWidth', 2); % Full time series in black
grid on; box on;

% Labels and formatting
xlabel('Date', 'FontSize', 20);
ylabel('Dst (nT)', 'FontSize', 20);
xlim([time(1), time(end)]);

% Font size for ticks
ax = gca;
xticks_dst = ax.XTick;
ax.FontSize = 15;

% Save plot
saveas(fig,fname)
disp([fname ' saved.'])

end
