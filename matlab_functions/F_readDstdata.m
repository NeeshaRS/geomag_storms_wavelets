function [timestamps, all_observations] = F_readDstdata(filename,era)
% Read in Dst data from the World Data Center for Geomagnetism, Kyoto
% and save it as two arrays: one of matlab datenum timestamps and one of
% the hourly Dst value.
%
% INPUTS:
%   filename: string of the path and filename with the Dst data.
%   era: string describing the temporal era of the data. Options are
%   '1900s' or '2000s'.
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 

% Open the file
fid = fopen(filename, 'r');
if fid == -1
    error('File cannot be opened: %s', filename);
end

% Initialize arrays for datenums and observations
timestamps = [];
all_observations = [];

% Read each line from the file
line = fgetl(fid);
while ischar(line)
    % Ignore the first 3 characters
    line = line(4:end);

    % Extract the date components
    if era == '1900s'
        year = str2double(['19', line(1:2)]);
    elseif era == '2000s'
        year = str2double(['20', line(1:2)]);
    end
    month = str2double(line(3:4));
    day = str2double(line(6:7));

    % Create a base datenum for the date
    base_date = datetime(year, month, day);

    % Initialize array to hold the 24 observations
    observations = zeros(1, 24);

    % Extract the hourly observations
    observations_str = line(18:end);

    % Read each 4-character segment
    for i = 1:24
        start_idx = (i-1)*4 + 1;
        obs_str = strtrim(observations_str(start_idx:start_idx+3)); % Trim spaces
        observations(i) = str2double(obs_str);
    end

    % Create datenums for each hour
    datenums = base_date + (0:23)/24;

    % Append to the overall arrays
    timestamps = [timestamps, datenums];
    all_observations = [all_observations, observations];

    % Read the next line
    line = fgetl(fid);
end

% Close the file
fclose(fid);
end