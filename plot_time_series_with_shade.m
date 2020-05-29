function phandle = plot_time_series_with_shade(Dmean, Derror, color, samplingrate, zero_offset)
% USAGE function phandle = plot_time_series_with_shade(Dmean, Derror, color, samplingrate, zero_offset)
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
% Last modified: 2020-05-29

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
if sum(nancol) > samplingrate
    warning('More than 1s of NaN samples removed during plotting of timeseries.');
end

ct(nancol) = [];
ce(nancol) = [];

x = 1 : length(ct);  % helper for plotting

patch([x x(end:-1:1)], [ct+ce ct(end:-1:1)-ce(end:-1:1)], color, 'facealpha', 0.2, 'Edgecolor', 'none'); hold on;
phandle = plot(x, ct, 'linestyle', '-', 'LineWidth', 1, 'color', color);

% set x-axis ticks
start_x_tick   = rem(zero_offset, samplingrate);
end_x_tick     = get(gca, 'XLim');
end_x_tick     = end_x_tick(2);


% closest multiple of sampling rate at the right
end_x_tick = end_x_tick - mod(end_x_tick, samplingrate);


% hack the number of ticks depending on their number
if end_x_tick > 5 * samplingrate
    spacing = samplingrate;
else
    spacing = samplingrate ./ 2;
end


xtickposition1 = [start_x_tick : spacing : zero_offset];
xtickposition1 = xtickposition1(1 : end - 1);  % delete last one to avoid duplicate with xtickposition2
xtickposition2 = [zero_offset : spacing : end_x_tick];
xtickposition  = [xtickposition1 xtickposition2];
set(gca, 'XTick', xtickposition);


% set x axis tick labels
xticklabels = (xtickposition - zero_offset) ./ samplingrate;
set(gca, 'XTickLabel', xticklabels);

% set axis label
xlabel('time (s)');

end
