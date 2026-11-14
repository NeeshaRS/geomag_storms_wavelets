function cmap = F_purpleRedColormap(n)
% F_purpleRedColormap  Dark purple -> hot red sequential colormap.
% Low index = purple, high index = red. Shared between the station map
% (F_StationStereoMap, colored by magnetic latitude) and the power stats
% plots (stats_plots_1989.m, colored by station) so both use the same
% palette -- bright red for low-latitude stations makes them
% more visible.
%
% INPUT (optional): n, number of colors (default: 256, so it also works
% as a bare function handle, e.g. 'Colormap', @F_purpleRedColormap)

if nargin < 1 || isempty(n)
    n = 256;
end

anchors = [0.18 0.00 0.35;   % deep purple
           0.42 0.10 0.65;   % purple-magenta
           0.90 0.25 0.70;   % hot pink
           0.95 0.05 0.10];  % bright red

x_anchor = linspace(0, 1, size(anchors,1));
x_query  = linspace(0, 1, n);
cmap = interp1(x_anchor, anchors, x_query, 'pchip');
cmap = max(min(cmap, 1), 0);

end
