function station_colors = F_magLatColors(mag_lat)
% F_magLatColors  Purple(high lat) -> red(low lat) color per station, on
% a FIXED absolute magnetic-latitude scale (47 to 90 degrees) shared
% across all events -- so the same physical latitude always gets the
% same color, and colorbars/legends are directly comparable event to
% event. Replaces the old per-event rank-based assignment (F_purpleRedColormap
% applied by station RANK within that event's own list), where "reddest"
% just meant "lowest-latitude station in THIS event," not a fixed value.
%
% INPUT:
%   mag_lat  magnetic latitude magnitude (degrees, positive -- if your
%            data stores cdm_lat negative, per this repo's convention,
%            pass in -cdm_lat), one value per station. Values outside
%            [47 90] are clamped rather than extrapolated.
%
% OUTPUT:
%   station_colors  [N x 3] RGB, same order as the input
%
% See also F_purpleRedColormap. Shared range is defined here (LAT_MIN/
% LAT_MAX) -- change once, applies everywhere this function is used
% (Map_Events.m, stats_plots_*.m).

LAT_MIN = 47;
LAT_MAX = 90;

frac = (mag_lat(:) - LAT_MIN) / (LAT_MAX - LAT_MIN);
frac = max(0, min(1, frac));

cmap = F_purpleRedColormap(256);
% high lat (frac=1) -> index 1 (purple); low lat (frac=0) -> index end (red)
idx = round((1 - frac) * (size(cmap,1)-1)) + 1;
station_colors = cmap(idx, :);

end
