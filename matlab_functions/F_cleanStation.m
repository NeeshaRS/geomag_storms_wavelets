function [t, y, info] = F_cleanStation(t, y, E, site, opts)
% F_cleanStation  Per-station cleaning on the station's OWN timestamps, before
% any common grid. Shared by Network_event_plotting.m and
% Greenland_event_plotting.m. Steps, in this order:
%
%   1) TRIM       -- clip to the event window and apply per-station overrides.
%   2) GAP CHECK  -- NaN, filler (> spike_threshold) and timestamp-jump gaps; flags
%                    stations with an internal gap >= max_gap_minutes.
%   3) SPIKES     -- flat threshold, then Hampel local-outlier pass, then the
%                    gap check again (spike removal can open new gaps). Skipped
%                    for a station already dropped at step 2 -- if it has a
%                    gap that long, its spikes don't matter.
%   4) INTERPOLATE -- fill the remaining (< max_gap_minutes) NaN gaps linearly
%                    with F_interpNans, on the station's own timestamps.
%                    Missing TIMESTAMPS (short jumps in t, no NaN row) are not
%                    filled here -- they get bridged when the cleaned series is
%                    placed on the event grid.
%
% INPUTS:
%   t     datetime vector (the station's own timestamps)
%   y     data vector, same length as t (H, Z, or BX -- one component at a time)
%   E     event struct from F_loadEvents (needs .ingestion.start/.end;
%         optional .station_start_overrides / .station_end_overrides /
%         .max_gap_minutes)
%   site  station code (field name in `data`), used to look up its overrides
%   opts  (optional) struct:
%           .spike_threshold  flat upper threshold, values above -> NaN
%                             (default 80000; Greenland_event_plotting.m uses 90000)
%           .hampel           apply the Hampel pass (default true; the network
%                             script applies it to H only, not Z)
%           .keep_gappy       if true, a long internal gap never drops the station
%                             and steps 3-4 still run (default false). Used for Z,
%                             which follows H's keep/drop decision; gaps >= the cap
%                             then stay NaN. A station with no valid data at all is
%                             still flagged dropped.
%
% OUTPUTS:
%   t, y  the cleaned series: trimmed (shorter, not NaN-padded), spikes removed,
%         small gaps interpolated, leading/trailing NaN truncated
%   info  struct of what happened, for the per-event station CSV and VERIFY:
%         n_in, first_in, last_in, trim_start, trim_end, n_after_trim (step 1);
%         n_nan, n_filler, cadence_s, max_gap_min, gap_start, gap_end (step 2);
%         n_spikes_flat, n_spikes_hampel, max_gap_min_post, gap_start_post,
%         gap_end_post (step 3); n_interpolated, n_final, first_valid,
%         last_valid, n_nan_final (step 4); dropped, drop_reason (steps 2-4).

if nargin < 5 || isempty(opts); opts = struct(); end
if ~isfield(opts, 'spike_threshold') || isempty(opts.spike_threshold); opts.spike_threshold = 80000; end
if ~isfield(opts, 'hampel') || isempty(opts.hampel); opts.hampel = true; end
if ~isfield(opts, 'keep_gappy') || isempty(opts.keep_gappy); opts.keep_gappy = false; end
drop_on_gap = ~opts.keep_gappy;

t = t(:);
y = y(:);

info = struct();
info.n_in     = numel(t);
info.first_in = t(1);
info.last_in  = t(end);

%% 1) TRIM
% Effective window = event window (ingestion.start/end), narrowed by this
% station's start/end override if it has one (events.json
% station_start_overrides / station_end_overrides).
lo = datetime(E.ingestion.start);
hi = datetime(E.ingestion.end);

if isfield(E, 'station_start_overrides') && isstruct(E.station_start_overrides) ...
        && isfield(E.station_start_overrides, site)
    lo = max(lo, datetime(E.station_start_overrides.(site)));
end
if isfield(E, 'station_end_overrides') && isstruct(E.station_end_overrides) ...
        && isfield(E.station_end_overrides, site)
    hi = min(hi, datetime(E.station_end_overrides.(site)));
end

keep = (t >= lo) & (t <= hi);
t = t(keep);
y = y(keep);

info.trim_start    = lo;
info.trim_end      = hi;
info.n_after_trim  = numel(t);

%% 2) GAP CHECK -- NaN, filler values, and timestamp jumps
% CHECK ONLY: y is not changed here (filler is replaced in the spike step
% below). A sample is "valid" if it is neither NaN nor filler (see
% FILL_THRESHOLD below). The internal gap is the longest stretch between
% two neighbouring valid samples, minus one cadence -- so NaN runs, filler runs
% and missing timestamps (jumps in t) all count the same way, and leading or
% trailing missing data (before the first / after the last valid sample) is
% ignored. Matches F_maxInternalGapMinutes when timestamps are uniform.
% A station whose longest internal gap is >= E.max_gap_minutes is flagged
% info.dropped (the caller drops it); events with max_gap_minutes null never drop.
% Filler = anything above the same per-network flat threshold used in step 3
% (opts.spike_threshold: 80000 IMAGE/CARISMA/OTT, 90000 DTU). That is why the
% thresholds sit below 99999: it catches exact 99999.0 fill (DTU 2024, e.g. SVS)
% as well as 99999.9 / 100000 fill.
FILL_THRESHOLD = opts.spike_threshold;

info.n_nan    = sum(isnan(y));
info.n_filler = sum(y > FILL_THRESHOLD);

cadence_s = NaN;
if numel(t) > 1; cadence_s = seconds(median(diff(t))); end
info.cadence_s = cadence_s;

max_gap_limit = Inf;
if isfield(E, 'max_gap_minutes') && ~isempty(E.max_gap_minutes)
    max_gap_limit = E.max_gap_minutes;
end

is_valid = ~isnan(y) & ~(y > FILL_THRESHOLD);
[info.max_gap_min, info.gap_start, info.gap_end] = local_internal_gap(t, is_valid, cadence_s);

info.dropped = ~any(is_valid) || (drop_on_gap && isfinite(max_gap_limit) && info.max_gap_min >= max_gap_limit);
if ~any(is_valid)
    info.drop_reason = "no valid data";
elseif info.dropped
    info.drop_reason = sprintf("internal gap %.1f min (%s to %s)", info.max_gap_min, ...
        string(info.gap_start, 'yyyy-MM-dd HH:mm:ss'), string(info.gap_end, 'yyyy-MM-dd HH:mm:ss'));
else
    info.drop_reason = "";
end

info.n_spikes_flat      = NaN;
info.n_spikes_hampel    = NaN;
info.max_gap_min_post   = NaN;
info.gap_start_post     = NaT;
info.gap_end_post       = NaT;
info.n_interpolated     = NaN;
info.n_final            = NaN;
info.first_valid        = NaT;
info.last_valid         = NaT;
info.n_nan_final        = NaN;

if info.dropped
    return  % too gappy already -- skip spike removal
end

%% 3) SPIKE REMOVAL, then gap check again
% Flat threshold first (also removes any filler, since the threshold is below
% 99999), then the Hampel-style local-outlier pass (5 min window, 6 robust
% sigma, 300 nT floor -- validated on 2003 CARISMA, see events.json notes).
n0 = sum(isnan(y));
y = F_removeSpikes(y, opts.spike_threshold);
n1 = sum(isnan(y));
info.n_spikes_flat = n1 - n0;

if opts.hampel
    y = F_removeJumpSpikes(t, y, 5, 6, 300);
end
info.n_spikes_hampel = sum(isnan(y)) - n1;

% Spike removal can open new gaps (e.g. a run of glitches) -- check again.
[info.max_gap_min_post, info.gap_start_post, info.gap_end_post] = local_internal_gap(t, ~isnan(y), cadence_s);
if ~any(~isnan(y))
    info.dropped = true;
    info.drop_reason = "no valid data after spike removal";
elseif drop_on_gap && isfinite(max_gap_limit) && info.max_gap_min_post >= max_gap_limit
    info.dropped = true;
    info.drop_reason = sprintf("after spike removal: internal gap %.1f min (%s to %s)", info.max_gap_min_post, ...
        string(info.gap_start_post, 'yyyy-MM-dd HH:mm:ss'), string(info.gap_end_post, 'yyyy-MM-dd HH:mm:ss'));
end

if info.dropped
    return  % spike removal opened a too-long gap -- nothing more to do
end

%% 4) INTERPOLATE small gaps
% Every NaN gap still here is < max_gap_minutes (longer ones dropped the station
% above), so F_interpNans' own cap is only a backstop. It truncates leading /
% trailing NaN rather than extrapolating, then fills internal gaps LINEARLY
% (bounded between the neighbouring samples -- no spline overshoot).
n_before   = numel(t);
nan_before = sum(isnan(y));
if isfinite(max_gap_limit); cap = max_gap_limit; else; cap = []; end
[t, y] = F_interpNans(t, y, cap);
t = t(:);
y = y(:);

info.n_final        = numel(t);
info.n_nan_final    = sum(isnan(y));
info.n_interpolated = nan_before - (n_before - info.n_final) - info.n_nan_final;
info.first_valid    = t(1);
info.last_valid     = t(end);
if info.n_nan_final > 0 && drop_on_gap
    info.dropped = true;
    info.drop_reason = sprintf("%d NaN left after interpolation", info.n_nan_final);
end

end


function [max_gap_min, gap_start, gap_end] = local_internal_gap(t, is_valid, cadence_s)
% Longest internal gap in minutes (stretch between neighbouring valid samples
% minus one cadence), and the valid samples bounding it.
max_gap_min = NaN;
gap_start = NaT;
gap_end = NaT;
tv = t(is_valid);
if numel(tv) > 1
    spans = seconds(diff(tv));
    [max_span_s, ix] = max(spans);
    max_gap_min = max(0, (max_span_s - cadence_s) / 60);
    gap_start = tv(ix);
    gap_end = tv(ix + 1);
end
end
