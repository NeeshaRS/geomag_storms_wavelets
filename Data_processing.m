%% Data_processing.m
% Read in each event's raw network data, merge into a unified per-site
% structure, attach geo/magnetic coordinates, and save <tag>_united_data.mat.
% Driven by config/paths.json + config/events.json -- see F_loadPaths, F_loadEvents.
clc; clear all; close all;
dbstop if error
fprintf("Ready to begin.")

%% 0) Paths + config
addpath matlab_functions/
paths = F_loadPaths();
fprintf("\n 0: Paths set.")

%% 1) EVENT REGISTRY (config/events.json) -- ingestable events only
all_events = F_loadEvents();
ingestable = arrayfun(@(e) ~isempty(e.ingestion), all_events);
events = all_events(ingestable);
fprintf("\n Loaded %d ingestable events from config/events.json.", numel(events));

%% 2) SELECT EVENT
event_idx = 3;  % index into `events` (ingestable events only); see events(k).id -- 2 = 2003-10-29
E = events(event_idx);
ing = E.ingestion;
fprintf("\n=== Processing Event %d/%d: %s ===\n%s\n\n", event_idx, numel(events), E.id, E.description);

if ~isfolder(paths.high_frequency_path)
    error("High-frequency data root not found: %s", paths.high_frequency_path);
end

%% 3) Read CARISMA into unified data structure (if configured for this event)
data = struct();
if isempty(ing.carisma)
    fprintf("\n 3: No ingestion.carisma configured for this event. Skipping.");
else
    tic
    carisma_dir = fullfile(paths.high_frequency_path, ing.carisma.subdir);
    data = F_read_CARISMA(carisma_dir, ing.carisma.cache_fname, ing.carisma.ftype);

    % CARISMA can carry its own end_override (e.g. to cut off before a
    % known outage) instead of the event's general ingestion.end.
    carisma_start = datetime(ing.start);
    if isfield(ing.carisma, 'end_override') && ~isempty(ing.carisma.end_override)
        carisma_end = datetime(ing.carisma.end_override);
    else
        carisma_end = datetime(ing.end);
    end

    sites = fieldnames(data);
    for k = 1:numel(sites)
        s = sites{k};
        keep = (data.(s).datetime >= carisma_start) & (data.(s).datetime <= carisma_end);
        data.(s).datetime = data.(s).datetime(keep);
        data.(s).BX = data.(s).BX(keep);
        data.(s).BY = data.(s).BY(keep);
        data.(s).BZ = data.(s).BZ(keep);

        data.(s).source = "CARISMA";
        if ~isfield(data.(s), "qc") || ~isstruct(data.(s).qc)
            data.(s).qc = struct();
        end
        if ~isfield(data.(s).qc, "usable"); data.(s).qc.usable = true; end
        if ~isfield(data.(s).qc, "processed"); data.(s).qc.processed = false; end
        if ~isfield(data.(s).qc, "notes");  data.(s).qc.notes  = "";   end
    end
    toc
    fprintf("\n 3: CARISMA data loaded for (%s).", E.id)
end

%% 4) Read + merge IMAGE (raw .txt via F_read_IMAGE)
for c = 1
    tic
    image_dir = fullfile(paths.high_frequency_path, "Image");
    image = F_read_IMAGE(image_dir, ing.image_fname);

    image_sites = fieldnames(image);
    image_sites = setdiff(image_sites, {'datetime_vector'}, 'stable');

    isComp = cellfun(@(s) strlength(string(s)) == 4 && any(s(end) == ['X','Y','Z']), image_sites);
    compNames = image_sites(isComp);

    siteIDs = cellfun(@(s) s(1:3), compNames, 'UniformOutput', false);
    siteIDs = unique(siteIDs, 'stable');

    t_image = image.datetime_vector(:);

    for i = 1:numel(siteIDs)
        site = siteIDs{i};

        siteX = [site 'X'];
        siteY = [site 'Y'];
        siteZ = [site 'Z'];

        missing = {};
        if ~isfield(image, siteX); missing{end+1} = siteX; end %#ok<AGROW>
        if ~isfield(image, siteY); missing{end+1} = siteY; end %#ok<AGROW>
        if ~isfield(image, siteZ); missing{end+1} = siteZ; end %#ok<AGROW>

        if isempty(missing)
            BX_new = image.(siteX)(:);
            BY_new = image.(siteY)(:);
            BZ_new = image.(siteZ)(:);
        else
            BX_new = nan(size(t_image));
            BY_new = nan(size(t_image));
            BZ_new = nan(size(t_image));
        end

        if isfield(data, site)
            warning("Site %s already exists in data; overwriting with IMAGE values.", site);
        end

        data.(site).source   = "IMAGE";
        data.(site).datetime = t_image;
        data.(site).BX       = BX_new;
        data.(site).BY       = BY_new;
        data.(site).BZ       = BZ_new;

        if ~isfield(data.(site), "qc") || ~isstruct(data.(site).qc)
            data.(site).qc = struct();
        end
        if ~isfield(data.(site).qc, "usable"); data.(site).qc.usable = true; end
        if ~isfield(data.(site).qc, "processed"); data.(site).qc.processed = false; end
        if ~isfield(data.(site).qc, "notes");  data.(site).qc.notes  = "";   end

        if ~isempty(missing)
            msg = "Missing IMAGE components: " + strjoin(string(missing), ", ");
            data.(site).qc.notes = strtrim(data.(site).qc.notes + " " + msg);
            warning("IMAGE station %s incomplete: %s", site, msg);
        end
    end
    toc
    fprintf("\n 4: IMAGE merged into data structure.")
end

%% 5A - Merge Greenland raw .sec data into data (if configured for this event)
for c = 1
    if isempty(ing.greenland_raw)
        fprintf("\n 5A: No ingestion.greenland_raw configured for this event. Skipping.");
        continue
    end

    green_dir = fullfile(paths.high_frequency_path, ing.greenland_raw.subdir);
    switch lower(string(ing.greenland_raw.format))
        case "sec"
            GL = F_read_Greenland_SEC(green_dir, ing.greenland_raw.cache_fname);
        case "cdf"
            GL = F_read_Greenland_CDF(green_dir, ing.greenland_raw.cache_fname);
        otherwise
            error("Unknown ingestion.greenland_raw.format: %s", string(ing.greenland_raw.format));
    end
    gl_sites = fieldnames(GL);
    n_added  = 0;

    event_start = datetime(ing.start);
    event_end   = datetime(ing.end);

    for i = 1:numel(gl_sites)
        site = gl_sites{i};
        gl   = GL.(site);

        t = gl.datetime;
        t.TimeZone = '';
        keep = (t >= event_start) & (t <= event_end);
        t    = t(keep);

        if isempty(t); continue; end

        BX = gl.BX(keep);
        BY = gl.BY(keep);
        BZ = gl.BZ(keep);

        if isfield(data, site)
            % Same physical station reported through two feeds (e.g. IMAGE
            % redistributes some DTU/Greenland stations) -- DTU is the
            % station operator, so it wins; the other feed's copy is
            % redundant and gets dropped rather than kept as a nameless,
            % coordinate-less duplicate entry.
            fprintf("\n  Greenland merge: %s already existed (source=%s) -- replacing with DTU version.", site, string(data.(site).source));
        end

        data.(site).source    = "DTU";
        data.(site).datetime  = t(:);
        data.(site).BX        = BX(:);
        data.(site).BY        = BY(:);
        data.(site).BZ        = BZ(:);
        if isfield(gl, "BF"); data.(site).BF = gl.BF(keep); data.(site).BF = data.(site).BF(:); end

        if isfield(gl, "lat");       data.(site).lat       = gl.lat;       end
        if isfield(gl, "lon");       data.(site).lon       = gl.lon;       end
        if isfield(gl, "elevation"); data.(site).elevation = gl.elevation; end
        if isfield(gl, "reported");  data.(site).reported  = gl.reported;  end

        if ~isfield(data.(site), "qc") || ~isstruct(data.(site).qc)
            data.(site).qc = struct();
        end
        if ~isfield(data.(site).qc, "usable");    data.(site).qc.usable    = true;  end
        if ~isfield(data.(site).qc, "processed"); data.(site).qc.processed = false; end
        if ~isfield(data.(site).qc, "notes");     data.(site).qc.notes     = "";    end

        n_added = n_added + 1;
    end

    fprintf("\n 5A: Greenland merged (%d sites added).", n_added);
end

%% 5B - Merge Greenland pre-processed BH CSV into data (if configured for this event)
for c = 1
    if isempty(ing.greenland_processed_csv)
        fprintf("\n 5B: No ingestion.greenland_processed_csv configured for this event. Skipping.");
        continue
    end

    green_path = fullfile(paths.high_frequency_path, ing.greenland_processed_csv.subdir, ing.greenland_processed_csv.fname);
    if ~isfile(green_path)
        fprintf("\n 5B: Processed Greenland CSV not found (%s). Skipping.", green_path);
        continue
    end

    T = readtable(green_path);

    vnames = string(T.Properties.VariableNames);
    vlow   = lower(vnames);
    it = find(ismember(vlow, ["time","timestamp","datetime","date_time"]), 1);
    assert(~isempty(it), "No time column found in %s", green_path);

    t_raw = T{:, it};

    if isdatetime(t_raw)
        t = t_raw;
    elseif isnumeric(t_raw)
        t = datetime(t_raw, "ConvertFrom", "datenum");
    else
        try
            t = datetime(t_raw);
        catch
            t = datetime(string(t_raw), "InputFormat", "yyyy-MM-dd HH:mm:ss");
        end
    end

    event_start = datetime(ing.start);
    event_end   = datetime(ing.end);
    keep = (t >= event_start) & (t <= event_end);
    t = t(keep);

    n_added = 0;

    for j = 1:numel(vnames)
        if j == it; continue; end

        site = upper(string(vnames(j)));
        site = char(site);

        BH = T{:, j};
        BH = BH(keep);

        if isempty(t); continue; end

        if ~isfield(data, site) || ~isstruct(data.(site))
            data.(site) = struct();
        end

        data.(site).source   = "DTU";
        data.(site).datetime = t(:);
        data.(site).BH       = BH(:);

        if ~isfield(data.(site), "qc") || ~isstruct(data.(site).qc)
            data.(site).qc = struct();
        end
        if ~isfield(data.(site).qc, "usable"); data.(site).qc.usable = true; end
        if ~isfield(data.(site).qc, "processed"); data.(site).qc.processed = false; end
        if ~isfield(data.(site).qc, "notes");  data.(site).qc.notes  = "Pre-processed BH loaded from greenland_processed_csv"; end
        data.(site).qc.processed = true;

        n_added = n_added + 1;
    end

    fprintf("\n 5B: Processed Greenland BH loaded and merged (%d sites added).", n_added);
end

%% 5C - Merge OTT into data (if configured for this event)
for c = 1
    if isempty(ing.ott)
        fprintf("\n 5C: No ingestion.ott configured for this event. Skipping.");
        continue
    end

    site = "OTT";
    ott_path = fullfile(paths.high_frequency_path, ing.ott.subdir, ing.ott.fname);
    assert(isfile(ott_path), "Missing OTT mat file: %s", ott_path);

    S = load(ott_path);

    t_ott = S.datetime_vector(:);
    BX    = S.x(:);
    BY    = S.y(:);
    BZ    = S.z(:);

    dt_sec = seconds(median(diff(t_ott)));
    assert(abs(dt_sec - 10) < 0.1, ...
        "OTT cadence is %.2f s (expected ~10 s).", dt_sec);

    event_start = datetime(ing.start);
    event_end   = datetime(ing.end);
    keep = (t_ott >= event_start) & (t_ott <= event_end);
    t_ott = t_ott(keep);
    BX    = BX(keep);
    BY    = BY(keep);
    BZ    = BZ(keep);

    if isfield(data, site)
        data.([site "_prev"]) = data.(site);
        warning("OTT merge: %s already existed. Old version moved to %s_prev.", site, site);
    end

    data.(site).source        = "OTT";
    data.(site).datetime      = t_ott;
    data.(site).BX            = BX;
    data.(site).BY            = BY;
    data.(site).BZ            = BZ;
    data.(site).dt_seconds    = dt_sec;
    data.(site).sampling_note = "10 s cadence";

    data.(site).qc.usable = true;
    data.(site).qc.processed = false;
    data.(site).qc.notes  = "OTT Ottawa magnetometer, 10-s cadence.";

    fprintf("\n 5C: OTT merged (%d samples, %.1f s cadence).", ...
        numel(t_ott), dt_sec);
end

%% 5D - Drop excluded sites (checked for gaps/quality, judged unusable -- dropped
%%       now so they never reach the map, site tally, or any downstream step)
for c = 1
    if isfield(E, 'exclude_sites') && ~isempty(E.exclude_sites)
        present = intersect(E.exclude_sites, fieldnames(data));
        if ~isempty(present)
            data = rmfield(data, present);
            fprintf("\n 5D: Dropped excluded site(s): %s", strjoin(present, ', '));
        end
    end
end

%% 6A - Attach geo + magnetic coordinate metadata from CSV
fprintf("\n Total sites in data struct: %d\n", numel(fieldnames(data)));

for c = 1
    geo_path = fullfile(paths.high_frequency_path, ing.geo_csv);
    geoinfo = readtable(geo_path);

    sites = fieldnames(data);
    missing_geo = string.empty;

    for k = 1:numel(sites)
        s = sites{k};
        idx = find(strcmp(geoinfo.site, s), 1);

        if isempty(idx)
            data.(s).lat     = NaN;
            data.(s).lon     = NaN;
            data.(s).cgm_lat = NaN;
            data.(s).cgm_lon = NaN;
            data.(s).cdm_lat = NaN;
            data.(s).cdm_lon = NaN;

            if ~isfield(data.(s), "qc") || ~isstruct(data.(s).qc)
                data.(s).qc = struct();
            end
            if ~isfield(data.(s).qc, "notes"); data.(s).qc.notes = ""; end
            data.(s).qc.notes = strtrim(data.(s).qc.notes + " Missing in geo CSV.");

            missing_geo(end+1) = string(s); %#ok<AGROW>
            continue
        end

        data.(s).lat     = geoinfo.lat(idx);
        data.(s).lon     = geoinfo.lon(idx);
        data.(s).cgm_lat = geoinfo.cgm_lat(idx);
        data.(s).cgm_lon = geoinfo.cgm_lon(idx);
        data.(s).cdm_lat = geoinfo.cdm_lat(idx);
        data.(s).cdm_lon = geoinfo.cdm_lon(idx);
    end

    if ~isempty(missing_geo)
        fprintf("WARNING: %d sites missing geo info: %s\n", numel(missing_geo), strjoin(missing_geo, ", "));
    else
        disp("All sites found in geo CSV.")
    end
    fprintf("\n 6A: Location info added.")
end

%% 6B - Update temporal resolution info
for c = 1
    geo_path = fullfile(paths.high_frequency_path, ing.geo_csv);
    geoinfo  = readtable(geo_path);

    if ~ismember("res_s", geoinfo.Properties.VariableNames)
        geoinfo.res_s = nan(height(geoinfo), 1);
    end

    sites = fieldnames(data);
    missing_in_csv = string.empty;
    bad_tres       = string.empty;

    for k = 1:numel(sites)
        s = sites{k};

        if ~isfield(data.(s), "datetime") || numel(data.(s).datetime) < 2
            data.(s).tres = NaN;
            bad_tres(end+1) = string(s); %#ok<AGROW>
            continue
        end

        t = data.(s).datetime;

        if isnumeric(t)
            t = datetime(t, "ConvertFrom", "datenum");
        end

        dt = seconds(diff(t));
        dt = dt(isfinite(dt) & dt > 0);

        if isempty(dt)
            data.(s).tres = NaN;
            bad_tres(end+1) = string(s); %#ok<AGROW>
            continue
        end

        tres_s = median(dt);
        data.(s).tres = tres_s;

        idx = find(strcmp(geoinfo.site, s), 1);
        if isempty(idx)
            missing_in_csv(end+1) = string(s); %#ok<AGROW>
        else
            geoinfo.res_s(idx) = tres_s;
        end
    end

    [p, f, ext] = fileparts(geo_path);
    geo_out = fullfile(p, f + "_with_res" + ext);

    writetable(geoinfo, geo_out);
    fprintf("\n 6B: Wrote updated geo CSV with res_s to:\n  %s\n", geo_out);
end

%% 7 - Save united dataset
% Written to processed_data_root (local disk, travels with this machine)
% rather than the raw-data drive, so it's available regardless of which
% external drive is plugged in. Dated filename -- never overwrites a
% previous run's output; consumers pick the most recent via
% F_findLatestUnitedData rather than assuming one fixed name.
if ~isfolder(paths.processed_high_frequency_path)
    mkdir(paths.processed_high_frequency_path);
end
[~, base_name, ext] = fileparts(E.united_data_fname);
today_str = string(datetime('now', 'Format', 'yyyyMMdd'));
out_fname = base_name + "_" + today_str + ext;
out_path = fullfile(paths.processed_high_frequency_path, out_fname);
save(out_path, 'data', 'E');
fprintf("\n 7: United dataset saved: %s", string(out_path))

%% 8 - Load united dataset
clc; clearvars -except E out_path
load(out_path, 'data');
fprintf("\n 8: United dataset loaded: %s", string(out_path))

%% 9 - Summary table / quick sanity checks
for c=1
    sites = fieldnames(data);

    sources = strings(size(sites));
    has_geo = false(size(sites));

    for k = 1:numel(sites)
        s = sites{k};
        sources(k) = string(data.(s).source);

        has_geo(k) = isfield(data.(s), "lat") && ~isnan(data.(s).lat) && ...
            isfield(data.(s), "lon") && ~isnan(data.(s).lon);
    end

    fprintf("Total stations: %d\n", numel(sites));
    fprintf("IMAGE stations: %d\n", sum(sources == "IMAGE"));
    fprintf("Greenland stations: %d\n", sum(sources == "DTU"));
    fprintf("CARISMA stations: %d\n", sum(sources == "CARISMA"));
    fprintf("Stations with geo coords: %d\n", sum(has_geo));

    if any(~has_geo)
        fprintf("Missing geo coords for: %s\n", strjoin(string(sites(~has_geo)), ", "));
    end
end
%% 10) Calculate and plot H and Z timeseries at each site

%% 11) Clean data (spike removal) + gap handling

%% 12) High-pass filtering + plot + export
