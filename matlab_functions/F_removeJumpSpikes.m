function y_clean = F_removeJumpSpikes(t, y, window_minutes, n_sigma, min_jump)
% F_removeJumpSpikes  Hampel-style local-outlier spike removal.
%
% Flags a sample as a spike if it deviates from its own local (time-
% windowed) median by more than n_sigma robust-sigma units, where the
% local median and spread (MAD) are recomputed at every point from its
% own neighborhood. Unlike F_removeSpikes' single fixed threshold, this
% scales with local activity -- a jump that stands out against a quiet
% baseline gets flagged, while the same absolute jump during active
% storm-time variation (where local spread is already large) does not.
% Meant for instrument-glitch-style single/short-run outliers (sudden
% spikes during quiet times), not for the
% storm signal itself.
%
% INPUTS:
%   t               datetime vector
%   y               numeric vector, same size as t (may already contain NaN)
%   window_minutes  total centered window duration in minutes used to
%                    compute each point's local median/MAD
%   n_sigma          (optional) outlier threshold in robust-sigma units.
%                    1.4826*MAD approximates 1 std for normal data.
%                    Default: 5.
%   min_jump        (optional) absolute nT floor on the deviation
%                    required to flag a point, so near-zero local MAD
%                    (a genuinely flat stretch) doesn't make the test
%                    hypersensitive to ordinary noise. Default: 0.
%
% OUTPUT:
%   y_clean         same size as y, flagged points replaced with NaN
%                   (feed into F_interpNans same as F_removeSpikes' output)

if nargin < 4 || isempty(n_sigma); n_sigma = 5; end
if nargin < 5 || isempty(min_jump); min_jump = 0; end

win = minutes(window_minutes);
local_med = movmedian(y, win, 'omitnan', 'SamplePoints', t);
local_mad = movmad(y, win, 'omitnan', 'SamplePoints', t);

thresh = max(n_sigma * 1.4826 * local_mad, min_jump);
is_outlier = abs(y - local_med) > thresh;

y_clean = y;
y_clean(is_outlier) = NaN;

end
