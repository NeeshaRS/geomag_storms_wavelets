function [x_interp, y_interp] = F_interpNans(x,y,max_gap_minutes)
% For given x and y data, check the y data for NaNs. Leading/trailing
% runs of NaNs (the record starting late or ending early) are truncated
% rather than extrapolated across -- there's no data on one side to
% ground an extrapolation, so it's unreliable regardless of method (seen
% in practice with a since-removed spline default: >1e17 nT from a
% station with a leading gap). Any remaining internal gaps (within the
% truncated valid range, so always bounded by real data on both sides)
% are then interpolated LINEARLY, EXCEPT any single internal gap longer
% than max_gap_minutes (if given), which is left as NaN instead.
%
% INPUTS:
% y- array of the data
% x- array of the data's observation stamps (datetime)
% max_gap_minutes- (optional) internal gaps longer than this are left as
%                  NaN instead of interpolated. Default: no limit.
% ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

if nargin < 3 || isempty(max_gap_minutes)
    max_gap_minutes = Inf;
end

% Check for Nans
y_nancheck = isnan(y);

if any(y_nancheck)
    % Truncate leading and trailing all-NaN runs first (record starts
    % late / ends early) -- separate from, and independent of, any
    % internal gaps.
    firstNonNaN = find(~y_nancheck, 1, 'first');
    lastNonNaN  = find(~y_nancheck, 1, 'last');
    if firstNonNaN > 1 || lastNonNaN < length(y)
        y = y(firstNonNaN:lastNonNaN);
        x = x(firstNonNaN:lastNonNaN);
        y_nancheck = y_nancheck(firstNonNaN:lastNonNaN);
        disp('Data starts late and/or ends early; leading/trailing bad data removed.')
    end

    if any(y_nancheck)
        try
            % Interpolate any remaining internal gaps (within the
            % now-truncated valid range, so no extrapolation risk).
            % Linear, not spline: cubic splines can overshoot well past
            % the surrounding data's actual range near a sharp signal
            % (seen in practice: up to ~1.6e6 nT from a gap under 15 min,
            % during the storm's sharp variations) -- linear interpolation
            % is mathematically bounded between the two neighboring
            % points, so it cannot produce that kind of blowup.
            y_interp = interp1(x(~y_nancheck), y(~y_nancheck), x, 'linear');
            x_interp = x;
            disp('Interpolated gaps in the array.')

            % Re-NaN any single internal gap longer than the cap.
            if isfinite(max_gap_minutes)
                d1 = diff([0; y_nancheck(:); 0]);
                starts = find(d1==1);
                ends = find(d1==-1) - 1;
                for g = 1:numel(starts)
                    gap_minutes = minutes(x(ends(g)) - x(starts(g)) + (x(2)-x(1)));
                    if gap_minutes > max_gap_minutes
                        y_interp(starts(g):ends(g)) = NaN;
                    end
                end
            end
        catch
            disp('This station cannot be used.')
            y_interp = y;
            x_interp = x;
        end
    else
        y_interp = y;
        x_interp = x;
    end

else % Case where there are no NaNs
    y_interp = y;
    x_interp = x;
    disp('No gaps in this array.')
end


end