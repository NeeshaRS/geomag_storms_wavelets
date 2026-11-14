function [] = F_woArrayData(datetime_vec,data_array, station_names, filename)
% Write out the observations for a data array (e.g. timestamps and then
% columns of horizontal magnetic field observations for each station in the
% IMAGE array). Saves the data as a CSV for easy loading in python.
%
% INPUTS:
% data_array- array of the data where each column is data from a different
% station
% datetime_vec- array of the data's observation stamps
% station_names- array of the stations' codes
% filename- string of the file path and name for writing out
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

% Convert datetime to string
timestamp_strings = cellstr(datestr(datetime_vec, 'yyyy-mm-dd HH:MM:SS'));  % Convert datetime to cell array of strings

% Combine timestamps and data into one cell array
combined_data= [timestamp_strings, num2cell(data_array)];

% Convert station_codes array (7x3) to a 1x7 cell array of strings
station_names_str = cellstr(station_names);  % Converts each row of the 7x3 array into a string

% Create headers: 'time' followed by station codes
headers = ['time', station_names_str'];

% Write to CSV file
fid = fopen(filename, 'w');  % Open the file for writing
disp(['File open for writing: ' filename])

% Write the headers
fprintf(fid, '%s,', headers{1:end-1});  % Write all headers except the last with commas
fprintf(fid, '%s\n', headers{end});  % Write the last header without trailing comma
disp('Headers written out.')

% Close the file after writing headers
fclose(fid);

% Append the combined data to the CSV
writecell(combined_data, filename, 'WriteMode', 'append');
disp('All data written out.')
end