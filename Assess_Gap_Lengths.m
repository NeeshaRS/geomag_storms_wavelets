%% Assess_Gap_Lengths.m
% Diagnostic: for a chosen event, report every contiguous data gap
% (after spike removal, before any interpolation) across all sites --
% length, start/end time. Writes results to a spreadsheet for review.
% Meant to inform a decision on a max-gap-to-interpolate threshold for
% F_interpNans -- not itself part of the pipeline.
clc; clear all; close all;

%% 0) Paths + config
addpath matlab_functions/
paths = F_loadPaths();

%% 1) SELECT EVENT
all_events = F_loadEvents();
mappable = arrayfun(@(e) ~isempty(e.united_data_fname), all_events);
events = all_events(mappable);
event_idx = 2;
E = events(event_idx);
fprintf("=== Gap assessment for event %d/%d: %s ===\n\n", event_idx, numel(events), E.id);

%% 2) LOAD DATA
[matpath, matfname] = F_findLatestUnitedData(paths.processed_high_frequency_path, E.united_data_fname);
S = load(matpath);
data = S.data;
fprintf("...loaded %s\n\n", matfname);

%% 3) Per-site + per-gap collection
sites = fieldnames(data);
if isfield(E, 'exclude_sites') && ~isempty(E.exclude_sites)
    sites = sites(~ismember(sites, E.exclude_sites));
end

Z_THRESHOLDS = struct('IMAGE', 99999, 'CARISMA', 99999, 'OTT', 80000, 'DTU', 99999);

site_summary = table('Size', [0 7], ...
    'VariableTypes', {'string','string','double','double','double','datetime','datetime'}, ...
    'VariableNames', {'site','source','n_gaps','pct_nan','max_gap_hrs','timestamp_start_max_gap','timestamp_end_max_gap'});

gap_list = table('Size', [0 7], ...
    'VariableTypes', {'string','string','datetime','datetime','double','double','logical'}, ...
    'VariableNames', {'site','source','gap_start','gap_end','duration_s','duration_hrs','overlaps_analysis_window'});

% Analysis window (events.json's dst_window -- used for wavelet peak/
% integrated-power calculations), if defined for this event.
has_window = isfield(E, 'dst_window') && ~isempty(E.dst_window);
if has_window
    win_start = datetime(E.dst_window.start);
    win_end   = datetime(E.dst_window.end);
    fprintf("Analysis window: %s to %s\n\n", datestr(win_start), datestr(win_end));
end

for k = 1:numel(sites)
    s = sites{k};
    d = data.(s);
    if ~isfield(d, 'source'); continue; end
    src = char(string(d.source));

    if isfield(d, 'BY') && ~strcmp(src, 'DTU')
        y = sqrt(d.BX.^2 + d.BY.^2);  % geographic network: H = sqrt(X^2+Y^2)
    else
        y = d.BX;  % Greenland: BX already = H
    end
    t = d.datetime;

    zt = 99999;
    if isfield(Z_THRESHOLDS, src); zt = Z_THRESHOLDS.(src); end
    y = F_removeSpikes(y, zt);

    nanmask = isnan(y);
    pct_nan = 100 * sum(nanmask) / numel(nanmask);

    d1 = diff([0; nanmask(:); 0]);
    starts = find(d1==1);
    ends = find(d1==-1) - 1;
    n_gaps = numel(starts);

    max_gap_s = 0;
    max_gap_start = NaT;
    max_gap_end = NaT;
    for g = 1:n_gaps
        gap_start = t(max(starts(g)-1,1));
        gap_end   = t(min(ends(g)+1, numel(t)));
        gap_s = seconds(gap_end - gap_start);

        overlaps = false;
        if has_window
            overlaps = (gap_start < win_end) && (gap_end > win_start);
        end

        gap_list = [gap_list; {string(s), string(src), gap_start, gap_end, gap_s, gap_s/3600, overlaps}]; %#ok<AGROW>

        if gap_s > max_gap_s
            max_gap_s = gap_s;
            max_gap_start = gap_start;
            max_gap_end = gap_end;
        end
    end

    site_summary = [site_summary; {string(s), string(src), n_gaps, pct_nan, max_gap_s/3600, max_gap_start, max_gap_end}]; %#ok<AGROW>
end

disp(site_summary)

%% 4) Overall gap-length distribution
fprintf("\n=== Gap-length distribution across all sites (%d gaps total) ===\n", height(gap_list));
edges_s = [0 60 300 1800 3600 21600 86400 Inf];
labels = ["<1 min","1-5 min","5-30 min","30-60 min","1-6 hr","6-24 hr",">24 hr"];
counts = histcounts(gap_list.duration_s, edges_s);
for i = 1:numel(labels)
    fprintf("  %-10s : %d\n", labels(i), counts(i));
end

%% 5) Gaps exceeding 1 hour -- print with exact timing
over_1hr = gap_list(gap_list.duration_s >= 3600, :);
over_1hr = sortrows(over_1hr, 'gap_start');
fprintf("\n=== Gaps exceeding 1 hour (%d) -- exact timing ===\n", height(over_1hr));
for i = 1:height(over_1hr)
    fprintf("  %-6s %-8s %s to %s (%.1f hr) overlaps_analysis_window=%d\n", over_1hr.site(i), over_1hr.source(i), ...
        datestr(over_1hr.gap_start(i)), datestr(over_1hr.gap_end(i)), over_1hr.duration_hrs(i), over_1hr.overlaps_analysis_window(i));
end

%% 6) Write to spreadsheet
out_path = fullfile(paths.processed_high_frequency_path, sprintf("%s_gap_assessment.xlsx", extractBefore(E.id, 5)));
writetable(site_summary, out_path, 'Sheet', 'Site Summary');
writetable(gap_list, out_path, 'Sheet', 'All Gaps');
fprintf("\nSpreadsheet written: %s\n", out_path);
