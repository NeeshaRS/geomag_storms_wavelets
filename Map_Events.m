%% Map_Events.m
% Generalized station-map script (multiple events via config block)

clc; clear all; close all;
fprintf("Reading to begin.");

%% 0) Paths + config
addpath matlab_functions/
paths = F_loadPaths();
fprintf("\n Paths set.");

%% 1) EVENT REGISTRY (config/events.json) -- mappable events only
all_events = F_loadEvents();
mappable = arrayfun(@(e) ~isempty(e.united_data_fname), all_events);
events = all_events(mappable);
fprintf("\n Loaded %d mappable events from config/events.json.", numel(events));

%% 2) SELECT EVENT
event_idx = 3;  % index into `events` (mappable events only); see events(k).id -- 2 = 2003-10-29
E = events(event_idx);

fprintf("\n=== Mapping Event %d/%d: %s ===\n%s\n\n", event_idx, numel(events), E.id, E.description);

%% 3) LOAD DATA
% (expects struct `data` with site fields)
% Picks the most recently written united_data.mat for this event --
% Data_processing.m writes dated snapshots rather than one fixed name.
[matpath, matfname] = F_findLatestUnitedData(paths.processed_high_frequency_path, E.united_data_fname);
S = load(matpath);
if ~isfield(S, 'data')
    error("MAT-file loaded, but variable 'data' not found inside %s", matpath);
end
data = S.data;
fprintf("...loaded %s\n", matfname);
fprintf("\n 3: Data loaded.");

%% 4) PREP FOR MAPPING (generalized version of your 'Prep for mapping' cell)
sites = fieldnames(data);
if isfield(E, 'exclude_sites') && ~isempty(E.exclude_sites)
    sites = sites(~ismember(sites, E.exclude_sites));
end

% Only map stations that survived cleaning (gap rule, trims, etc.), i.e. those
% in the cleaned Hhpf CSVs the wavelet/power analysis and stats figures use --
% united_data still holds stations later dropped (e.g. 1989 GDH/SKT, 2003
% BJN/FSMI/LOZ/MAS/MCMU/NUR/TALO). Errors if a network's CSV is missing.
clean_sites = F_cleanedStationList(paths, E);
dropped_from_map = setdiff(sites, clean_sites, 'stable');
not_in_united    = setdiff(clean_sites, sites, 'stable');
if ~isempty(not_in_united)
    error("Cleaned CSVs contain station(s) absent from %s (or listed in exclude_sites): %s", ...
        matfname, strjoin(not_in_united, ', '));
end
sites = sites(ismember(sites, clean_sites));
fprintf("\n 4: Map site list restricted to cleaned Hhpf CSV stations.");
if isempty(dropped_from_map); dropped_str = "(none)"; else; dropped_str = strjoin(dropped_from_map, ', '); end
fprintf("\n    Dropped from map (in united_data, not in cleaned CSVs): %s", dropped_str);
N = numel(sites);
assert(N == numel(unique(clean_sites)), "Map has %d stations but the cleaned CSVs have %d unique.", N, numel(unique(clean_sites)));
fprintf("\n    VERIFY: %d map stations == %d cleaned-CSV stations for %s.\n", N, numel(unique(clean_sites)), E.id);

geo_lat = nan(N,1);
geo_lon = nan(N,1);
cdm_lat = nan(N,1);
cdm_lon = nan(N,1);

for k = 1:N
    s = sites{k};

    % Only fill if fields exist
    if isfield(data.(s), 'lat');      geo_lat(k) = data.(s).lat;      end
    if isfield(data.(s), 'lon');      geo_lon(k) = data.(s).lon;      end
    if isfield(data.(s), 'cdm_lat');  cdm_lat(k) = data.(s).cdm_lat;  end
    if isfield(data.(s), 'cdm_lon');  cdm_lon(k) = data.(s).cdm_lon;  end
end

fprintf("\n 4: Loaded metadata for %d sites.\n", N);

% Wrap longitudes to [-180, 180]
geo_lon_wrapped = geo_lon;
mask = geo_lon_wrapped > 180;
geo_lon_wrapped(mask) = geo_lon_wrapped(mask) - 360;
fprintf("\n 4: Longitudes wrapped to [-180, 180].");

% Station colors: purple(high lat)->red(low lat), on the FIXED 47-90 deg
% scale shared across all 3 events (F_magLatColors) -- so a station at a
% given latitude gets the same color regardless of which event/how many
% other stations are in this particular map, and matches the same
% fixed-scale colors used in the stats plots. cdm_lat is stored negative
% here (more-negative = higher actual latitude), so flip sign first.
station_colors = F_magLatColors(-cdm_lat);

% Landmark cities (stars) for this event -- cdm_lat computed in
% Calc_IGRF_CDMlatlon.ipynb at the same per-event epoch as the stations.
lm_path = 'config/event_landmarks_geo_info_with_cdm.csv';
lm_opts = setvartype(detectImportOptions(lm_path), {'event_id', 'name'}, 'string'); % else event_id parses as datetime
lm_tbl = readtable(lm_path, lm_opts);
lm_tbl = lm_tbl(lm_tbl.event_id == string(E.id), :);
% Rows with no location (e.g. the unlocated 2003 power station) only mark a
% failure time on the heatmaps -- no star on the map.
lm_tbl = lm_tbl(isfinite(lm_tbl.lat) & isfinite(lm_tbl.lon), :);
landmarks = struct('lat', lm_tbl.lat, 'lon', lm_tbl.lon, ...
    'colors', F_magLatColors(-lm_tbl.cdm_lat));
fprintf("\n 4: %d landmark(s) for %s: %s\n", height(lm_tbl), E.id, strjoin(lm_tbl.name, ', '));

%% 5) PLOT + SAVE (generalized version of your final plot cell)
year_str = extractBefore(E.id, 5);
fname = sprintf("%s_lambertstd.png", year_str);
out_png = char(fullfile(paths.figure_root_paper, E.figure_subdir, "maps", fname));

% Ensure output directory exists
out_dir = fileparts(out_png);
if ~isempty(out_dir) && ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

F_StationStereoMap(geo_lat, geo_lon_wrapped, cdm_lat, station_colors, out_png, ...
    'Landmarks', landmarks);

fprintf("Saved map to: %s\n", out_png);

%% 6) STATION TABLE (per-event site metadata export)
% Full name/location come from F_stationInfo's static lookup (CARISMA/IMAGE/DTU
% station pages); falls back to the site code and a blank location for any
% site not in that lookup rather than guessing. Cadence + start/end timestamps are
% the span actually used in the analysis, read from the per-event station tracking
% CSV written by the cleaning scripts (UsedStart/UsedEnd = first/last valid time on
% the event grid). If a station isn't in that CSV, it falls back to its united_data
% span narrowed by any station_start/end_overrides, with a warning.
station_info = F_stationInfo();

track = table();
track_path = fullfile(paths.processed_data_root, 'WO_data', 'station_tracking', sprintf('%s_station_tracking.csv', year_str));
if isfile(track_path)
    topts = detectImportOptions(track_path);
    topts = setvartype(topts, {'Event','Network','Site','Status','Reason','Note','InputStart','InputEnd','UsedStart','UsedEnd'}, 'string');
    track = readtable(track_path, topts);
    track = track(track.Event == string(E.id), :);
else
    warning("No station tracking CSV at %s -- table times fall back to united_data spans.", track_path);
end

SiteName   = strings(N,1);
SiteAcronym = strings(N,1);
Location   = strings(N,1);
Network    = strings(N,1);
CadenceSec = nan(N,1);
TimeStart  = NaT(N,1);
TimeEnd    = NaT(N,1);

% Data-side site code -> published acronym, where they differ (Thule Air Base
% is "PIF" in the raw Greenland files/united_data but "TAB" in the paper).
acronym_alias = containers.Map({'PIF'}, {'TAB'});

for k = 1:N
    s = sites{k};
    pub = s;
    if isKey(acronym_alias, s); pub = acronym_alias(s); end
    SiteAcronym(k) = string(pub);

    idx = find(station_info.site == string(pub), 1);
    if isempty(idx)
        SiteName(k) = string(s);
        Location(k) = "";
    else
        SiteName(k) = station_info.name(idx);
        Location(k) = station_info.location(idx);
    end

    if isfield(data.(s), 'source'); Network(k) = string(data.(s).source); end

    if isfield(data.(s), 'tres') && ~isempty(data.(s).tres)
        CadenceSec(k) = data.(s).tres;
    elseif isfield(data.(s), 'dt_seconds') && ~isempty(data.(s).dt_seconds)
        CadenceSec(k) = data.(s).dt_seconds;
    end

    if isfield(data.(s), 'datetime') && ~isempty(data.(s).datetime)
        TimeStart(k) = min(data.(s).datetime);
        TimeEnd(k)   = max(data.(s).datetime);
    end

    % Per-station trims applied downstream (Network_event_plotting.m) shorten
    % the series actually used (fallback only; the tracking CSV below is preferred).
    if isfield(E, 'station_start_overrides') && isstruct(E.station_start_overrides) && isfield(E.station_start_overrides, s)
        TimeStart(k) = max(TimeStart(k), datetime(E.station_start_overrides.(s)));
    end
    if isfield(E, 'station_end_overrides') && isstruct(E.station_end_overrides) && isfield(E.station_end_overrides, s)
        TimeEnd(k) = min(TimeEnd(k), datetime(E.station_end_overrides.(s)));
    end

    % Used span + cadence from the tracking CSV (single source of truth).
    r = [];
    if ~isempty(track); r = find(track.Site == string(s) & track.Status == "kept", 1); end
    if ~isempty(r) && strlength(track.UsedStart(r)) > 0
        TimeStart(k) = datetime(track.UsedStart(r), 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        TimeEnd(k)   = datetime(track.UsedEnd(r),   'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    else
        warning("Station %s has no 'kept' row with a used span in the tracking CSV -- using its united_data span.", s);
    end
end

station_table = table(SiteName, SiteAcronym, Network, Location, geo_lat, geo_lon_wrapped, ...
    cdm_lat, cdm_lon, CadenceSec, TimeStart, TimeEnd, ...
    'VariableNames', {'SiteName', 'SiteAcronym', 'Network', 'Location', 'Lat', 'Lon', ...
    'MagLat', 'MagLon', 'CadenceSec', 'TimeStart', 'TimeEnd'});

out_csv = char(fullfile(paths.figure_root_paper, E.figure_subdir, "tables", sprintf("%s_station_table.csv", year_str)));
out_csv_dir = fileparts(out_csv);
if ~isempty(out_csv_dir) && ~exist(out_csv_dir, 'dir')
    mkdir(out_csv_dir);
end

writetable(station_table, out_csv);
fprintf("\n 6: Saved station table (%d sites) to: %s\n", N, out_csv);