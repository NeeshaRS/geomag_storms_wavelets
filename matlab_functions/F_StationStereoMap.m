function [sta_map] = F_StationStereoMap(station_geo_lats, station_geo_lons, ...
    cdm_lat, station_colors, fname, varargin)
% F_StationMap  Map of stations colored by geomagnetic latitude color set
% Uses Mapping Toolbox map axes (axesm) to avoid Web Mercator.
% INPUTS:
%   station_colors : [N x 3] RGB, one row per station, same order as the
%     lat/lon/cdm_lat arrays -- literal per-station colors (e.g. from
%     F_purpleRedColormap assigned by latitude rank), used directly
%     instead of colormap()+caxis() so this map's colors always match
%     whatever other plot (e.g. stats_plots_1989.m) assigned them,
%     exactly, station by station -- not just approximately via a shared
%     continuous scale.
%
% NAME-VALUE (optional)
%   'Projection'     : 'stereo' | 'lambertstd' | any AXESM proj (default auto)
%   'MapLatLimit'    : [min max]  % degrees
%   'MapLonLimit'    : [min max]  % degrees (−180..180)
%   'FigureSizeInch' : [W H] (default depends on storm)
%   'Landmarks'      : struct with fields lat, lon (deg E, any wrap) and
%                      colors ([M x 3] RGB, e.g. F_magLatColors) -- drawn
%                      as filled stars on top of the stations. Not used
%                      for the map origin. Default: none.

p = inputParser;
p.addParameter('Projection', '', @(x)ischar(x)||isstring(x));
p.addParameter('storm', '', @(x)ischar(x)||isstring(x));
p.addParameter('MapLatLimit', [], @(x)isnumeric(x)&&numel(x)==2);
p.addParameter('MapLonLimit', [], @(x)isnumeric(x)&&numel(x)==2);
p.addParameter('FigureSizeInch', [], @(x)isnumeric(x)&&numel(x)==2);
p.addParameter('Landmarks', [], @(x)isempty(x)||isstruct(x));
p.parse(varargin{:});
opt = p.Results;

% ---- Figure size
figSize = [12 6];
if ~isempty(opt.FigureSizeInch), figSize = opt.FigureSizeInch; end

% ---- Start figure
sta_map = figure('Color','w','Units','inches','Position',[0 10 figSize]);
disp('Starting mapping.')

% ---- Set projection
projection = 'lambertstd';

% Set map limits
mapLatLim = [45 89.99]; % 45: 44 made the landareas clipping draw a stray line across the map (2026-11-11). NOTE: use <90 to suppress forced pole label in Mapping Toolbox
mapLonLim = [-160 35]; 

% Map center (origin) — use mean station location unless you set pole
lonWrap = station_geo_lons; lonWrap(lonWrap>180) = lonWrap(lonWrap>180)-360;
lat0 = mean(station_geo_lats(:),'omitnan');
lon0 = mean(lonWrap(:),'omitnan');

% ---- Create map axes
ax = axesm(projection, ...
    'Origin',[lat0 lon0 0], ...
    'MapLatLimit',mapLatLim, ...
    'MapLonLimit',mapLonLim, ...
    'Frame','on','FEdgeColor',[0.3 0.3 0.3], ...
    'Grid','on','GLineStyle',':','GColor',[0.7 0.7 0.7], ...
    'MeridianLabel','on','ParallelLabel','on', ...
    'MLabelParallel','south');  % put meridian labels below when possible

% Only label the parallels/meridians you want
setm(gca, ...
    'ParallelLabel', 'on', ...
    'MeridianLabel', 'on', ...
    'PLabelLocation', [45], ...                 % only these latitudes
    'PLabelMeridian', -160, ...                % place lat label near left edge
    'MLabelLocation', [-60 -30 0 ], ...  % only these meridians
    'MLabelParallel', 45);               % place lon labels along 45N (bottom edge, = mapLatLim(1))
                      

setm(ax,'FontSize',20);

set(gca,'Visible','off')   % removes the rectangular axes box
framem on                  % keeps the curved map frame

% ---- Land and coast outlines (no basemap)
% These are shipped with Mapping Toolbox
try
    land = shaperead('landareas','UseGeoCoords',true);
    geoshow(ax, land, 'FaceColor',[0.95 0.95 0.95], 'EdgeColor',[0.6 0.6 0.6]);
catch
    % Fallback to coarse coastlines if shapefile not found
    load coastlines
    geoshow(ax, coastlat, coastlon, 'Color',[0.6 0.6 0.6]);
end

hold(ax,'on');

% ---- Plot stations, colored with the literal per-station RGB passed in
scatterm(station_geo_lats, lonWrap, 70, station_colors, 'filled', 'MarkerEdgeColor','k');

% ---- Landmark cities: filled stars, same magnetic-latitude color scale,
% drawn after the stations so they sit on top. No labels.
if ~isempty(opt.Landmarks) && ~isempty(opt.Landmarks.lat)
    lm_lon = opt.Landmarks.lon(:); lm_lon(lm_lon>180) = lm_lon(lm_lon>180)-360;
    scatterm(opt.Landmarks.lat(:), lm_lon, 300, opt.Landmarks.colors, 'p', 'filled', ...
        'MarkerEdgeColor','k');
    disp('Landmarks plotted.')
end

% Colorbar on the same FIXED 47-90 deg scale used to compute
% station_colors (F_magLatColors) -- shared across all 3 events, not
% rebuilt from this event's own min/max, so the colorbar means the same
% thing (and matches the same colors) on every event's map.
colormap(flipud(F_purpleRedColormap(256))); % low value(47)->red, high value(90)->purple
cb = colorbar;
caxis([47 90]);
cb.Label.String = 'Magnetic Latitude (°)';
cb.Label.FontSize = 15;
disp('Stations plotted.')

% ---- Save figure
set(gcf, 'PaperPositionMode', 'auto')  % preserves on-screen size
print(gcf, fname, '-dpng', '-r300')    % 300 dpi PNG
disp(['Saved ' fname '.'])

% ---- Done
disp('Map made.')

end
