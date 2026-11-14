function [t_grid, Y, info] = F_placeOnEventGrid(t_cell, y_cell, E, network, gopts)
% F_placeOnEventGrid  Put already-cleaned stations (F_cleanStation output) onto
% ONE full-coverage time grid for the event/network. Replaces the old
% "regrid onto the first station's timestamps" step, which truncated every
% station to that station's span and bridged gaps before they were checked.
%
% The grid comes from the event config, not from any station:
%   start = E.ingestion.start, end = E.ingestion.end (CARISMA: its own
%   E.ingestion.carisma.end_override if set), at the network's cadence (the
%   stations of one network share one cadence in every event; an error is
%   raised if they don't). The grid's timestamp PHASE follows the network's
%   dominant sample phase (e.g. 2003 DTU samples fall at :10/:30/:50 on a 20 s
%   cadence, so its grid starts at 00:00:10), so most stations land exactly on
%   grid points and are not smoothed by a half-sample interpolation. Each station is linearly interpolated onto the grid
%   from its own valid samples and is NaN wherever it has no data -- leading
%   and trailing coverage is never extrapolated. Short missing-timestamp jumps
%   inside a station's record (no NaN row, so F_interpNans never saw them) are
%   bridged here; F_cleanStation already guaranteed every internal gap is
%   < max_gap_minutes.
%
% INPUTS:
%   t_cell   1xN or Nx1 cell of datetime vectors (each station's own timestamps)
%   y_cell   same-size cell of data vectors (no NaN inside a station's record)
%   E        event struct (needs .ingestion.start/.end)
%   network  string, e.g. "IMAGE", "CARISMA", "OTT", "DTU"
%   gopts    (optional) struct:
%              .t_grid     use this exact grid instead of building one (so a second
%                          component, e.g. Z, lands on H's grid)
%              .limit_min  gaps between a station's valid samples of at least this
%                          many minutes are left NaN instead of bridged (default
%                          Inf = bridge everything; used for Z, whose long gaps
%                          are deliberately left NaN)
%
% OUTPUTS:
%   t_grid   column datetime vector (the event grid)
%   Y        numel(t_grid) x N matrix, one column per station, NaN outside its span
%   info     struct: cadence_s, phase_s, grid_start, grid_end, n_grid, and per-station
%            columns first_valid, last_valid, n_nan_inside (NaN between its
%            first and last valid grid points; should be 0)

if nargin < 5 || isempty(gopts); gopts = struct(); end
N = numel(t_cell);

% Network cadence = median of the stations' own median cadences; they should agree.
cad = nan(N, 1);
for k = 1:N
    cad(k) = seconds(median(diff(t_cell{k}(:))));
end
cadence_s = median(cad);
if any(abs(cad - cadence_s) > 0.01 * cadence_s)
    error('F_placeOnEventGrid:mixedCadence', ...
        '%s stations do not share one cadence (%s s) -- decide how to grid them before continuing.', ...
        network, strjoin(string(cad'), ', '));
end

t_start = datetime(E.ingestion.start);
t_end   = datetime(E.ingestion.end);
if string(network) == "CARISMA" && isfield(E.ingestion, 'carisma') && isstruct(E.ingestion.carisma) ...
        && isfield(E.ingestion.carisma, 'end_override') && ~isempty(E.ingestion.carisma.end_override)
    t_end = min(t_end, datetime(E.ingestion.carisma.end_override));
end

% Dominant phase: where each station's samples fall relative to t_start (modulo
% the cadence); the most common phase across stations wins (ties -> smallest).
phase = nan(N, 1);
for k = 1:N
    tk = t_cell{k}(:);
    tk = tk(1:min(numel(tk), 1000));
    phase(k) = mode(round(mod(seconds(tk - t_start), cadence_s), 3));
end
phase_s = mode(phase);

t_grid = (t_start + seconds(phase_s) : seconds(cadence_s) : t_end).';
if isfield(gopts, 't_grid') && ~isempty(gopts.t_grid); t_grid = gopts.t_grid(:); end

Y = nan(numel(t_grid), N);
first_valid = NaT(N, 1);
last_valid  = NaT(N, 1);
n_nan_inside = zeros(N, 1);
for k = 1:N
    tk = t_cell{k}(:);
    yk = y_cell{k}(:);
    ok = ~isnan(yk);
    tk = tk(ok);
    yk = yk(ok);
    % interp1 needs strictly increasing sample points (a few raw sources carry
    % duplicate timestamps) -- keep the first of each.
    [tk, ia] = unique(tk, 'sorted');
    yk = yk(ia);
    if numel(tk) < 2; continue; end
    Y(:, k) = interp1(tk, yk, t_grid, 'linear');   % NaN outside [tk(1), tk(end)]
    if isfield(gopts, 'limit_min') && isfinite(gopts.limit_min)
        % leave long internal gaps NaN rather than bridging them
        long_gap = find(seconds(diff(tk)) - cadence_s >= gopts.limit_min * 60);
        for g = long_gap(:)'
            Y(t_grid > tk(g) & t_grid < tk(g+1), k) = NaN;
        end
    end
    v = find(~isnan(Y(:, k)));
    if ~isempty(v)
        first_valid(k) = t_grid(v(1));
        last_valid(k)  = t_grid(v(end));
        n_nan_inside(k) = sum(isnan(Y(v(1):v(end), k)));
    end
end

info = struct('cadence_s', cadence_s, 'phase_s', phase_s, 'grid_start', t_grid(1), 'grid_end', t_grid(end), ...
    'n_grid', numel(t_grid), 'first_valid', first_valid, 'last_valid', last_valid, ...
    'n_nan_inside', n_nan_inside);

end
