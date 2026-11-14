function F_powerTimeLatHeatmap(time, power_ts, station_mag_lats, fname, varargin)
% F_powerTimeLatHeatmap
%   Heatmap of power over time (x) and magnetic latitude (y).
%   Stations are sorted by latitude (high → low). Color = log10(power) by default.
%
% INPUTS
%   time               : [T x 1] datetime or datenum
%   power_ts           : [T x N] numeric power, one column per station
%   station_mag_lats   : [1 x N] or [N x 1] magnetic latitudes (deg)
%   fname              : filename to save (e.g., 'heatmap.png')
%
% NAME-VALUE (optional)
%   'LogPower'         : true|false (default: true)  % log10 of power
%   'Colormap'         : colormap handle or Nx3 array (default: parula)
%   'CLim'             : [cmin cmax] for color axis (default: auto)
%   'SaturationThreshold' : scalar log10(power) value above which color is saturated (default: [])
%   'YTickEvery'       : label every k-th station (default: 2 or auto)
%   'FigSizeInches'    : [W H] (default: [8 3])
%   'ShowMaxLine'      : true|false (default: false)  % overlay grey line at max per time
%   'ShowMax'          : true|false (default: false)  % overlay grey * at max per time
%   'DstOverlay'       : [T x 1] Dst values matching `time` (default: []) --
%                        overlays a grey Dst line on its own right-side
%                        y-axis, instead of/alongside the ShowMax markers
%   'DstYLim'          : [ymin ymax] for the Dst axis (default: auto) --
%                        set this to the same range across events (e.g.
%                        [-600 0]) to make storms visually comparable
%   'EventTimes'       : [K x 1] datetime (default: []) -- marks each time
%                        (e.g. power-grid failures, see F_loadFailureTimes)
%                        with a black dashed vertical line across the
%                        heatmap and a filled black down-triangle just
%                        above the top edge. Times outside the plotted
%                        range are skipped with a warning.
%
% Example:
%   F_powerTimeLatHeatmap(time, P, lats, 'heat.png', 'LogPower', true, ...
%                           'YTickEvery', 2, 'ShowMaxLine', true);
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 

% ---- Parse options
p = inputParser;
p.addParameter('LogPower', true, @(x)islogical(x)&&isscalar(x));
p.addParameter('Colormap', @parula);
p.addParameter('CLim', [], @(x)isnumeric(x)&&numel(x)==2 || isempty(x));
p.addParameter('SaturationThreshold', [], @(x)isnumeric(x)&&isscalar(x));
p.addParameter('YTickEvery', [], @(x)isnumeric(x)&&isscalar(x) || isempty(x));
p.addParameter('FigSizeInches', [10 3], @(x)isnumeric(x)&&numel(x)==2);
p.addParameter('ShowMaxLine', false, @(x)islogical(x)&&isscalar(x));
p.addParameter('ShowMax', false, @(x)islogical(x)&&isscalar(x));
p.addParameter('XTickVals', [], @(x)(isnumeric(x) || isdatetime(x) || isempty(x)));
p.addParameter('DstOverlay', [], @(x)isnumeric(x) || isempty(x));
p.addParameter('DstYLim', [], @(x)isnumeric(x)&&numel(x)==2 || isempty(x));
p.addParameter('EventTimes', [], @(x)isdatetime(x) || isempty(x));
p.parse(varargin{:});
opt = p.Results;

% ---- Normalize inputs
if isrow(station_mag_lats), station_mag_lats = station_mag_lats(:); end
[T, N] = size(power_ts);
if numel(station_mag_lats) ~= N
    error('station_mag_lats must have one latitude per station (N columns).');
end
if ~isdatetime(time)
    time = datetime(time, 'ConvertFrom','datenum');
end
if numel(time) ~= T
    error('time length (%d) must match rows of power_ts (%d).', numel(time), T);
end
if ~isempty(opt.DstOverlay) && numel(opt.DstOverlay) ~= T
    error('DstOverlay length (%d) must match rows of power_ts (%d).', numel(opt.DstOverlay), T);
end

% ---- Trim to the range where at least one station has data -- avoids
% wasting plot width on an all-gray margin when `time` extends past
% where every station is simultaneously NaN (same cause as
% F_stormPowerIndexMovie's "keeps animating with nothing to show" fix).
any_valid = any(~isnan(power_ts), 2);
first_t = find(any_valid, 1, 'first');
last_t  = find(any_valid, 1, 'last');
if isempty(first_t)
    error('power_ts is entirely NaN -- nothing to plot.');
end
time = time(first_t:last_t);
power_ts = power_ts(first_t:last_t, :);
if ~isempty(opt.DstOverlay)
    opt.DstOverlay = opt.DstOverlay(first_t:last_t);
end
T = numel(time);

% ---- Sort stations by latitude (high → low)
[lat_sorted, order] = sort(station_mag_lats(:), 'descend');
P = power_ts(:, order);

% ---- Transform to log10 if requested
if opt.LogPower
    P(P<=0) = NaN;
    P = log10(P);
end

% ---- Figure & axes (reserve room for colorbar, and for the Dst axis if requested)
fig = figure('Units','inches','Position',[0 10 opt.FigSizeInches], 'Color','w');
% Bottom margin (0.32, was 0.18) leaves room for the rotated date tick
% labels + the "Date" axis label without getting clipped at the figure
% edge -- top height trimmed by the same amount so the plot's top edge
% doesn't move.
if ~isempty(opt.DstOverlay)
    ax_pos = [0.08 0.32 0.60 0.60]; % narrower, leaves room for a Dst axis before the colorbar
    cbar_pos = [0.90 0.32 0.03 0.60];
else
    ax_pos = [0.10 0.32 0.72 0.60];
    cbar_pos = [];
end
ax  = axes('Parent', fig, 'Position', ax_pos); % [left bottom width height]
ax.PositionConstraint = 'innerposition';

% ---- Heatmap with NaN transparency
X = datenum(time);

% Solid grey backdrop, drawn first: NaN cells in the data image (made
% transparent below via AlphaData) reveal this instead of the figure's
% white background, so they read as "no data" rather than blending in
% with real low-power cells (white, under a white-low colormap). Setting
% ax.Color alone doesn't work here -- it doesn't survive exportgraphics'
% 'ContentType','image' flattening against its own BackgroundColor.
grey_backdrop = repmat(reshape([0.75 0.75 0.75], 1, 1, 3), N, numel(X));
image(ax, X, 1:N, grey_backdrop);
hold(ax, 'on');

h_img = imagesc(ax, X, 1:N, P.');
set(ax,'YDir','reverse');  % high lat at top
h_img.AlphaData = ~isnan(P).';

% ---- Optional grey max line (index of max power vs time)
if opt.ShowMaxLine
    % Copy P and replace NaNs so they don't win the max
    Ptmp = P;
    allNaN = all(isnan(Ptmp), 2);       % times with no valid data
    Ptmp(isnan(Ptmp)) = -Inf;

    % For each time (row), find station index of maximum power
    [~, idx_max] = max(Ptmp, [], 2);    % [T x 1], values 1..N

    % Set y to NaN where all stations were NaN so the line breaks
    y_line = double(idx_max);
    y_line(allNaN) = NaN;

    % Plot the line in grey on the same axes (x = time, y = station index)
    plot(ax, X, y_line, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
end
% ---- Optional grey max * (index of max power vs time)
if opt.ShowMax
    % Copy P and replace NaNs so they don't win the max
    Ptmp = P;
    allNaN = all(isnan(Ptmp), 2);       % times with no valid data
    Ptmp(isnan(Ptmp)) = -Inf;

    % For each time (row), find station index of maximum power
    [~, idx_max] = max(Ptmp, [], 2);    % [T x 1], values 1..N

    % Set y to NaN where all stations were NaN so the line breaks
    y_line = double(idx_max);
    y_line(allNaN) = NaN;

    % Plot the line in grey on the same axes (x = time, y = station index)
    plot(ax, X, y_line, '*', 'Color', [0.5 0.5 0.5]);
end

% ---- Optional event markers: black dashed vertical line across the
% heatmap + filled black down-triangle just above its top edge. Rows span
% 0.5..N+0.5 in data units with YDir reversed, so "above the top" is
% y < 0.5; Clipping off lets the triangle sit outside the axes.
if ~isempty(opt.EventTimes)
    ev = opt.EventTimes(:);
    in_range = ev >= time(1) & ev <= time(end);
    if any(~in_range)
        warning('F_powerTimeLatHeatmap:eventOutOfRange', ...
            'Skipping %d EventTimes outside the plotted range: %s', nnz(~in_range), ...
            strjoin(string(ev(~in_range), 'yyyy-MM-dd HH:mm:ss'), ', '));
    end
    y_tri = 0.5 - 0.06 * N;
    for x_ev = datenum(ev(in_range)).'
        plot(ax, [x_ev x_ev], [0.5 N+0.5], '--', 'Color', 'k', 'LineWidth', 1.5);
        plot(ax, x_ev, y_tri, 'v', 'MarkerSize', 10, 'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'k', 'Clipping', 'off');
    end
end
ylim(ax, [0.5 N+0.5]); % keep rows filling the axes (markers above must not stretch it)

% ---- Colormap, color limits, and optional log10-threshold saturation
applyColormapWithThreshold(ax, opt.Colormap, opt.LogPower, opt.CLim, opt.SaturationThreshold, cbar_pos);



% ---- Axes labels, ticks, formatting
% Month(s) and year go in the x-axis label, so tick labels can be just the
% day of month (e.g. 12, 13, 14) and stay horizontal in every panel.
t0 = time(1); t1 = time(end);
if year(t0) == year(t1) && month(t0) == month(t1)
    period_str = char(datetime(t0, 'Format', 'MMMM yyyy'));
elseif year(t0) == year(t1)
    period_str = sprintf('%s–%s', char(datetime(t0, 'Format', 'MMMM')), ...
                         char(datetime(t1, 'Format', 'MMMM yyyy')));
else
    period_str = sprintf('%s–%s', char(datetime(t0, 'Format', 'MMMM yyyy')), ...
                         char(datetime(t1, 'Format', 'MMMM yyyy')));
end
xlabel(ax, sprintf('Date (%s)', period_str), 'FontSize', 20);
ylabel(ax,'Station MLat (°)','FontSize',20);
ax.FontSize = 15;

% X ticks
xlim(ax, [X(1) X(end)]);
if ~isempty(opt.XTickVals)
    % Use user-specified tick positions, matching F_plotDst (etc.)
    if isdatetime(opt.XTickVals)
        ax.XTick = datenum(opt.XTickVals);  % convert to datenum to match X
    else
        ax.XTick = opt.XTickVals;           % assume numeric datenums
    end
    disp('Matching Dst xticks.')
else
    % Let MATLAB choose tick positions within the plotted range
    datetick(ax, 'x', 'dd', 'keeplimits');
    disp('Not matching Dst xticks.')
end
% Day-of-month labels without leading zeros (1, 2, ... 31), kept horizontal
ax.XTickLabel = arrayfun(@(d) sprintf('%d', d), ...
    day(datetime(ax.XTick, 'ConvertFrom', 'datenum')), 'UniformOutput', false);
xtickangle(ax, 0);

box(ax,'on');

% Y ticks (sparser labels)
if isempty(opt.YTickEvery)
    if N <= 15, k = 1; elseif N <= 30, k = 2; elseif N <= 60, k = 3; else, k = 5; end
else
    k = max(1, round(opt.YTickEvery));
end
yt = 1:k:N;
set(ax,'YTick', yt, 'YTickLabel', round(lat_sorted(yt),0));

% ---- Optional Dst overlay: grey line on its own right-side y-axis,
% overlaid at the exact same position as the heatmap axes so the x (time)
% alignment matches exactly.
if ~isempty(opt.DstOverlay)
    ax2 = axes('Parent', fig, 'Position', ax.Position, 'Color', 'none');
    ax2.PositionConstraint = 'innerposition';
    hold(ax2, 'on');
    plot(ax2, X, opt.DstOverlay(:), '-', 'Color', [65/255 105/255 225/255], 'LineWidth', 1.5);
    ax2.XLim = ax.XLim;
    ax2.XTick = [];
    ax2.YAxisLocation = 'right';
    ax2.Box = 'off';
    ax2.FontSize = 15;
    ax2.YColor = [65/255 105/255 225/255];
    ylabel(ax2, 'Dst (nT)', 'FontSize', 20, 'Color', [65/255 105/255 225/255]);
    if ~isempty(opt.DstYLim)
        ax2.YLim = opt.DstYLim;
    end
    % NOTE: deliberately not calling axes(ax) here -- that call re-raises
    % ax to the front of the figure's stacking order, which put the
    % (opaque) heatmap right back on top of this line, hiding it.
end

% ---- Save (no clipping)
try
    exportgraphics(fig, fname, 'Resolution', 300, 'ContentType','image', 'BackgroundColor','white');
catch
    % Fallback for older MATLAB
    set(fig, 'PaperPositionMode','auto'); set(fig,'InvertHardcopy','off');
    print(fig, fname, '-dpng', '-r300');
end
disp([char(fname) ' saved.']);
end

% ======================================================================
function applyColormapWithThreshold(ax, cmapIn, isLogPower, CLimOpt, satThr, cbarPosition)
% applyColormapWithThreshold
%   Sets colormap + colorbar on axes AX.
%   Optionally applies a saturation threshold in log10(power) units:
%   any value above satThr maps to the max colormap color.

    % 1) Respect user CLim if provided
    if ~isempty(CLimOpt)
        caxis(ax, CLimOpt);
    end

    % Get actual CLim after imagesc + override (in log10 units if isLogPower)
    cl = caxis(ax);   % [cmin cmax]

    % 2) Build base colormap from handle or array
    if isa(cmapIn, 'function_handle')
        cmap = cmapIn();
    else
        cmap = cmapIn;
    end
    nColors = size(cmap, 1);

    % 3) Threshold-based saturation (assumed in log10 units if isLogPower)
    if ~isempty(satThr) && isLogPower

        % Only apply if threshold is above lower limit
        if satThr > cl(1)
            % Fractional position of threshold in color scale
            f = (satThr - cl(1)) / (cl(2) - cl(1));
            f = max(0, min(1, f));             % clamp to [0, 1]

            % Map to colormap index
            idx = round(f * (nColors - 1)) + 1;
            idx = min(max(1, idx), nColors);

            % Flatten all colors at/above threshold to max color
            cmap(idx:end, :) = repmat(cmap(end, :), nColors - idx + 1, 1);
        end
    end

    % 4) Apply the colormap
    colormap(ax, cmap);

    % 5) Create colorbar + label
    if nargin >= 6 && ~isempty(cbarPosition)
        cb = colorbar(ax, 'Position', cbarPosition);
    else
        cb = colorbar(ax, 'Location','eastoutside');
    end
    if isLogPower
        ylabel(cb, 'log_{10} Power (nT^2)', 'FontSize', 15);
    else
        ylabel(cb, 'Power (nT^2)', 'FontSize', 15);
    end
end
