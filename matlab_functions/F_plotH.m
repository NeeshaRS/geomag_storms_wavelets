function [Hfig] = F_plotH(datetime_vector, H, station_colors, station_names, figname)
% For given datetime vector, horizontal magnetic field data, station
% colors, station names, and a figure name, plot the data and save it.
%
% INPUTS:
% H- array of the horizontal magnetic field data
% datetime_vector- array of the data's observation stamps (e.g. timestamps 
%                  or indexing)
% station_colors- array of the colors to use for the stations' data
% station_names- array of the stations' codes
% figname- string with the file path and file name for saving the plot as a
%          figure
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

Hfig= figure();

temp= size(station_names);
num_stations = temp(1);

if num_stations > 1
    % Set the figure size
    set(gcf, 'Units', 'inches', 'Position', [0, 10, 8, 10]);
    hold on
    for i = 1:num_stations
        plot(datetime_vector, H(:, i), 'Color', station_colors(i,:), ...
            'DisplayName', [station_names(i,:)],'LineWidth',2);
    end
elseif num_stations == 1
    % Set the figure size
    set(gcf, 'Units', 'inches', 'Position', [0, 10, 8, 5]);
    plot(datetime_vector, H, 'Color', station_colors, ...
            'DisplayName', [station_names],'LineWidth',2);
end

% Add labels and legend
xlabel('Date', 'FontSize', 20);
ylabel('Horizontal Magnetic Field (nT)', 'FontSize', 20);
grid on;

% Customize the axes
ax = gca;
ax.FontSize = 15; % Set font size for axis tick marks

% Customize the legend
lgd = legend('show');
lgd.FontSize = 15;
lgd.Orientation = 'vertical';
lgd.Location = 'eastoutside';

% Save plot
saveas(Hfig,[figname '.png'])
disp([figname ' png saved.'])
saveas(Hfig,[figname '.fig'])
disp([figname ' MATLAB fig saved.'])
end
