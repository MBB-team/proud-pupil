function plot_time_series_with_shade(Dmean, Derror, color, samplingrate, zero_offset)
% USAGE function plot_time_series_with_shade(Dmean, Derror, color, samplingrate, zero_offset)
%
% ARGS
% Dmean          mean of time series (1D)
% Derror         error of time series (1D)
% color          color for plot in RGB
% samplingrate   How many samples are there per second?
% zero_offset    How many samples before onset?
%
% Author:        Antonius Wiehler <antonius.wiehler@gmail.com>
% Original:      2017-05-12
% Last modified: 2017-05-12

if ~exist('zero_offset', 'var')
    zero_offset = 0;  % set pre stimulus interval to 0 if not defined
end

if length(Dmean) ~= length(Derror)
    error('Length of mean and error vectors do not match.\n');
end

% assign mean and error
ct = Dmean;
ce = Derror;

% remove nan collumns
nancol = isnan(ct) | isnan(ce);
if sum(nancol) > 50
    warning('More than 50 NaN samples removed during plotting of timeseries.');
end

ct(nancol) = [];
ce(nancol) = [];

x = 1 : length(ct);  % helper for plotting

patch([x x(end:-1:1)], [ct+ce ct(end:-1:1)-ce(end:-1:1)], color, 'facealpha', 0.2, 'Edgecolor', 'none'); hold on;
plot(x, ct, 'linestyle', '-', 'LineWidth', 1, 'color', color);

% set x-axis ticks
start_x_tick   = rem(zero_offset, samplingrate);
end_x_tick     = size(ct, 2);
xtickposition1 = [start_x_tick : samplingrate : zero_offset];
xtickposition1 = xtickposition1(1 : end - 1);  % to avoid duplicate with xtickposition2
xtickposition2 = [zero_offset : samplingrate : end_x_tick];
xtickposition  = [xtickposition1 xtickposition2];
set(gca, 'XTick', xtickposition);

% set x axis tick labels
xticklabels = (xtickposition - zero_offset) ./ samplingrate;
set(gca, 'XTickLabel', xticklabels);

% set axis label
xlabel('Time (s)');

end
