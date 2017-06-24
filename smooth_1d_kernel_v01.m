function [d] = smooth_1d_kernel_v01(d , samplingrate)
% function [d] = smooth_1d_kernel_v01(d, samplingrate)
%
% Smooth 1D pupil size measures.
%
% d: vector of pupil size measures
% samples: how wide should the smoothing window be?
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-24
% Modified: 2017-06-24

samples             = samplingrate .* 2;  % window size for smoothing
var_kernel_temporal = floor(samples/100);  % width of the smoothing

autocorrelation_kernel_temporal = exp(-0.5 .* ((1 : samples) - samples / 2) .^ 2 / var_kernel_temporal);
autocorrelation_kernel_temporal = autocorrelation_kernel_temporal / sum(autocorrelation_kernel_temporal);

d = conv2(d, autocorrelation_kernel_temporal, 'same');


end

