function data_clean = F_removeSpikes(data, upper_threshold, varargin)
% F_removeSpikes  Replace obviously-bad fill/spike values with NaN.
%
% Consolidates the inline `H(H>99999) = NaN;`-style thresholding that was
% previously copy-pasted across IMAGE_event_plotting_*.m,
% Greenland_variometers_*.m, and Ottawa_event_plotting.m (each with its
% own hardcoded threshold, e.g. 99999 for H everywhere, 80000 for
% Ottawa's Z) into one parameterized function.
%
% INPUTS:
%   data             numeric vector or matrix
%   upper_threshold  values > upper_threshold become NaN
%
% NAME-VALUE (optional):
%   'LowerThreshold'  values < LowerThreshold also become NaN (default: none)
%
% OUTPUT:
%   data_clean  same size as data, spikes replaced by NaN
%
% Examples (matches the conventions the old inline code used):
%   H = F_removeSpikes(H, 99999);   % IMAGE / CARISMA / Greenland H convention
%   Z = F_removeSpikes(Z, 80000);   % Ottawa Z convention

p = inputParser;
p.addParameter('LowerThreshold', [], @(x) isempty(x) || isnumeric(x));
p.parse(varargin{:});
opt = p.Results;

data_clean = data;
data_clean(data_clean > upper_threshold) = NaN;
if ~isempty(opt.LowerThreshold)
    data_clean(data_clean < opt.LowerThreshold) = NaN;
end

end
