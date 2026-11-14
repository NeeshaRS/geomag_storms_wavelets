function stations = F_cleanedStationList(paths, E)
% F_cleanedStationList  Station codes present in the cleaned Hhpf CSVs for an
% event, i.e. the stations the wavelet/power analysis (Run_Wavelet_Analysis.py)
% and the stats/heatmap figures actually use. Reads only each CSV's header line,
% not the data.
%
% Mirrors Run_Wavelet_Analysis.py's CSV lookup: one CSV per entry in
% E.networks, named <year>_<label>_Hhpf.csv, in either <network>/ or <label>/
% under paths.processed_high_frequency_path (label: DTU -> Greenland, else same
% as the network name).
%
% INPUTS:
%   paths  struct from F_loadPaths
%   E      event struct (needs .id and .networks)
%
% OUTPUT:
%   stations  cellstr column of station codes, in CSV column order, networks
%             concatenated in E.networks order. Errors if any configured
%             network's CSV is missing, so a map can't silently show a subset.

labels = struct('IMAGE', 'IMAGE', 'DTU', 'Greenland', 'OTT', 'OTT', 'CARISMA', 'CARISMA');
tag = char(extractBefore(E.id, 5));
networks = cellstr(E.networks);

stations = {};
for n = 1:numel(networks)
    network = networks{n};
    if isfield(labels, network); label = labels.(network); else; label = network; end
    fname = sprintf('%s_%s_Hhpf.csv', tag, label);

    csv_path = fullfile(paths.processed_high_frequency_path, network, fname);
    if ~isfile(csv_path)
        csv_path = fullfile(paths.processed_high_frequency_path, label, fname);
    end
    if ~isfile(csv_path)
        error('F_cleanedStationList:missingCSV', ...
            'No cleaned Hhpf CSV for %s (%s) -- run Network_event_plotting.m / Greenland_event_plotting.m first.', network, fname);
    end

    fid = fopen(csv_path, 'r');
    header = fgetl(fid);
    fclose(fid);
    cols = strtrim(strrep(strsplit(header, ','), '"', ''));
    cols = cols(~strcmpi(cols, 'time'));
    stations = [stations; cols(:)]; %#ok<AGROW>
end

end
