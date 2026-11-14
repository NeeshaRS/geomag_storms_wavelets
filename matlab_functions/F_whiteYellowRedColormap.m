function cmap = F_whiteYellowRedColormap(n)
% F_whiteYellowRedColormap  White -> yellow -> red sequential colormap.
% Low values render white, high values render red, yellow at the midpoint
% -- easier to read at a glance than 'hot' (black for low values).
%
% INPUT (optional): n, number of colors (default: 256, so it also works
% as a bare function handle, e.g. 'Colormap', @F_whiteYellowRedColormap).

if nargin < 1 || isempty(n)
    n = 256;
end

half = floor(n/2);
t1 = linspace(0, 1, half)';
t2 = linspace(0, 1, n - half)';

seg1 = [ones(half,1),     ones(half,1),     1 - t1];        % white -> yellow
seg2 = [ones(n-half,1),   1 - t2,           zeros(n-half,1)]; % yellow -> red

cmap = [seg1; seg2];

end
